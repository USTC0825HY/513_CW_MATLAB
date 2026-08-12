function    adc_inl_dnl
%%
clc;
clear; % removes all variables from the current workspace
close all; % deletes all figures whose handles are not hidden

format shortG; % Short floating-point display format
format compact; % Remove blank lines in command window output

divLine = '========================================';

%% parameters configuration
N = 128*1024;    % FFT calculation length
fsig = 1e6;     % input frequency, 1MHz
fs = 1e8;       % sampling frequency, 100 MHz
ADC_BITS = 16;          
ADC_MIN = -2^ADC_BITS/2;
ADC_MAX = 2^ADC_BITS/2 - 1;

opt.datacutzero = false;
bin_merge_num = 1;

%% locate csv file
initPath = '.\';
[fileName, pathName] = uigetfile('*.csv', 'Select file',initPath, 'MultiSelect', 'on');
% if only 1 file is selected, fileNames is just a string.
if ~iscell(fileName)
    fileName = cellstr(fileName);
end
fileNum = length(fileName);
fprintf('Selected %d files...\n', length(fileNum));
% set diary
diary(fullfile(pathName, 'output.txt'));
disp(divLine);
fprintf('Start to analysis\n');
%% Time-domain sine wave fitting 

filePath = fullfile(pathName, fileName{1});
data = readmatrix(filePath);
adc_data = data(1:N,end);% adc data input
fit_data = adc_data';

[fitResult, gof] = sine_fit(fit_data, fsig, fs); % Sine fitting function
disp(fitResult); % Output fitting model information
disp(gof); % Output goodness of fitting parameters
fitParameter = coeffvalues(fitResult); % Extract fitting coefficients
vamp = fitParameter(1); % Fitted sine wave peak amplitude
dcvolt = fitParameter(4);
vampdb = mag2db(vamp/32/1024); % Convert amplitude to dBFS

sin_max = min([round(dcvolt + vamp)-1000 , ADC_MAX-1000]);
sin_min = max([round(dcvolt - vamp)+1000 , ADC_MIN+1000]);

disp(divLine);
fprintf('Fitting Amplitude = %f (%f dBFS)\n', vamp, vampdb);
fprintf('The interval for ADC nonlinearity test is from %d to %d\n', sin_min, sin_max);

%% Get all data
adc_data_combine = zeros(fileNum * N, 1);

waitnote = waitbar(0,'reading data');
for kk = 1:fileNum
    filePath = fullfile(pathName, fileName{kk});
    data = readmatrix(filePath);
    adc_single = data(1:N, end);

    idx_start = (kk - 1)*N + 1;
    idx_end = kk * N;
    adc_data_combine(idx_start:idx_end) = adc_single;
    waitbar(kk/fileNum,waitnote,sprintf('reading data : %d / %d',kk, fileNum));
end

%% Extract data within the sine signal interval [sin_min, sin_max]
valid_mask = (adc_data_combine >= sin_min) & (adc_data_combine <= sin_max);
valid_data = adc_data_combine(valid_mask);

disp(divLine);
fprintf('Total combined samples: %d\n', length(adc_data_combine));
fprintf('Valid samples within signal range [%d, %d]: %d\n', sin_min, sin_max, length(valid_data));

%% Count unique covered ADC codes within valid signal range
unique_codes = unique(valid_data);
covered_code_num = length(unique_codes);
% full_total_codes = ADC_MAX - ADC_MIN + 1;
full_total_codes = sin_max - sin_min + 1;
coverage_ratio = covered_code_num / full_total_codes * 100;

fprintf('Number of unique covered ADC codes: %d\n', covered_code_num);
fprintf('Full scale code coverage ratio: %.2f %%\n', coverage_ratio);

%% Histogram statistics within signal interval [sin_min, sin_max]
code_axis = (sin_min : sin_max)';


total_bin = length(code_axis);
trunc_len = floor(total_bin / bin_merge_num) * bin_merge_num;
code_trunc = code_axis(1:trunc_len);
code_axis = mean(reshape(code_trunc, bin_merge_num, []), 1)';
edges = linspace(code_axis(1)-bin_merge_num/2, code_axis(end)+bin_merge_num/2, length(code_axis)+1);

cnt_real = histcounts(valid_data, edges);
cnt_real = cnt_real(:);

if opt.datacutzero 
    valid_cnt_mask = cnt_real > 0;
    code_axis = code_axis(valid_cnt_mask);
    cnt_real = cnt_real(valid_cnt_mask);
end

disp(divLine);
fprintf('Histogram code range: %d ~ %d, total bins: %d\n', sin_min, sin_max, length(code_axis));

% Normalize histogram count to probability
total_valid_points = sum(cnt_real);
prob_real = cnt_real / total_valid_points;

%% ================== Calculate theoretical sine probability ==================
% Normalized mapping: ADC code -> [-1,1] normalized voltage
code_mid = dcvolt;
code_half_span = vamp;
code_norm = (code_axis - code_mid) / code_half_span;
LSB_norm = bin_merge_num / code_half_span;  % single LSB normalized width

% Each code voltage boundary [Vlow, Vhigh]
V_low_norm  = code_norm - LSB_norm/2;
V_high_norm = code_norm + LSB_norm/2;

% Sine theoretical probability integral formula
prob_theo_raw = (asin(V_high_norm) - asin(V_low_norm)) / pi;

idx_neg = find(prob_theo_raw < 0);
idx_nan = find(isnan(prob_theo_raw));
idx_bad = union(idx_neg, idx_nan);
if ~isempty(idx_bad)
    warning('Detected unreasonable theoretical probability values at code index: %s', num2str(idx_bad(:)'));
    fprintf('Number of abnormal probability points: %d\n', length(idx_bad));
end
prob_theo_raw(idx_bad) = 0;

% Normalize theoretical probability over full signal interval
prob_theo = prob_theo_raw / sum(prob_theo_raw);

%% Draw measured + theoretical probability on one figure
figure('Color','w','Position',[100,100,1000,400]);
plot(code_axis, prob_real, 'b-', 'LineWidth',1.2, 'DisplayName','Measured Probability');
hold on;
plot(code_axis, prob_theo, 'r--', 'LineWidth',1.5, 'DisplayName','Theoretical Sine Probability');
xlabel('ADC Code');
ylabel('Probability');
title('Measured vs Theoretical Sine Wave Code Probability Distribution');
legend('Location','best');
grid on;
xlim([sin_min-10, sin_max+10]);


%% Calculate DNL (LSB)
% Avoid division by zero
zero_theo_mask = prob_theo < 1e-12;
DNL = zeros(size(code_axis));
DNL(~zero_theo_mask) = prob_real(~zero_theo_mask) ./ prob_theo(~zero_theo_mask) - 1;
DNL(zero_theo_mask) = NaN; % theoretical probability near zero, mark as invalid

disp(divLine);
dnl_abs_max = max(abs(DNL(~isnan(DNL))));
fprintf('Max absolute DNL: %.4f LSB\n', dnl_abs_max);

%% Plot DNL curve
fDNL = figure('Color','w','Position',[100,100,1000,400]);
plot(code_axis, DNL, 'm-', 'LineWidth',1.2, 'DisplayName','DNL');
hold on;
yline(0, 'k--', '0 LSB','HandleVisibility','off');
yline(1, 'g:', '+1 LSB','HandleVisibility','off');
yline(-1, 'g:', '-1 LSB','HandleVisibility','off');
xlabel('ADC Code');
ylabel('DNL (LSB)');
title('ADC Differential Non-Linearity (DNL)');
resultStr = sprintf('DNLmax  = %6.2f\n', dnl_abs_max);
text(0.02, 0.81, resultStr, 'Units','normalized', 'FontSize', 22, 'FontWeight', 'bold', 'Color', 'b', 'HorizontalAlignment','left');
legend('Location','best');
grid on;
xlim([sin_min-10, sin_max+10]);
ylim([-dnl_abs_max, dnl_abs_max]);

%% Calculate INL via cumulative sum of DNL
% INL = cumsum(DNL);

INL_raw = cumsum(DNL);
% N_bin = length(INL_raw);
% k_idx = (0:N_bin-1)';
k_idx = code_axis;
% slope = (INL_raw(end) - INL_raw(1)) / (N_bin - 1);
p = polyfit(k_idx, INL_raw, 1);
slope = p(1);   % 斜率
b = p(2);   % 截距
% baseline = INL_raw(1) + slope * k_idx;
baseline = b + slope * k_idx;
INL = INL_raw - baseline;

inl_abs_max = max(abs(INL));
fprintf('Max absolute INL: %.4f LSB\n', inl_abs_max);

mask_half = (code_axis > -16*1024) & (code_axis < 16*1024);
inl_abs_mid = max(abs(INL(mask_half)));

fINL=figure('Color','w','Position',[100,100,1000,400]);
plot(code_axis, INL, 'r-', 'LineWidth',1.2, 'DisplayName','INL (Baseline Removed)');
hold on;
% plot(code_axis, INL_raw, 'c-', 'LineWidth',1.2, 'DisplayName','INL');
yline(0, 'k--', '0 LSB','HandleVisibility','off');
xlabel('ADC Code');
ylabel('INL (LSB)');
title('ADC Integral Non-Linearity (INL, Endpoint Baseline Subtracted)');
resultStr = sprintf('INLmax  = %6.2f\nINLmax_{mid} = %6.2f\n', inl_abs_max,inl_abs_mid);
text(0.02, 0.81, resultStr, 'Units','normalized', 'FontSize', 22, 'FontWeight', 'bold', 'Color', 'b', 'HorizontalAlignment','left');
legend('Location','best');
grid on;
xlim([sin_min-10, sin_max+10]);
ylim([-inl_abs_max, inl_abs_max]);

%% Save DNL & INL figures to selected folder
% DNL figure save
exportgraphics(fDNL.CurrentAxes, fullfile(pathName, 'DNL_Plot.png'), 'Resolution', 300);
% INL figure save
exportgraphics(fINL.CurrentAxes, fullfile(pathName, 'INL_Plot.png'), 'Resolution', 300);
disp(divLine);
fprintf('Figures saved to folder: %s\n', pathName);
fprintf('Saved files: DNL_Plot.png , INL_Plot.png\n');

disp(divLine);
diary off; % Close log file recording
end %end function
%%
clc;
clear; % removes all variables from the current workspace
close all; % deletes all figures whose handles are not hidden

format shortG; % Short floating-point display format
format compact; % Remove blank lines in command window output
divLine = '========================================';

%% parameters configuration
Nfft = 16*1024*1024;    % FFT calculation length
% fs = 1e8;       % sampling frequency, 100 MHz
fs = 4.17e6;
t = (0:Nfft-1)/fs; % time domain x axis
f = (0:Nfft/2)/Nfft*fs; % freq domain x axis, from 0 to fs/2
f_MHz = f*1e-6; % unit: MHz

%% 积分频带设置
% 可按测试要求设置任意积分频带，单位均为 Hz。
% 频带必须满足：0 <= f_low_band < f_high_band <= fs/2。
f_low_band  = 1e3;    % 默认积分下限：1 kHz
f_high_band = 100e3;  % 默认积分上限：100 kHz

%% locate csv file and read data
initPath = '.\';
[fileName, pathName] = uigetfile('*.csv', 'Select file',initPath, 'MultiSelect', 'on');
% if only 1 file is selected, fileNames is just a string.
if ~iscell(fileName)
    fileName = cellstr(fileName);
end
fprintf('Selected %d files...\n', length(fileName));
filePath = fullfile(pathName, fileName{1});
data = readmatrix(filePath);
dac_data = data(:,end);% DAC data input

datalength = length(dac_data);
fprintf('Raw data length = %d\n', datalength);
% truncate or pad data to Nfft
if datalength >= Nfft
    sig = dac_data(1:Nfft);
else
    sig = zeros(Nfft,1);
    sig(1:datalength) = dac_data;
end

sig_mean = mean(sig);
sig = sig - sig_mean;

%% Windowed FFT spectrum calculation
window_hann = hann(Nfft); % Generate Hanning window to suppress spectral leakage
% window power correction factor for PSD
win_corr = 1/mean(window_hann.^2);  

sig_win = sig .* window_hann;
data_freq = fft(sig_win); % Apply window then execute FFT transform

%% Single-sided Power Spectral Density (PSD) S_V [V^2/Hz]
% Single-sided PSD formula
S_V = win_corr * (abs(data_freq).^2) / (Nfft * fs);
S_V = S_V(1:Nfft/2+1); % 0 ~ fs/2 single-sided
% For a real-valued signal, double all positive-frequency bins except
% DC and Nyquist so that integrating the one-sided PSD gives Vrms^2.
S_V(2:end-1) = 2 * S_V(2:end-1);

% voltage noise density: V/sqrt(Hz)
V_noise_density = sqrt(S_V);
% convert to uV/sqrt(Hz)
Vn_uVsqrtHz = V_noise_density * 1e6;

%% Frequency axis for plotting
f_axis = (0:Nfft/2)'/Nfft * fs;    % Hz
f_axis_MHz = f_axis / 1e6;         % MHz

%% Plot noise power spectral density (log scale)
figure('Color','w');
% semilogx(f_axis_MHz, Vn_uVsqrtHz, 'LineWidth',1.2);
% 修改为双对数
loglog(f_axis_MHz, Vn_uVsqrtHz, 'LineWidth',1.2);
grid on; grid minor;
xlabel('Frequency (MHz)');
ylabel('Noise Density (\muV/\surdHz)');
title('Noise Power Spectral Density');
xlim([f_axis_MHz(2), max(f_axis_MHz)]); % skip DC to avoid log(0) issue

%% Output sample value at 1Hz (find nearest bin to 1 Hz)
target_freq = 1; % Hz
[~,idx_1Hz] = min(abs(f_axis - target_freq));
Vn_1Hz = Vn_uVsqrtHz(idx_1Hz);
fprintf('%s\n',divLine);
fprintf('Noise density near 1 Hz: %.3f uV/sqrt(Hz)\n', Vn_1Hz);
fprintf('%s\n',divLine);

%% 噪声积分计算
if f_low_band < 0 || f_high_band <= f_low_band || f_high_band > fs/2
    error(['Invalid integration band. Require 0 <= f_low_band < ' ...
        'f_high_band <= fs/2 (%.6g Hz).'], fs/2);
end

idx_band = (f_axis >= f_low_band) & (f_axis <= f_high_band);
f_band = f_axis(idx_band);
Sv_band = S_V(idx_band);

if numel(f_band) < 2
    error(['Integration band contains fewer than two FFT bins. ' ...
        'Increase the band width or Nfft.']);
end

% 梯形数值积分 ∫S_V df
int_Sv = trapz(f_band, Sv_band);
Vrms_band = sqrt(int_Sv);          % V
Vrms_band_uV = Vrms_band * 1e6;    % uV
fprintf('Integration frequency range: %.6g Hz ~ %.6g Hz\n', ...
    f_band(1), f_band(end));
fprintf('Integrated noise power: %.6e V^2\n', int_Sv);
fprintf('Integrated noise Vrms: %.6e V RMS\n', Vrms_band);
fprintf('Integrated noise Vrms: %.3f uV RMS\n', Vrms_band_uV);
fprintf('%s\n',divLine);

%% Mark the 1Hz point on figure
hold on;
plot(f_axis_MHz(idx_1Hz), Vn_1Hz, 'ro','MarkerSize',6,'DisplayName','1 Hz Point');
text(f_axis_MHz(idx_1Hz)*1.1, Vn_1Hz,...
    sprintf('1Hz:\n%.2f uV/√Hz',Vn_1Hz),'Color','r');

x_low_MHz  = f_low_band / 1e6;
x_high_MHz = f_high_band / 1e6;
low_freq_label = sprintf('%.6g Hz', f_low_band);
high_freq_label = sprintf('%.6g Hz', f_high_band);
xline(x_low_MHz,'g--',low_freq_label,'LabelOrientation','horizontal');
xline(x_high_MHz,'g--',high_freq_label,'LabelOrientation','horizontal');

str_integral = sprintf([ ...
    'Integrated Noise Vrms\n' ...
    '%.6g Hz ~ %.6g Hz\n' ...
    '%.2f uV RMS'], ...
    f_band(1), f_band(end), Vrms_band_uV);
text(0.02, 0.05, str_integral,...
    'Units','normalized','BackgroundColor',[0.96 0.96 0.96],'FontSize',9);

legend('Location','best');
hold off;

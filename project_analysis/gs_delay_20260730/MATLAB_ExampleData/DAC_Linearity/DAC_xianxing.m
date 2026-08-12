%%
clc;
clear; % removes all variables from the current workspace
close all; % deletes all figures whose handles are not hidden

format shortG; % Short floating-point display format
format compact; % Remove blank lines in command window output
divLine = '========================================';

combine_num = 1; %奇数

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

%% Auto find valid rising ramp boundary (refer your template)
[dac_min,min_index] = min(dac_data(1:datalength/2));
[dac_max,max_index] = max(dac_data(datalength/2:datalength));
max_index = max_index + round(datalength/2) - 1;   % 修正索引偏移

data_valid = dac_data(min_index:max_index);
%% 滑动均值处理 
% 滑动均值滤波
filter_kernel = ones(1, combine_num) / combine_num;
data_smooth = conv(data_valid, filter_kernel, 'valid');
data_valid = data_smooth;
N_valid    = length(data_valid);
data_index = 0:(N_valid-1);
%% Linear fitting
p = polyfit(data_index, data_valid, 1);
slope = p(1);   % 斜率
b     = p(2);   % 截距
data_fit = slope * data_index + b;

%% Calculate INL (Voltage form only)
INL_V = data_valid - data_fit';    

%% Compute indicators
max_INL = max(INL_V);
min_INL = min(INL_V);
pp_INL  = max_INL - min_INL;

%% Print results
fprintf('\n%s\n',divLine);
fprintf('Valid data range: sample %d ~ %d\n',min_index,max_index);
fprintf('Max INL voltage: %.6e V\n', max_INL);
fprintf('Min INL voltage: %.6e V\n', min_INL);
fprintf('Peak-Peak INL: %.6e V\n', pp_INL);
fprintf('%s\n',divLine);

%% Optimized plotting
figure('Position',[100,100,960,640],'Color','w');

% 1. 原始有效斜坡 + 拟合直线
subplot(2,1,1);
plot(data_index, data_valid, 'b-','LineWidth',1.2,'DisplayName','Measured DAC Output');
hold on;
plot(data_index, data_fit, 'r--','LineWidth',1.5,'DisplayName','Linear Fit');
grid on; grid minor;
title('DAC Measured Ramp and Linear Fitting Curve');
xlabel('Relative Sample Index');
ylabel('Voltage (V)');
legend('Location','best');
hold off;

% 2. INL 电压误差，标题嵌入INL指标
subplot(2,1,2);
plot(data_index, INL_V, 'b','LineWidth',1.2);
yline(0,'k--','Zero Line');
grid on; grid minor;
title(sprintf('INL (Voltage Deviation), Max INL = %.6e V, Min INL = %.6e V',max_INL,min_INL));
xlabel('Relative Sample Index');
ylabel('\Delta V (V)');

sgtitle('DAC Integral Non-Linearity Analysis','FontSize',12);
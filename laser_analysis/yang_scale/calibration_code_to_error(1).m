%% clear
clear;
clc;
%% Load data
hardware_gain = 1;

%%
v_codes = [2000,3000,4000,5000,6000,8000,9000,10000,15000,20000,25000,30000];
 v_amp = zeros(size(v_codes));
for i = 1:length(v_codes)
    filename = sprintf('.\\CodeVpp_%d.mat', v_codes(i));
    [signalA, fs] = load_pico_data(hardware_gain, filename);
    T = 1/fs;
    tt = (1:length(signalA))*T;
    [fitresult, gof] = fit_sine_linear(tt, signalA, 1);
    v_amp(i) = fitresult.A;
end
%% 
v_amp_use = 2*abs(v_amp);
figure;plot(v_codes, v_amp_use, "*-")

p1 = polyfit(v_codes, v_amp_use, 1);
slope = p1(1);
intercept = p1(2);

% 生成拟合曲线上的点
y_fit = polyval(p1, v_codes);

%% 3. 绘图展示
figure('Name', 'Linear Fitting of Discriminator Coefficient', 'Color', 'w');
scatter(v_codes, v_amp_use, 80, 'filled', 'MarkerFaceColor', [0 0.4470 0.7410]);
hold on;
plot(v_codes, y_fit, 'r-', 'LineWidth', 1.5);

% 添加标注
grid on;
xlabel('\bf Code峰峰值');
ylabel('\bf DAC输出峰峰值 (V)');
title(sprintf('Linear Fit: y = %.4e * x + (%.4e)', slope, intercept));
legend('Experimental Data', 'Linear Fit', 'Location', 'best');


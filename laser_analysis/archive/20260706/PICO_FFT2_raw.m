clc;
%adc_data_noise = importfile("E:\中科大上海研究院\延迟驱动板测试\YCSD-数据\AD766噪声(直流)\20250911.mat", [1, Inf]);
%adc_data= ad766noise1(2:2:end,1)./2^16*10; 
adc_data = A;%直接处理DAC数据的时候先双击保存的.mat数据文件，然后直接运行本代码，由于PICO的CHA和CHB通道均有使用，因此运行完一次后需要手动换成B
na = 100; %越大分辨率越差，越平滑

fs=1e7;%直接处理DAC数据的时候改成PICO采样率，对应.mat文件中的Tinterval变量的倒数

gain=1;%注意要和vivado中设置的增益参数保持一致 %直接处理DAC数据的时候设置为1

%freq_x=[logspace(0,3,500) logspace(3,6,500)];

y=adc_data/gain;          
nx=length(y);
n=length(y);
w=hanning(floor(nx/na));

[psd,fsd1]=pwelch(y-mean(y),w,10,[],fs);
% 用welch方法计算功率谱密度
% w是加窗
% 第三个参数是重叠部分的长度
% []目的是让fs是第5个参数
figure('Name', 'JG15 PSD_raw');
loglog(fsd1,psd)

xlabel('Frequency (Hz)');

ylabel('Voltage Noise Spetrum (V^2/Hz)','Interpreter','latex');

grid on
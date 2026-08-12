clc;
clear;
close all;
name1 = fileparts(mfilename('fullpath'));

f_v0=3E8/698E-9;%% 中心频率

%% 0427--跳频功能
f1=double(readmatrix('HYpfd_频率计_300MHz.csv','range',':'));%10Hz采样
f1=f1(1:end,1); 
size1=length(f1);
fs=1e1;
t1=(1:size1)/fs;t1=t1';


figure
subplot(2,1,1)
plot(t1,f1);
%频率
legend({'1MHz/s扫频-跳频' },...
'location','northeast','FontSize',14);
title('移频锁相-频率');
% xlim([1E-3,1e1]);
grid on
xlabel('t(s)');
ylabel('Frequency');
set(gcf,'position',[30 30 1600 900]);
set(findobj(gcf,'type','line'),'linewidth',2);

subplot(2,1,2)    
 % 计算1秒阿伦偏差 (ADEV)
 m=(1:1:size1/2);
 [avar1,tau1] = allanvar(f1,m,fs);
 avar1=sqrt(avar1)/f_v0;

loglog(tau1,avar1);
% hold on;
% 
% hold off;
% 添加图例和标签
legend('1MHz/s扫频-跳频');
xlabel('\tau (s)');
ylabel('Allan Deviation (ADEV)');
title('200M-400M阿伦偏差曲线');
grid on
set(gcf,'position',[30 30 1600 900]);
set(findobj(gcf,'type','line'),'linewidth',2);





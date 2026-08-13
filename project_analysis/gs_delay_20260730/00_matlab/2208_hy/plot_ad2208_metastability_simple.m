%% plot_ad2208_metastability_simple
% 简单查看 AD2208 CSV 是否存在疑似亚稳态突变点。
% 只在单个 CSV 内做差分，不跨文件边界判断。

clear; clc; close all;

%% 只修改这里
dataFolder = 'F:\\01_Laser\\20260727_513test\\03_CW测试\\02_Data_测试数据\\513_CW_DATA\\AD2208\\05_INL_DNL\\ADC1_JG15\\JG15_6.5dBm\\yb2208_ch01_20260812_154203';
fileIndex = 3;          % 1~N 查看指定文件；改成 0 查看全部文件概览
dataColumn = 4;         % ADC 数据列
jumpThreshold = 4000;   % 一阶差分阈值，单位 code
secondThreshold = 500;  % 二阶差分阈值，单位 code
zoomStart = 1;          % 详细图起始样点
zoomCount = 5000;       % 详细图显示点数

files = dir(fullfile(dataFolder, '*.csv'));
if isempty(files), error('目录中没有 CSV。'); end
[~, order] = sort({files.name}); files = files(order);
if fileIndex < 0 || fileIndex > numel(files)
    error('fileIndex 必须为 0 到 %d。', numel(files));
end

%% 全部文件概览
if fileIndex == 0
    figure('Color','w','Name','AD2208 all files');
    tiledlayout(2,1);
    nexttile; hold on;
    for k = 1:numel(files)
        x = readAdc(fullfile(files(k).folder, files(k).name), dataColumn);
        plot(linspace(k-1,k,numel(x)), x, 'b-');
    end
    grid on; xlabel('文件序号（文件之间不连续）'); ylabel('ADC code');
    title('全部文件原始波形概览');
    nexttile; hold on;
    for k = 1:numel(files)
        x = readAdc(fullfile(files(k).folder, files(k).name), dataColumn);
        d2 = diff(x,2);
        plot(linspace(k-1,k,numel(d2)), d2, 'k-');
    end
    yline(secondThreshold,'r--'); yline(-secondThreshold,'r--');
    grid on; xlabel('文件序号（文件之间不连续）'); ylabel('二阶差分 code');
    title('全部文件二阶差分概览');
    return;
end

%% 单文件详细图
filePath = fullfile(files(fileIndex).folder, files(fileIndex).name);
x = readAdc(filePath, dataColumn);
n = (0:numel(x)-1)';
d1 = [NaN; diff(x)];
d2 = [NaN; NaN; diff(x,2)];
candidate = abs(d1) > jumpThreshold | abs(d2) > secondThreshold;
candidate(1:2) = false;

% 相邻样本按16位二进制比较。高位翻转尤其值得检查。
word = typecast(int16(round(x)), 'uint16');
xorMask = [NaN; double(bitxor(word(2:end), word(1:end-1)))];

fprintf('文件：%s\n', files(fileIndex).name);
fprintf('样本数：%d，候选点：%d，最大|二阶差分|：%.0f code\n', ...
    numel(x), sum(candidate), max(abs(d2(3:end))));
if any(candidate)
    disp(table(n(candidate), x(candidate), d1(candidate), d2(candidate), ...
        xorMask(candidate), 'VariableNames', ...
        {'SampleIndex','Code','DeltaCode','SecondDifference','BitXorMask'}));
else
    fprintf('当前阈值下没有候选突变点。\n');
end

first = max(1, zoomStart);
last = min(numel(x), first + zoomCount - 1);
idx = first:last;

figure('Color','w','Name',['AD2208 detail - ' files(fileIndex).name], ...
    'NumberTitle','off');
tiledlayout(1,1,'TileSpacing','compact');

nexttile;
plot(n(idx), x(idx), 'b-'); hold on;
plot(n(candidate & n >= first & n <= last), ...
    x(candidate & n >= first & n <= last), 'ro'); hold off;
grid on; xlabel('样本索引'); ylabel('ADC code');
title('原始波形；红点为候选突变');
% 
% nexttile;
% plot(n(idx), d1(idx), 'k-'); hold on;
% yline(jumpThreshold,'r--'); yline(-jumpThreshold,'r--'); hold off;
% grid on; xlabel('样本索引'); ylabel('Delta code');
% title('一次差分');
% 
% nexttile;
% plot(n(idx), d2(idx), 'm-'); hold on;
% yline(secondThreshold,'r--'); yline(-secondThreshold,'r--'); hold off;
% grid on; xlabel('样本索引'); ylabel('Second difference code');
% title('二次差分');
% 
% nexttile;
% plot(n(idx), xorMask(idx), 'g-');
% grid on; xlabel('样本索引'); ylabel('Bit XOR mask');
% title('相邻样本 bit XOR；高位大范围翻转需重点检查');

function x = readAdc(filePath, dataColumn)
% 当前 CSV 第一行为文字表头，后面为数值区。
raw = readmatrix(filePath, 'NumHeaderLines', 1);
x = raw(:, dataColumn);
x = x(isfinite(x));
end

%s05_compare_ad_p1_p100_input_noise - 比较 P=1 与 P=100 输入等效噪声
%   s05_compare_ad_p1_p100_input_noise 使用相同 Welch 口径比较两种
%   FPGA 增益条件下的总链路输入等效 PSD/ASD。
%
%   输入 MAT 必须包含电压 A，以及 Tinterval 或 fs。折算关系为：
%       P=1 input referred = A/1
%       P=100 input referred = A/100
%   cfg.p1.gain 和 cfg.p100.gain 应填写各自的总链路电压增益。若采集
%   文件已经折算到输入端，相应 gain 应设为 1，避免重复除增益。
%
%   本脚本没有扣除 DA 或测量仪器本底，因此结果表示 AD+FPGA+DA
%   总链路输入等效噪声，不等于纯 AD 噪声。需要分离 AD/DA 时使用
%   s04_separate_ad_da_noise，并确认不相关假设和参考面一致。
%
%   两组采样率不一致会产生警告；频率轴不完全一致时，P=100 PSD
%   会插值到 P=1 频率轴。频段上限仍受两组数据的 Nyquist 限制。
%
%   首次使用时修改两个文件路径、增益、summaryBands 和输出目录。
%   输出包括汇总 CSV、结果 MAT 以及 PSD/ASD 对比图。
%
%   Example:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       s05_compare_ad_p1_p100_input_noise
%
%   See also s02_analyze_pico_psd_asd, s04_separate_ad_da_noise
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% ======================== 用户配置区：通常只改这里 ========================

paths = laser_test_paths();
adDataDir = fullfile(paths.digitalLockDataRoot, '20260703_ADC_2208_JG15_JG12_JG18_1');
cfg.outputDir = fullfile(paths.digitalLockDataRoot, 'JG15_P1_P100_input_ref_compare');

cfg.p1.file = fullfile(adDataDir, 'JG15_JG18_JG12_P1', 'JG15_1s_10MSPS_2.mat');
cfg.p1.label = 'P=1 input-ref';
cfg.p1.gain = 1;

cfg.p100.file = fullfile(adDataDir, 'JG15_JG18_JG12_P100', 'JG15_JG3_P100_1S.mat');
cfg.p100.label = 'P=100 input-ref';
cfg.p100.gain = 100;

% 统一使用 100 段 Welch 平均，适合作为宽带噪声底统计口径。
cfg.welch.numSegments = 100;
cfg.welch.overlapRatio = 0.5;

cfg.removeMean = true;
cfg.showFigures = true;

cfg.summaryBands = struct([]);
cfg.summaryBands(1).name = '0-100k';
cfg.summaryBands(1).rangeHz = [0, 100e3];
cfg.summaryBands(2).name = '100k-1M';
cfg.summaryBands(2).rangeHz = [100e3, 1e6];
cfg.summaryBands(3).name = '1M-5M';
cfg.summaryBands(3).rangeHz = [1e6, 5e6];
cfg.summaryBands(4).name = '0-5M';
cfg.summaryBands(4).rangeHz = [0, 5e6];

%% ======================== 主流程 ========================

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

p1 = localComputeSpectrum(cfg.p1.file, cfg.p1.gain, cfg);
p100 = localComputeSpectrum(cfg.p100.file, cfg.p100.gain, cfg);

if abs(p1.fs - p100.fs) / p1.fs > 1e-6
    warning('P=1 和 P=100 采样率不完全一致：%.12g Hz vs %.12g Hz。', p1.fs, p100.fs);
end

freqHz = p1.freqHz;
p1Psd = p1.psd;
p1Asd_nV = p1.asd_nV;

if numel(p1.freqHz) == numel(p100.freqHz) && max(abs(p1.freqHz - p100.freqHz)) == 0
    p100Psd = p100.psd;
else
    p100Psd = interp1(p100.freqHz, p100.psd, freqHz, 'linear', NaN);
end
p100Asd_nV = sqrt(p100Psd) * 1e9;

summaryTable = localMakeSummaryTable(freqHz, p1Psd, p1Asd_nV, p100Psd, p100Asd_nV, cfg.summaryBands);

fprintf('P=1 file      : %s\n', cfg.p1.file);
fprintf('P=100 file    : %s\n', cfg.p100.file);
fprintf('P=1 fs        : %.12g Hz, N = %d, win = %d, overlap = %d\n', ...
    p1.fs, p1.n, p1.winLen, p1.overlap);
fprintf('P=100 fs      : %.12g Hz, N = %d, win = %d, overlap = %d\n\n', ...
    p100.fs, p100.n, p100.winLen, p100.overlap);
disp(summaryTable);

localPlotAsd(freqHz, p1Asd_nV, p100Asd_nV, cfg);
localPlotPsd(freqHz, p1Psd, p100Psd, cfg);

summaryCsv = fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_summary.csv');
summaryMat = fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_compare.mat');
writetable(summaryTable, summaryCsv);
save(summaryMat, 'cfg', 'p1', 'p100', 'freqHz', 'p1Psd', 'p1Asd_nV', ...
    'p100Psd', 'p100Asd_nV', 'summaryTable', '-v7.3');

fprintf('\nSaved ASD figure : %s\n', fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_ASD.png'));
fprintf('Saved PSD figure : %s\n', fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_PSD.png'));
fprintf('Saved summary    : %s\n', summaryCsv);
fprintf('Saved MAT result : %s\n', summaryMat);

%% ======================== 本地函数 ========================

function spec = localComputeSpectrum(matFile, gain, cfg)
%localComputeSpectrum - 将单个链路测量折算到输入端并估计频谱
if ~exist(matFile, 'file')
    error('找不到 MAT 文件：%s', matFile);
end
if ~isfinite(gain) || gain == 0
    error('gain 必须是非零有限数值。');
end

fileVars = who('-file', matFile);
loadVars = {'A'};
if ismember('Tinterval', fileVars)
    loadVars{end + 1} = 'Tinterval';
end
if ismember('fs', fileVars)
    loadVars{end + 1} = 'fs';
end

data = load(matFile, loadVars{:});
if ~isfield(data, 'A')
    error('MAT 文件里没有变量 A：%s', matFile);
end

fs = localGetSampleRate(data);
y = data.A(:);
clear data;

y = y(isfinite(y));
y = y ./ gain;

if cfg.removeMean
    y = y - mean(y);
end

nx = numel(y);
if nx < 16
    error('有效数据点太少：%d。', nx);
end

[win, winLen, overlap] = localMakeWelchWindow(nx, cfg.welch);
[psd, freqHz] = pwelch(y, win, overlap, [], fs);
asd_nV = sqrt(psd) * 1e9;

spec = struct();
spec.file = matFile;
spec.fs = fs;
spec.n = nx;
spec.gain = gain;
spec.winLen = winLen;
spec.overlap = overlap;
spec.freqHz = freqHz;
spec.psd = psd;
spec.asd_nV = asd_nV;
end

function fs = localGetSampleRate(data)
%localGetSampleRate - 从 MAT 元数据读取并验证采样率
if isfield(data, 'Tinterval') && ~isempty(data.Tinterval)
    fs = 1 / data.Tinterval(1);
elseif isfield(data, 'fs') && ~isempty(data.fs)
    fs = data.fs(1);
else
    error('MAT 文件中没有 Tinterval 或 fs，无法确定采样率。');
end
if ~isfinite(fs) || fs <= 0
    error('采样率无效。');
end
end

function [win, winLen, overlap] = localMakeWelchWindow(nx, welchCfg)
%localMakeWelchWindow - 为两组数据构造一致规则的 Hann Welch 窗
if ~isfinite(welchCfg.numSegments) || welchCfg.numSegments <= 0
    error('cfg.welch.numSegments 必须是正数。');
end
if ~isfinite(welchCfg.overlapRatio) || welchCfg.overlapRatio < 0 || welchCfg.overlapRatio >= 1
    error('cfg.welch.overlapRatio 必须满足 0 <= overlapRatio < 1。');
end

winLen = max(8, floor(nx / welchCfg.numSegments));
winLen = min(winLen, nx);
overlap = min(floor(winLen * welchCfg.overlapRatio), winLen - 1);
win = hanning(winLen);
end

function summaryTable = localMakeSummaryTable(freqHz, p1Psd, p1Asd, p100Psd, p100Asd, bands)
%localMakeSummaryTable - 生成每个频段、每种增益条件的统计表
nBands = numel(bands);
nRows = nBands * 3;

bandName = strings(nRows, 1);
sourceName = strings(nRows, 1);
bandStartHz = nan(nRows, 1);
bandEndHz = nan(nRows, 1);
psdMedian = nan(nRows, 1);
psdMean = nan(nRows, 1);
psdMax = nan(nRows, 1);
asdMedian = nan(nRows, 1);
asdMean = nan(nRows, 1);
asdMax = nan(nRows, 1);

row = 0;
for k = 1:nBands
    bandRange = bands(k).rangeHz;
    mask = freqHz >= bandRange(1) & freqHz <= bandRange(2);
    p1PsdBand = p1Psd(mask);
    p100PsdBand = p100Psd(mask);
    p1AsdBand = p1Asd(mask);
    p100AsdBand = p100Asd(mask);
    ratioPsdBand = p100PsdBand ./ p1PsdBand;
    ratioAsdBand = p100AsdBand ./ p1AsdBand;

    row = localFillSummaryRow(row, bands(k).name, 'P=1 input-ref', ...
        bandRange, p1PsdBand, p1AsdBand);
    row = localFillSummaryRow(row, bands(k).name, 'P=100 input-ref', ...
        bandRange, p100PsdBand, p100AsdBand);
    row = localFillSummaryRow(row, bands(k).name, 'P100/P1 ratio', ...
        bandRange, ratioPsdBand, ratioAsdBand);
end

summaryTable = table(bandName, sourceName, bandStartHz, bandEndHz, ...
    psdMedian, psdMean, psdMax, asdMedian, asdMean, asdMax, ...
    'VariableNames', {'Band', 'Source', 'BandStartHz', 'BandEndHz', ...
    'PsdMedian', 'PsdMean', 'PsdMax', 'AsdMedian', 'AsdMean', 'AsdMax'});

    function rowOut = localFillSummaryRow(rowIn, name, source, bandRange, psdValues, asdValues)
        %localFillSummaryRow - 填写一个频段的一行 PSD/ASD 统计量
        rowOut = rowIn + 1;
        bandName(rowOut) = string(name);
        sourceName(rowOut) = string(source);
        bandStartHz(rowOut) = bandRange(1);
        bandEndHz(rowOut) = bandRange(2);

        psdValues = psdValues(isfinite(psdValues));
        asdValues = asdValues(isfinite(asdValues));

        if ~isempty(psdValues)
            psdMedian(rowOut) = median(psdValues);
            psdMean(rowOut) = mean(psdValues);
            psdMax(rowOut) = max(psdValues);
        end
        if ~isempty(asdValues)
            asdMedian(rowOut) = median(asdValues);
            asdMean(rowOut) = mean(asdValues);
            asdMax(rowOut) = max(asdValues);
        end
    end
end

function localPlotAsd(freqHz, p1Asd, p100Asd, cfg)
%localPlotAsd - 保存 P=1 与 P=100 的输入等效 ASD 对比图
visibleState = 'on';
if ~cfg.showFigures
    visibleState = 'off';
end

[p1FreqPlot, p1AsdPlot] = localThinForPlot(freqHz, p1Asd);
[p100FreqPlot, p100AsdPlot] = localThinForPlot(freqHz, p100Asd);

fig = figure('Name', 'JG15 P=1 vs P=100 input-ref ASD', 'Visible', visibleState, 'Color', 'w');
axes('Parent', fig, 'Color', 'w');
loglog(p1FreqPlot, p1AsdPlot, 'LineWidth', 1);
hold on;
loglog(p100FreqPlot, p100AsdPlot, 'LineWidth', 1);
grid on;
xlabel('Frequency (Hz)');
ylabel('Voltage amplitude spectral density (nV/sqrtHz)');
title('JG15 P=1 vs P=100 Input-Referred ASD');
legend({cfg.p1.label, cfg.p100.label}, 'Location', 'best');
exportgraphics(fig, fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_ASD.png'), ...
    'Resolution', 180, 'BackgroundColor', 'white');
end

function localPlotPsd(freqHz, p1Psd, p100Psd, cfg)
%localPlotPsd - 保存 P=1 与 P=100 的输入等效 PSD 对比图
visibleState = 'on';
if ~cfg.showFigures
    visibleState = 'off';
end

[p1FreqPlot, p1PsdPlot] = localThinForPlot(freqHz, p1Psd);
[p100FreqPlot, p100PsdPlot] = localThinForPlot(freqHz, p100Psd);

fig = figure('Name', 'JG15 P=1 vs P=100 input-ref PSD', 'Visible', visibleState, 'Color', 'w');
axes('Parent', fig, 'Color', 'w');
loglog(p1FreqPlot, p1PsdPlot, 'LineWidth', 1);
hold on;
loglog(p100FreqPlot, p100PsdPlot, 'LineWidth', 1);
grid on;
xlabel('Frequency (Hz)');
ylabel('Voltage power spectral density (V^2/Hz)');
title('JG15 P=1 vs P=100 Input-Referred PSD');
legend({cfg.p1.label, cfg.p100.label}, 'Location', 'best');
exportgraphics(fig, fullfile(cfg.outputDir, 'JG15_P1_P100_input_ref_PSD.png'), ...
    'Resolution', 180, 'BackgroundColor', 'white');
end

function [freqPlot, yPlot] = localThinForPlot(freqHz, y)
%localThinForPlot - 限制绘图点数，完整数据仍用于计算和保存
validMask = isfinite(freqHz) & isfinite(y) & freqHz > 0 & y > 0;
freqPlot = freqHz(validMask);
yPlot = y(validMask);

maxPlotPoints = 300000;
if numel(freqPlot) <= maxPlotPoints
    return;
end

idx = unique(round(linspace(1, numel(freqPlot), maxPlotPoints)));
freqPlot = freqPlot(idx);
yPlot = yPlot(idx);
end

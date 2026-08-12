%s02_analyze_pico_psd_asd - 通用电压时序 PSD/ASD 分析
%   s02_analyze_pico_psd_asd 对 PicoScope 或 ILA 转换得到的电压序列
%   计算单边 Welch PSD、ASD 和多个频段的统计量。
%
%   数据读取有明确优先级：工作区存在非空 A 时优先使用 A；否则读取
%   cfg.matFile。为避免误用上一次数据，切换文件前建议执行
%   clear A Tinterval fs。A 的单位必须是 V，并应整理为一维时序。
%
%   采样率优先由 Tinterval 计算，其次读取 fs，二者都不存在时使用
%   cfg.fsManual。cfg.frontendGain 用于把测量端电压折算到目标输入端：
%   y = A/frontendGain。若 A 已在目标参考面，frontendGain 应设为 1。
%
%   pwelch 返回 PSD，单位 V^2/Hz；ASD=sqrt(PSD)，本脚本显示单位为
%   uV/sqrt(Hz)。analysisBands 可配置多个频段；asdLimit_uV 为空表示
%   只统计，填写数值后才绘制限值线并给出 PASS/FAIL。
%
%   本脚本只在命令行显示 summaryTable 并生成图窗，不自动保存文件。
%   需要正式证据文件时，应使用对应的 s03-s11 专项脚本。
%
%   Example:
%       clear A Tinterval fs
%       load('F:\path\replace_with_data.mat','A','Tinterval')
%       s02_analyze_pico_psd_asd
%
%   See also s01_convert_ila_to_pico_mat, pwelch, periodogram
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% ======================== 用户配置区：通常只改这里 ========================

cfg.deviceName = 'X7';

% MAT 文件路径。默认留空，优先使用工作区已有变量 A。
% 如果工作区没有 A，且这里填了 MAT 文件路径，脚本会自动 load 该 MAT 文件。
cfg.matFile = '';

% MAT 文件没有 Tinterval/fs 时才使用这个手动采样率。
cfg.fsManual = 100e6;

% 前端模拟增益。
% A 是 ADC/Pico 端电压；若要折算到器件输入端，填实际前端增益。
% 若只看 ADC/Pico 输入端噪声，填 1。
cfg.frontendGain = 1;

% 是否去掉直流均值。噪声谱分析通常建议设为 true。
cfg.removeMean = true;

% Welch 参数。
% numSegments 越大，窗口越短，曲线越平滑，但频率分辨率越差。
cfg.welch.numSegments = 10;
cfg.welch.overlapRatio = 0.5;

% 分析频段。可以添加多个频段。
% asdLimit_uV = [] 表示只统计，不画指标线，不做 PASS/FAIL。
cfg.analysisBands = struct([]);
cfg.analysisBands(1).name = 'Band 1';
cfg.analysisBands(1).rangeHz = [1e-1, 1e1];
cfg.analysisBands(1).asdLimit_uV = [];

% 示例：需要第二个频段时，取消下面三行注释并按实际指标修改。
% cfg.analysisBands(2).name = 'Band 2';
% cfg.analysisBands(2).rangeHz = [5e6, 20e6];
% cfg.analysisBands(2).asdLimit_uV = 500;

% 绘图开关。
cfg.plot.showFigures = true;
cfg.plot.showAsd = true;
cfg.plot.showPsd = true;
cfg.plot.showBandLines = true;
cfg.plot.showLimitLines = true;

%% ======================== 读取数据 ========================

if exist('A', 'var') && ~isempty(A)
    adcData = A(:);
    inputMeta = struct();
    if exist('Tinterval', 'var') && ~isempty(Tinterval)
        inputMeta.Tinterval = Tinterval;
    end
    dataLabel = '<workspace A>';
elseif ~isempty(cfg.matFile)
    if ~exist(cfg.matFile, 'file')
        error('找不到 MAT 文件：%s', cfg.matFile);
    end

    matData = load(cfg.matFile);
    if ~isfield(matData, 'A')
        error('MAT 文件里没有变量 A：%s', cfg.matFile);
    end

    adcData = matData.A(:);
    inputMeta = matData;
    dataLabel = cfg.matFile;
else
    error('工作区没有变量 A。请先 load MAT 文件，或在 cfg.matFile 中填写 MAT 文件路径。');
end

fs = localGetSampleRate(inputMeta, cfg.fsManual);

if ~isfinite(fs) || fs <= 0
    error('采样率 fs 无效，请检查 Tinterval/fs 或 cfg.fsManual。');
end

%% ======================== 预处理 ========================

if ~isfinite(cfg.frontendGain) || cfg.frontendGain == 0
    error('cfg.frontendGain 必须是非零有限数值。');
end

y = adcData ./ cfg.frontendGain;
y = y(isfinite(y));

if cfg.removeMean
    y = y - mean(y);
end

nx = length(y);
if nx < 16
    error('有效数据点太少：%d，无法进行 Welch 谱分析。', nx);
end

if std(double(y)) == 0
    warning('输入数据为常值，噪声谱会接近 0。请检查数据通道或采集配置。');
end

%% ======================== 计算 PSD 和 ASD ========================

[win, winLen, overlap] = localMakeWelchWindow(nx, cfg.welch);

% pwelch 输出 PSD，单位 V^2/Hz。
[psd, freqHz] = pwelch(y, win, overlap, [], fs);

% ASD = sqrt(PSD)，单位换算为 uV/sqrtHz。
asd_uV = sqrt(psd) * 1e6;

%% ======================== 多频段统计 ========================

summaryTable = localAnalyzeBands(freqHz, asd_uV, psd, cfg.analysisBands, fs);

fprintf('Data source      : %s\n', dataLabel);
fprintf('Device name      : %s\n', cfg.deviceName);
fprintf('frontendGain     : %.6g\n', cfg.frontendGain);
fprintf('fs               : %.12g Hz\n', fs);
fprintf('Nyquist          : %.12g Hz\n', fs / 2);
fprintf('N                : %d\n', nx);
fprintf('Welch window     : %d samples\n', winLen);
fprintf('Welch overlap    : %d samples\n\n', overlap);

fprintf('Band summary:\n');
disp(summaryTable);

%% ======================== 绘图 ========================

localPlotSpectrum(freqHz, asd_uV, psd, cfg, summaryTable);

%% ======================== 小工具函数：一般不用改 ========================

function fsValue = localGetSampleRate(inputMeta, fsManual)
%localGetSampleRate - 按 Tinterval、fs、手动值的顺序解析采样率
if isfield(inputMeta, 'Tinterval') && ~isempty(inputMeta.Tinterval)
    fsValue = 1 / inputMeta.Tinterval(1);
elseif isfield(inputMeta, 'fs') && ~isempty(inputMeta.fs)
    fsValue = inputMeta.fs(1);
else
    fsValue = fsManual;
end
end

function [win, winLen, overlap] = localMakeWelchWindow(nx, welchCfg)
%localMakeWelchWindow - 按分段数和重叠率构造 Welch 窗
if ~isfield(welchCfg, 'numSegments') || isempty(welchCfg.numSegments)
    error('cfg.welch.numSegments 不能为空。');
end
if ~isfield(welchCfg, 'overlapRatio') || isempty(welchCfg.overlapRatio)
    error('cfg.welch.overlapRatio 不能为空。');
end
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

function summaryTable = localAnalyzeBands(freqHz, asd_uV, psd, bands, fs)
%localAnalyzeBands - 统计各频段 ASD、PSD 和限值判定
if isempty(bands)
    error('cfg.analysisBands 至少需要配置一个分析频段。');
end

nBands = numel(bands);
bandName = strings(nBands, 1);
startHz = nan(nBands, 1);
endHz = nan(nBands, 1);
exceedsNyquist = false(nBands, 1);
hasData = false(nBands, 1);
asdLimit_uV = nan(nBands, 1);
asdMedian_uV = nan(nBands, 1);
asdMean_uV = nan(nBands, 1);
asdMax_uV = nan(nBands, 1);
psdMedian_V2Hz = nan(nBands, 1);
psdMean_V2Hz = nan(nBands, 1);
psdMax_V2Hz = nan(nBands, 1);
pointsLeLimitPercent = nan(nBands, 1);
judgment = strings(nBands, 1);

for k = 1:nBands
    if ~isfield(bands(k), 'name') || isempty(bands(k).name)
        bandName(k) = string(sprintf('Band %d', k));
    else
        bandName(k) = string(bands(k).name);
    end

    if ~isfield(bands(k), 'rangeHz') || numel(bands(k).rangeHz) ~= 2
        error('cfg.analysisBands(%d).rangeHz 必须是 [fStart, fEnd]。', k);
    end

    bandRange = double(bands(k).rangeHz(:)).';
    if any(~isfinite(bandRange)) || bandRange(1) < 0 || bandRange(2) <= bandRange(1)
        error('cfg.analysisBands(%d).rangeHz 无效，必须满足 0 <= fStart < fEnd。', k);
    end

    startHz(k) = bandRange(1);
    endHz(k) = bandRange(2);
    exceedsNyquist(k) = endHz(k) > fs / 2;

    if isfield(bands(k), 'asdLimit_uV') && ~isempty(bands(k).asdLimit_uV)
        limitValue = bands(k).asdLimit_uV(1);
        if ~isfinite(limitValue) || limitValue <= 0
            error('cfg.analysisBands(%d).asdLimit_uV 必须为空或正数。', k);
        end
        asdLimit_uV(k) = limitValue;
    end

    bandMask = freqHz >= startHz(k) & freqHz <= endHz(k);
    hasData(k) = any(bandMask);

    if hasData(k)
        bandAsd = asd_uV(bandMask);
        bandPsd = psd(bandMask);
        asdMedian_uV(k) = median(bandAsd);
        asdMean_uV(k) = mean(bandAsd);
        asdMax_uV(k) = max(bandAsd);
        psdMedian_V2Hz(k) = median(bandPsd);
        psdMean_V2Hz(k) = mean(bandPsd);
        psdMax_V2Hz(k) = max(bandPsd);
    end

    if exceedsNyquist(k)
        judgment(k) = "OUT_OF_RANGE";
        warning('频段 "%s" 上限 %.6g Hz 超过 Nyquist 频率 %.6g Hz，不做 PASS/FAIL 判定。', ...
            char(bandName(k)), endHz(k), fs / 2);
    elseif ~hasData(k)
        judgment(k) = "NO_DATA";
        warning('频段 "%s" 没有落在当前频率轴上的数据点。', char(bandName(k)));
    elseif isnan(asdLimit_uV(k))
        judgment(k) = "NO_LIMIT";
    else
        pointsLeLimitPercent(k) = mean(asd_uV(bandMask) <= asdLimit_uV(k)) * 100;
        if asdMedian_uV(k) <= asdLimit_uV(k)
            judgment(k) = "PASS";
        else
            judgment(k) = "FAIL";
        end
    end
end

summaryTable = table( ...
    bandName, startHz, endHz, exceedsNyquist, hasData, asdLimit_uV, ...
    asdMedian_uV, asdMean_uV, asdMax_uV, ...
    psdMedian_V2Hz, psdMean_V2Hz, psdMax_V2Hz, ...
    pointsLeLimitPercent, judgment, ...
    'VariableNames', {'BandName', 'StartHz', 'EndHz', 'ExceedsNyquist', 'HasData', 'AsdLimit_uV', ...
    'AsdMedian_uV', 'AsdMean_uV', 'AsdMax_uV', ...
    'PsdMedian_V2Hz', 'PsdMean_V2Hz', 'PsdMax_V2Hz', ...
    'PointsLeLimitPercent', 'Judgment'});
end

function localPlotSpectrum(freqHz, asd_uV, psd, cfg, summaryTable)
%localPlotSpectrum - 按绘图开关显示 ASD 和 PSD 频谱
if ~isfield(cfg, 'plot') || ~isfield(cfg.plot, 'showFigures') || ~cfg.plot.showFigures
    return;
end

if isfield(cfg.plot, 'showAsd') && cfg.plot.showAsd
    figure('Name', sprintf('%s ASD', cfg.deviceName));
    loglog(freqHz, asd_uV, 'LineWidth', 1);
    grid on;
    hold on;
    localDrawBandMarkers(summaryTable, 'ASD', cfg.plot);
    xlabel('Frequency (Hz)');
    ylabel('Voltage amplitude spectral density (uV/sqrtHz)');
    title(sprintf('%s Input-Referred ASD, gain = %.4g', cfg.deviceName, cfg.frontendGain));
end

if isfield(cfg.plot, 'showPsd') && cfg.plot.showPsd
    figure('Name', sprintf('%s PSD', cfg.deviceName));
    loglog(freqHz, psd, 'LineWidth', 1);
    grid on;
    hold on;
    localDrawBandMarkers(summaryTable, 'PSD', cfg.plot);
    xlabel('Frequency (Hz)');
    ylabel('Voltage power spectral density (V^2/Hz)');
    title(sprintf('%s Input-Referred PSD, gain = %.4g', cfg.deviceName, cfg.frontendGain));
end
end

function localDrawBandMarkers(summaryTable, plotKind, plotCfg)
%localDrawBandMarkers - 在频谱图上标出频段边界和可选限值线
for k = 1:height(summaryTable)
    nameText = char(summaryTable.BandName(k));

    if isfield(plotCfg, 'showBandLines') && plotCfg.showBandLines
        if summaryTable.StartHz(k) > 0
            xline(summaryTable.StartHz(k), 'k--', ...
                sprintf('%s start (%s)', nameText, localFreqLabel(summaryTable.StartHz(k))), ...
                'LineWidth', 1);
        end
        if summaryTable.EndHz(k) > 0
            xline(summaryTable.EndHz(k), 'k--', ...
                sprintf('%s end (%s)', nameText, localFreqLabel(summaryTable.EndHz(k))), ...
                'LineWidth', 1);
        end
    end

    if isfield(plotCfg, 'showLimitLines') && plotCfg.showLimitLines && ~isnan(summaryTable.AsdLimit_uV(k))
        if strcmp(plotKind, 'ASD')
            yline(summaryTable.AsdLimit_uV(k), 'r--', ...
                sprintf('%s %.4g uV/sqrtHz', nameText, summaryTable.AsdLimit_uV(k)), ...
                'LineWidth', 1.2);
        else
            limitPsd = (summaryTable.AsdLimit_uV(k) * 1e-9)^2;
            yline(limitPsd, 'r--', sprintf('%s ASD limit^2', nameText), 'LineWidth', 1.2);
        end
    end
end
end

function label = localFreqLabel(freqHz)
%localFreqLabel - 将 Hz 数值格式化为易读的 Hz/kHz/MHz 标签
if freqHz >= 1e6
    label = sprintf('%.4g MHz', freqHz / 1e6);
elseif freqHz >= 1e3
    label = sprintf('%.4g kHz', freqHz / 1e3);
else
    label = sprintf('%.4g Hz', freqHz);
end
end

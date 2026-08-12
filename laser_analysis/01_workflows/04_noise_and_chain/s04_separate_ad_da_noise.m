%s04_separate_ad_da_noise - 由总链路和 DAC 测量估算 ADC 噪声
%   s04_separate_ad_da_noise 分析 AD+DA 总链路及 DA 单独噪声，在两者
%   不相关的假设下，通过 PSD 相减估算 AD 对应的噪声。
%
%   核心关系为：
%       PSD_total = PSD_AD + PSD_DA
%       PSD_AD = PSD_total - PSD_DA
%       ASD_AD = sqrt(PSD_AD)
%   功率可以在不相关假设下相减，ASD 不能直接相减。totalGain 和
%   daGain 必须先把两组数据折算到同一参考面、同一电压单位。
%
%   两个 Welch 频率轴不一致时，DA PSD 会线性插值到总链路频率轴。
%   相减为负的频点被记为 NaN；negativeDiffPercent 较大通常说明
%   本底不匹配、测量波动、参考面错误或不相关假设不成立。
%
%   每组 cfg.pairs 指定总链路文件、DA 文件、增益和图例。可在调用
%   前创建 adDaNoiseCfgOverride 临时覆盖顶层 cfg 字段，例如：
%       adDaNoiseCfgOverride.outputDir = 'F:\path\replace_output';
%       s04_separate_ad_da_noise
%
%   输出包括每组 MAT、PSD/ASD 图以及总汇 CSV/MAT。采样率决定
%   Nyquist 上限；10 MSPS 数据最多只覆盖约 5 MHz。
%
%   See also s03_calc_dac_integrated_noise_1k_100k, pwelch, interp1
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% ======================== 用户配置区：通常只改这里 ========================

paths = laser_test_paths();
adDataDir = fullfile(paths.digitalLockDataRoot, '20260703_ADC_2208_JG15_JG12_JG18_1');
dacDataDir = fullfile(paths.dac9726DataRoot, '20260703_DAC_9726');
cfg.outputDir = fullfile(paths.digitalLockDataRoot, 'AD_DA_noise_separation_result');

% 去直流均值。做噪声谱通常建议 true。
cfg.removeMean = true;

% Welch 参数。统一按数据长度分成 100 段，作为宽带噪声底统计口径。
cfg.welch.numSegments = 100;
cfg.welch.overlapRatio = 0.5;
cfg.welch.nfft = [];

% 统计摘要频段。当前数据约为 10 MSPS，因此有效最高频率约为 5 MHz。
cfg.summaryBandHz = [0, 5e6];

% 调试时可改小，例如 2e6；正式分析保持 inf。
cfg.maxSamples = inf;

% 是否显示 figure。脚本始终会保存 png。
cfg.showFigures = true;

% 文件配对：
% totalFile = AD2208+DA9726 总链路测量
% daFile    = DA9726 单独测量
% totalGain/daGain 用来把两边折算到同一个参考测量点。若都已经是同一单位，保持 1。
cfg.pairs = struct([]);

cfg.pairs(1).name = 'JG15_total_minus_DA_JG3';
cfg.pairs(1).totalLabel = 'AD2208+DA9726 JG15/JG3';
cfg.pairs(1).daLabel = 'DA9726 JG3';
cfg.pairs(1).adLabel = 'AD2208 estimated from JG15';
cfg.pairs(1).totalFile = fullfile(adDataDir, 'JG15_JG18_JG12_P100', 'JG15_JG3_P100_1S.mat');
cfg.pairs(1).daFile = fullfile(dacDataDir, 'JG3', 'JG3_1s_10MSPS.mat');
cfg.pairs(1).totalGain = 100;
cfg.pairs(1).daGain = 1;

cfg.pairs(2).name = 'JG18_total_minus_DA_JG2';
cfg.pairs(2).totalLabel = 'AD2208+DA9726 JG18/JG2';
cfg.pairs(2).daLabel = 'DA9726 JG2';
cfg.pairs(2).adLabel = 'AD2208 estimated from JG18';
cfg.pairs(2).totalFile = fullfile(adDataDir, 'JG15_JG18_JG12_P100', 'JG18_50ms_10MSPS.mat');
cfg.pairs(2).daFile = fullfile(dacDataDir, 'JG2', 'JG2_50ms_10MSPS.mat');
cfg.pairs(2).totalGain = 100;
cfg.pairs(2).daGain = 1;

cfg.pairs(3).name = 'JG12_total_minus_DA_JG32';
cfg.pairs(3).totalLabel = 'AD2208+DA9726 JG12/JG32';
cfg.pairs(3).daLabel = 'DA9726 JG32';
cfg.pairs(3).adLabel = 'AD2208 estimated from JG12';
cfg.pairs(3).totalFile = fullfile(adDataDir, 'JG15_JG18_JG12_P100', 'JG12_50ms_10MSPS.mat');
cfg.pairs(3).daFile = fullfile(dacDataDir, 'JG32', 'JG32_50ms_10MSPS.mat');
cfg.pairs(3).totalGain = 100;
cfg.pairs(3).daGain = 1;

% 自动化测试或临时覆盖配置用；正常手动运行时不用管。
if exist('adDaNoiseCfgOverride', 'var')
    cfg = localApplyOverrides(cfg, adDaNoiseCfgOverride);
end

%% ======================== 主流程 ========================

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

allSummary = table();

for k = 1:numel(cfg.pairs)
    pair = cfg.pairs(k);
    fprintf('\n========== %s ==========\n', pair.name);

    totalSpec = localComputeSpectrum(pair.totalFile, pair.totalGain, cfg);
    daSpec = localComputeSpectrum(pair.daFile, pair.daGain, cfg);

    daPsdOnTotalFreq = interp1(daSpec.freqHz, daSpec.psd, totalSpec.freqHz, 'linear', NaN);
    validMask = isfinite(totalSpec.psd) & isfinite(daPsdOnTotalFreq);

    adPsd = nan(size(totalSpec.psd));
    adPsd(validMask) = totalSpec.psd(validMask) - daPsdOnTotalFreq(validMask);

    negativeMask = validMask & adPsd < 0;
    negativeDiffPercent = mean(negativeMask(validMask)) * 100;

    adPsdPositive = adPsd;
    adPsdPositive(adPsdPositive <= 0) = NaN;
    adAsd_nV = sqrt(adPsdPositive) * 1e9;

    totalAsd_nV = sqrt(totalSpec.psd) * 1e9;
    daAsdOnTotalFreq_nV = sqrt(daPsdOnTotalFreq) * 1e9;

    pairSummary = localMakeSummaryTable(pair, totalSpec.freqHz, ...
        totalSpec.psd, totalAsd_nV, ...
        daPsdOnTotalFreq, daAsdOnTotalFreq_nV, ...
        adPsdPositive, adAsd_nV, ...
        negativeDiffPercent, cfg.summaryBandHz);

    allSummary = [allSummary; pairSummary]; %#ok<AGROW>

    safeName = localSafeFileName(pair.name);
    resultFile = fullfile(cfg.outputDir, [safeName '_noise_separation.mat']);
    save(resultFile, 'pair', 'cfg', 'totalSpec', 'daSpec', 'daPsdOnTotalFreq', ...
        'adPsd', 'adPsdPositive', 'adAsd_nV', 'pairSummary', '-v7.3');

    localPlotPair(pair, totalSpec.freqHz, totalSpec.psd, totalAsd_nV, ...
        daPsdOnTotalFreq, daAsdOnTotalFreq_nV, adPsdPositive, adAsd_nV, ...
        cfg, safeName);

    fprintf('Saved result: %s\n', resultFile);
    disp(pairSummary);
end

summaryCsv = fullfile(cfg.outputDir, 'AD_DA_noise_summary.csv');
summaryMat = fullfile(cfg.outputDir, 'AD_DA_noise_summary.mat');
writetable(allSummary, summaryCsv);
save(summaryMat, 'cfg', 'allSummary');

fprintf('\nAll done.\n');
fprintf('Summary CSV: %s\n', summaryCsv);
fprintf('Summary MAT: %s\n', summaryMat);

%% ======================== 本地函数 ========================

function spec = localComputeSpectrum(matFile, gain, cfg)
%localComputeSpectrum - 把单个 MAT 折算到目标参考面并估计 PSD
if ~exist(matFile, 'file')
    error('找不到 MAT 文件：%s', matFile);
end
if ~isfinite(gain) || gain == 0
    error('gain 必须是非零有限数值：%s', matFile);
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

if isfinite(cfg.maxSamples)
    y = y(1:min(numel(y), cfg.maxSamples));
end

y = y(isfinite(y));
y = y ./ gain;

if cfg.removeMean
    y = y - mean(y);
end

nx = numel(y);
if nx < 16
    error('有效数据点太少：%s', matFile);
end

if ~isfield(cfg.welch, 'numSegments') || isempty(cfg.welch.numSegments)
    error('cfg.welch.numSegments 不能为空。');
end
if ~isfinite(cfg.welch.numSegments) || cfg.welch.numSegments <= 0
    error('cfg.welch.numSegments 必须是正数。');
end

winLen = max(8, floor(nx / cfg.welch.numSegments));
winLen = min(winLen, nx);
overlap = min(floor(winLen * cfg.welch.overlapRatio), winLen - 1);
win = hanning(winLen);

[psd, freqHz] = pwelch(y, win, overlap, cfg.welch.nfft, fs);

spec = struct();
spec.file = matFile;
spec.fs = fs;
spec.n = nx;
spec.gain = gain;
spec.numSegments = cfg.welch.numSegments;
spec.winLen = winLen;
spec.overlap = overlap;
spec.freqHz = freqHz;
spec.psd = psd;
end

function fs = localGetSampleRate(data)
%localGetSampleRate - 从 Tinterval 或 fs 中解析有效采样率
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

function summary = localMakeSummaryTable(pair, freqHz, totalPsd, totalAsd, daPsd, daAsd, adPsd, adAsd, negativeDiffPercent, bandHz)
%localMakeSummaryTable - 汇总指定频段内总链路、DA 和估算 AD 指标
bandMask = freqHz >= bandHz(1) & freqHz <= bandHz(2);
bandMask = bandMask & isfinite(freqHz);

sourceName = ["Total_AD_plus_DA"; "DA_only"; "AD_estimated"];
label = string({pair.totalLabel; pair.daLabel; pair.adLabel});
psdList = {totalPsd, daPsd, adPsd};
asdList = {totalAsd, daAsd, adAsd};

pairName = strings(3, 1);
bandStartHz = nan(3, 1);
bandEndHz = nan(3, 1);
psdMedian = nan(3, 1);
psdMean = nan(3, 1);
psdMax = nan(3, 1);
asdMedian = nan(3, 1);
asdMean = nan(3, 1);
asdMax = nan(3, 1);
negativePercent = nan(3, 1);

for i = 1:3
    pairName(i) = string(pair.name);
    bandStartHz(i) = bandHz(1);
    bandEndHz(i) = bandHz(2);

    psdBand = psdList{i}(bandMask);
    asdBand = asdList{i}(bandMask);
    psdBand = psdBand(isfinite(psdBand));
    asdBand = asdBand(isfinite(asdBand));

    if ~isempty(psdBand)
        psdMedian(i) = median(psdBand);
        psdMean(i) = mean(psdBand);
        psdMax(i) = max(psdBand);
    end

    if ~isempty(asdBand)
        asdMedian(i) = median(asdBand);
        asdMean(i) = mean(asdBand);
        asdMax(i) = max(asdBand);
    end
end

negativePercent(3) = negativeDiffPercent;

summary = table(pairName, sourceName, label, bandStartHz, bandEndHz, ...
    psdMedian, psdMean, psdMax, asdMedian, asdMean, asdMax, negativePercent, ...
    'VariableNames', {'Pair', 'Source', 'Label', 'BandStartHz', 'BandEndHz', ...
    'PsdMedian_V2Hz', 'PsdMean_V2Hz', 'PsdMax_V2Hz', ...
    'AsdMedian_nVrtHz', 'AsdMean_nVrtHz', 'AsdMax_nVrtHz', 'NegativeDiffPercent'});
end

function localPlotPair(pair, freqHz, totalPsd, totalAsd, daPsd, daAsd, adPsd, adAsd, cfg, safeName)
%localPlotPair - 保存单组噪声分离的 ASD 与 PSD 对比图
visibleState = 'on';
if ~cfg.showFigures
    visibleState = 'off';
end

figAsd = figure('Name', [pair.name ' ASD comparison'], 'Visible', visibleState);
loglog(freqHz, totalAsd, 'LineWidth', 1.1);
hold on;
loglog(freqHz, daAsd, 'LineWidth', 1.1);
loglog(freqHz, adAsd, 'LineWidth', 1.1);
grid on;
xline(cfg.summaryBandHz(1), 'k--', localFreqLabel(cfg.summaryBandHz(1)));
xline(cfg.summaryBandHz(2), 'k--', localFreqLabel(cfg.summaryBandHz(2)));
xlabel('Frequency (Hz)');
ylabel('ASD (nV/sqrtHz)');
title([pair.name ' ASD']);
legend({pair.totalLabel, pair.daLabel, pair.adLabel}, 'Interpreter', 'none', 'Location', 'best');
saveas(figAsd, fullfile(cfg.outputDir, [safeName '_ASD_compare.png']));

figPsd = figure('Name', [pair.name ' PSD comparison'], 'Visible', visibleState);
loglog(freqHz, totalPsd, 'LineWidth', 1.1);
hold on;
loglog(freqHz, daPsd, 'LineWidth', 1.1);
loglog(freqHz, adPsd, 'LineWidth', 1.1);
grid on;
xline(cfg.summaryBandHz(1), 'k--', localFreqLabel(cfg.summaryBandHz(1)));
xline(cfg.summaryBandHz(2), 'k--', localFreqLabel(cfg.summaryBandHz(2)));
xlabel('Frequency (Hz)');
ylabel('PSD (V^2/Hz)');
title([pair.name ' PSD']);
legend({pair.totalLabel, pair.daLabel, pair.adLabel}, 'Interpreter', 'none', 'Location', 'best');
saveas(figPsd, fullfile(cfg.outputDir, [safeName '_PSD_compare.png']));
end

function cfg = localApplyOverrides(cfg, overrides)
%localApplyOverrides - 用工作区覆盖结构更新顶层配置字段
fields = fieldnames(overrides);
for i = 1:numel(fields)
    cfg.(fields{i}) = overrides.(fields{i});
end
end

function name = localSafeFileName(name)
%localSafeFileName - 将分析名称转换为可安全写入文件系统的名称
name = regexprep(name, '[^\w\-]+', '_');
end

function label = localFreqLabel(freqHz)
%localFreqLabel - 将频率数值格式化为 Hz/kHz/MHz 标签
if freqHz >= 1e6
    label = sprintf('%.4g MHz', freqHz / 1e6);
elseif freqHz >= 1e3
    label = sprintf('%.4g kHz', freqHz / 1e3);
else
    label = sprintf('%.4g Hz', freqHz);
end
end

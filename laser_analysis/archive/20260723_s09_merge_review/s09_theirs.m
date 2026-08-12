% s09_analyze_ad_input_equiv_noise_new_flow
% JG15/JG3 链路：从 DAC 输出端测得噪声折算 ADC 输入端等效噪声。
%
% 本脚本完成两条曲线对比：
%   1) 未扣 DAC 固定中码本底
%   2) 已扣 DAC 固定中码本底
%
% 重要计算规则：
%   PSD_ADC_to_DACout(f) = PSD_Vout_total(f) - PSD_DAC_mid(f)
%   PSD_ADC_in(f) = PSD_ADC_to_DACout(f) * (L_ADC / (K_out * G))^2
%
% 注意：
%   不能直接用 ASD 相减。本脚本先扣 PSD，再开根号得到 ASD。

clear;
clc;

%% ======================== 用户参数区：通常只改这里 ========================

cfg.analysisName = 'JG15_JG3_ADC_input_equiv_baseline_compare';

% false：使用下面固定路径，便于复现实验。
% true ：运行时弹窗选择总链路 MAT 和 DAC 本底 MAT。
cfg.useGuiSelect = false;

% 总链路 DAC 输出端测得噪声：AD2208 JG15 -> FPGA G=100 -> DA9726 JG3。
cfg.totalMatFile = 'G:\Laser_test\DATA_2026207\AD2208\JG15_P1_P100\JG15JG12JG18_P_100\JG15_50ms_10MSPS.mat';

% DAC 固定中码本底：JG3 DAC 输出端噪声，包含 DAC 本底和仪器本底。
cfg.dacBaselineMode = 'rawMat';       % 'none' or 'rawMat'
cfg.dacBaselineRawMat = 'G:\Laser_test\DATA_2026207\DAC 9726\noise\JG3_50ms_10MSPS.mat';
cfg.makeBaselineCompare = true;

% 结果输出目录。
cfg.outputDir = 'G:\Laser_test\DATA_2026207\AD2208\JG15_P1_P100\JG15JG12JG18_P_100\ad_input_equiv_JG15_JG3_baseline_compare';

% AD/DA 刻度表。K_out 和 L_ADC 均从这里读取，不使用手册满量程公式。
cfg.calibrationXlsx = 'G:\Laser_test\AD_DA_calibration_table.xlsx';
cfg.calibrationSheet = 'Summary';
cfg.adcInterface = 'JG15';
cfg.dacInterface = 'JG3';
cfg.chainName = 'JG15/JG3';

% FPGA 链路常数增益。
cfg.G = 100;

% MAT 文件没有 Tinterval/fs 时才使用此手动采样率。
cfg.fsManual = 10e6;

% Welch 频谱参数。
% targetResolutionHz 越小，频率分辨率越高，曲线越不平滑。
% 当前默认 20 Hz：10 MSPS 数据对应约 0.05 s 窗长。
cfg.removeMean = true;
cfg.welch.targetResolutionHz = 20;
cfg.welch.numSegments = 100;          % 仅在 targetResolutionHz 留空时使用。
cfg.welch.overlapRatio = 0.5;
cfg.welch.nfft = [];
cfg.maxSamples = inf;

% 指标频段。当前数据约 10 MSPS，Nyquist 约 5 MHz，不能判定 10 MHz-25 MHz。
cfg.targetBandHz = [10e6, 25e6];
cfg.targetAsd_nV = 300;

cfg.summaryBands = struct([]);
cfg.summaryBands(1).name = '0-100k';
cfg.summaryBands(1).rangeHz = [0, 100e3];
cfg.summaryBands(1).asdLimit_nV = [];
cfg.summaryBands(2).name = '100k-1M';
cfg.summaryBands(2).rangeHz = [100e3, 1e6];
cfg.summaryBands(2).asdLimit_nV = [];
cfg.summaryBands(3).name = '1M-5M';
cfg.summaryBands(3).rangeHz = [1e6, 5e6];
cfg.summaryBands(3).asdLimit_nV = [];
cfg.summaryBands(4).name = '0-5M';
cfg.summaryBands(4).rangeHz = [0, 5e6];
cfg.summaryBands(4).asdLimit_nV = [];
cfg.summaryBands(5).name = '10M-25M target';
cfg.summaryBands(5).rangeHz = cfg.targetBandHz;
cfg.summaryBands(5).asdLimit_nV = cfg.targetAsd_nV;

% 绘图设置。
cfg.showFigures = false;
cfg.plotDpi = 180;

%% ======================== 主流程：一般不用改 ========================

cfg = localResolveGuiFiles(cfg);
localValidateConfig(cfg);
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

calibrationTable = readtable(cfg.calibrationXlsx, ...
    'Sheet', cfg.calibrationSheet, 'TextType', 'string');
chainParam = localResolveCalibration(calibrationTable, cfg);

fprintf('\n=== JG15/JG3 ADC input-equivalent noise baseline compare ===\n');
fprintf('Total MAT            : %s\n', cfg.totalMatFile);
fprintf('DAC baseline mode    : %s\n', cfg.dacBaselineMode);
fprintf('DAC baseline MAT     : %s\n', cfg.dacBaselineRawMat);
fprintf('Output dir           : %s\n', cfg.outputDir);
fprintf('Calibration table    : %s\n', cfg.calibrationXlsx);
fprintf('K_out                : %.12g V/code\n', chainParam.K_out);
fprintf('L_ADC                : %.12g V/code\n', chainParam.L_ADC);
fprintf('G                    : %.12g\n', chainParam.G);
fprintf('Scale                : %.12g V_ADCin/V_DACout\n\n', chainParam.scaleAdcInPerVout);

totalSpec = localComputeSpectrumFromMat(cfg.totalMatFile, cfg);
baselineSpec = localLoadBaselineSpectrum(totalSpec.freqHz, cfg);

freqHz = totalSpec.freqHz;
psdVoutTotal = totalSpec.psd;
psdDacMid = baselineSpec.psdOnTotalFreq;

psdAdToDacout = psdVoutTotal - psdDacMid;
validSubtract = isfinite(psdVoutTotal) & isfinite(psdDacMid);
negativeMask = validSubtract & psdAdToDacout < 0;
if any(validSubtract)
    negativeDiffPercent = mean(negativeMask(validSubtract)) * 100;
else
    negativeDiffPercent = NaN;
end
psdAdToDacoutPositive = psdAdToDacout;
psdAdToDacoutPositive(psdAdToDacoutPositive < 0) = NaN;

scale = chainParam.scaleAdcInPerVout;
psdAdcInNoBaseline = psdVoutTotal .* (scale ^ 2);
psdAdcInBaselineSub = psdAdToDacoutPositive .* (scale ^ 2);
asdAdcInNoBaseline_nV = sqrt(psdAdcInNoBaseline) * 1e9;
asdAdcInBaselineSub_nV = sqrt(psdAdcInBaselineSub) * 1e9;

summaryTable = localMakeSummaryTable(freqHz, psdAdcInNoBaseline, ...
    psdAdcInBaselineSub, asdAdcInNoBaseline_nV, asdAdcInBaselineSub_nV, ...
    totalSpec, baselineSpec, chainParam, negativeDiffPercent, cfg);

outMat = fullfile(cfg.outputDir, 'JG15_JG3_adc_input_equiv_baseline_compare.mat');
outCsv = fullfile(cfg.outputDir, 'JG15_JG3_adc_input_equiv_baseline_compare_summary.csv');
outAsd = fullfile(cfg.outputDir, 'JG15_JG3_ADC_input_ASD_baseline_compare.png');
outPsd = fullfile(cfg.outputDir, 'JG15_JG3_ADC_input_PSD_baseline_compare.png');
outSubtract = fullfile(cfg.outputDir, 'JG15_JG3_DAC_output_PSD_subtraction_check.png');

writetable(summaryTable, outCsv, 'Encoding', 'UTF-8');
save(outMat, 'cfg', 'chainParam', 'totalSpec', 'baselineSpec', 'freqHz', ...
    'psdVoutTotal', 'psdDacMid', 'psdAdToDacout', 'psdAdToDacoutPositive', ...
    'psdAdcInNoBaseline', 'psdAdcInBaselineSub', ...
    'asdAdcInNoBaseline_nV', 'asdAdcInBaselineSub_nV', ...
    'negativeDiffPercent', 'summaryTable', '-v7.3');

localPlotAsdCompare(freqHz, asdAdcInNoBaseline_nV, ...
    asdAdcInBaselineSub_nV, chainParam, cfg, totalSpec.fs, outAsd);
localPlotPsdCompare(freqHz, psdAdcInNoBaseline, ...
    psdAdcInBaselineSub, chainParam, cfg, totalSpec.fs, outPsd);
localPlotSubtractionCheck(freqHz, psdVoutTotal, psdDacMid, ...
    psdAdToDacoutPositive, cfg, outSubtract);

fprintf('fs total             : %.12g Hz\n', totalSpec.fs);
fprintf('fs baseline          : %.12g Hz\n', baselineSpec.fs);
fprintf('N total              : %d\n', totalSpec.n);
fprintf('N baseline           : %d\n', baselineSpec.n);
fprintf('Welch window         : %d samples\n', totalSpec.winLen);
fprintf('Welch overlap        : %d samples\n', totalSpec.overlap);
fprintf('Frequency resolution : %.9g Hz\n', totalSpec.fs / totalSpec.winLen);
fprintf('Negative PSD bins    : %.6g %%\n', negativeDiffPercent);
if negativeDiffPercent > 10
    warning('扣除 DAC 本底后负 PSD bin 比例较高：%.6g%%。请检查本底数据是否匹配。', negativeDiffPercent);
end
if cfg.targetBandHz(2) > totalSpec.fs / 2
    warning('当前 Nyquist = %.6g Hz，低于指标上限 %.6g Hz，不能判定 10 MHz-25 MHz 指标。', ...
        totalSpec.fs / 2, cfg.targetBandHz(2));
end

disp(summaryTable);
fprintf('\nSaved MAT            : %s\n', outMat);
fprintf('Saved summary        : %s\n', outCsv);
fprintf('Saved ASD compare    : %s\n', outAsd);
fprintf('Saved PSD compare    : %s\n', outPsd);
fprintf('Saved subtraction    : %s\n', outSubtract);

%% ======================== 本地函数 ========================

function cfg = localResolveGuiFiles(cfg)
if ~cfg.useGuiSelect
    return;
end

[fileName, fileDir] = uigetfile({'*.mat', 'MAT files (*.mat)'}, ...
    '选择 JG15/JG3 总链路 MAT 文件', fileparts(cfg.totalMatFile));
if isequal(fileName, 0)
    error('已取消选择总链路 MAT 文件。');
end
cfg.totalMatFile = fullfile(fileDir, fileName);

if strcmpi(cfg.dacBaselineMode, 'rawMat')
    [fileName, fileDir] = uigetfile({'*.mat', 'MAT files (*.mat)'}, ...
        '选择 JG3 DAC 固定中码本底 MAT 文件', fileparts(cfg.dacBaselineRawMat));
    if isequal(fileName, 0)
        error('已取消选择 DAC 本底 MAT 文件。');
    end
    cfg.dacBaselineRawMat = fullfile(fileDir, fileName);
end
end

function localValidateConfig(cfg)
if ~exist(cfg.totalMatFile, 'file')
    error('找不到总链路 MAT 文件：%s', cfg.totalMatFile);
end
if ~exist(cfg.calibrationXlsx, 'file')
    error('找不到刻度表：%s', cfg.calibrationXlsx);
end
if ~isfinite(cfg.G) || cfg.G == 0
    error('cfg.G 必须是非零有限数值。');
end
if ~ismember(lower(string(cfg.dacBaselineMode)), ["none", "rawmat"])
    error('cfg.dacBaselineMode 只能是 ''none'' 或 ''rawMat''。');
end
if strcmpi(cfg.dacBaselineMode, 'rawMat') && ~exist(cfg.dacBaselineRawMat, 'file')
    error('找不到 DAC 本底 MAT 文件：%s', cfg.dacBaselineRawMat);
end
end

function chainParam = localResolveCalibration(calTable, cfg)
adRow = localFindCalibrationRow(calTable, "AD", string(cfg.adcInterface));
daRow = localFindCalibrationRow(calTable, "DA", string(cfg.dacInterface));

chainParam = struct();
chainParam.chainName = cfg.chainName;
chainParam.adcInterface = cfg.adcInterface;
chainParam.dacInterface = cfg.dacInterface;
chainParam.K_out = daRow.slope_v_per_code(1);
chainParam.L_ADC = adRow.slope_v_per_code(1);
chainParam.G = cfg.G;
chainParam.scaleAdcInPerVout = chainParam.L_ADC / (chainParam.K_out * abs(cfg.G));
chainParam.adR2 = adRow.r2(1);
chainParam.daR2 = daRow.r2(1);
chainParam.adSource = string(adRow.source_file(1));
chainParam.daSource = string(daRow.source_file(1));

if ~isfinite(chainParam.K_out) || chainParam.K_out <= 0
    error('%s 的 K_out 无效。', cfg.dacInterface);
end
if ~isfinite(chainParam.L_ADC) || chainParam.L_ADC <= 0
    error('%s 的 L_ADC 无效。', cfg.adcInterface);
end
end

function row = localFindCalibrationRow(calTable, deviceType, interfaceName)
typeMask = string(calTable.device_type) == deviceType;
interfaceMask = string(calTable.analysis_interface) == interfaceName;
row = calTable(typeMask & interfaceMask, :);
if height(row) ~= 1
    error('刻度表中 %s/%s 匹配到 %d 行，应为 1 行。', ...
        deviceType, interfaceName, height(row));
end
end

function spec = localComputeSpectrumFromMat(matFile, cfg)
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
    error('MAT 文件中没有变量 A：%s', matFile);
end

fs = localGetSampleRate(data, cfg.fsManual);
y = double(data.A(:));
if isfinite(cfg.maxSamples)
    y = y(1:min(numel(y), cfg.maxSamples));
end
y = y(isfinite(y));
if cfg.removeMean
    y = y - mean(y);
end

n = numel(y);
if n < 16
    error('有效数据点太少：%d。', n);
end

welchCfg = cfg.welch;
if isfield(welchCfg, 'targetResolutionHz') && ...
        ~isempty(welchCfg.targetResolutionHz) && ...
        isfinite(welchCfg.targetResolutionHz) && welchCfg.targetResolutionHz > 0
    welchCfg.windowLengthSamples = max(8, floor(fs / welchCfg.targetResolutionHz));
end
[win, winLen, overlap] = localMakeWelchWindow(n, welchCfg);
[psd, freqHz] = pwelch(y, win, overlap, cfg.welch.nfft, fs);

spec = struct();
spec.file = matFile;
spec.fs = fs;
spec.n = n;
spec.winLen = winLen;
spec.overlap = overlap;
spec.freqHz = freqHz(:);
spec.psd = psd(:);
end

function baselineSpec = localLoadBaselineSpectrum(totalFreqHz, cfg)
if strcmpi(cfg.dacBaselineMode, 'none')
    baselineSpec = struct();
    baselineSpec.file = "";
    baselineSpec.fs = NaN;
    baselineSpec.n = 0;
    baselineSpec.winLen = NaN;
    baselineSpec.overlap = NaN;
    baselineSpec.freqHz = totalFreqHz(:);
    baselineSpec.psd = zeros(size(totalFreqHz(:)));
    baselineSpec.psdOnTotalFreq = zeros(size(totalFreqHz(:)));
    return;
end

baselineSpec = localComputeSpectrumFromMat(cfg.dacBaselineRawMat, cfg);
if numel(baselineSpec.freqHz) == numel(totalFreqHz) && ...
        max(abs(baselineSpec.freqHz - totalFreqHz), [], 'omitnan') < 1e-6
    baselineSpec.psdOnTotalFreq = baselineSpec.psd;
else
    baselineSpec.psdOnTotalFreq = interp1(baselineSpec.freqHz, baselineSpec.psd, ...
        totalFreqHz, 'linear', NaN);
end
end

function fs = localGetSampleRate(data, fsManual)
if isfield(data, 'Tinterval') && ~isempty(data.Tinterval)
    fs = 1 / double(data.Tinterval(1));
elseif isfield(data, 'fs') && ~isempty(data.fs)
    fs = double(data.fs(1));
else
    fs = fsManual;
end
if ~isfinite(fs) || fs <= 0
    error('采样率 fs 无效。');
end
end

function [win, winLen, overlap] = localMakeWelchWindow(nx, welchCfg)
if isfield(welchCfg, 'windowLengthSamples') && ~isempty(welchCfg.windowLengthSamples)
    winLen = welchCfg.windowLengthSamples;
else
    winLen = max(8, floor(nx / welchCfg.numSegments));
end
winLen = min(winLen, nx);
overlap = min(floor(winLen * welchCfg.overlapRatio), winLen - 1);
win = hanning(winLen);
end

function summaryTable = localMakeSummaryTable(freqHz, psdNoBase, psdSub, ...
    asdNoBase_nV, asdSub_nV, totalSpec, baselineSpec, chainParam, ...
    negativeDiffPercent, cfg)
rowList = cell(numel(cfg.summaryBands), 1);
nyquist = totalSpec.fs / 2;

for k = 1:numel(cfg.summaryBands)
    band = cfg.summaryBands(k);
    bandStart = band.rangeHz(1);
    bandEnd = band.rangeHz(2);
    exceedsNyquist = bandEnd > nyquist;
    bandMask = freqHz >= bandStart & freqHz <= min(bandEnd, nyquist);
    hasData = any(bandMask);

    [noBaseAsdMedian, noBaseAsdMean, noBaseAsdMax, noBasePsdMedian] = ...
        localBandStats(asdNoBase_nV, psdNoBase, bandMask, hasData);
    [subAsdMedian, subAsdMean, subAsdMax, subPsdMedian] = ...
        localBandStats(asdSub_nV, psdSub, bandMask, hasData);

    if isempty(band.asdLimit_nV) || isnan(band.asdLimit_nV)
        asdLimit = NaN;
        judgment = "仅统计";
    elseif exceedsNyquist || ~hasData
        asdLimit = band.asdLimit_nV;
        judgment = "无法判定";
    elseif subAsdMedian <= band.asdLimit_nV
        asdLimit = band.asdLimit_nV;
        judgment = "通过";
    else
        asdLimit = band.asdLimit_nV;
        judgment = "未通过";
    end

    if exceedsNyquist
        note = "频段超过 Nyquist，结果不用于指标判定。";
    else
        note = "已按 PSD 扣除 DAC 固定中码本底；负 PSD bin 置为 NaN。";
    end

    rowList{k} = table( ...
        string(cfg.chainName), string(cfg.adcInterface), string(cfg.dacInterface), ...
        string(band.name), bandStart, bandEnd, nyquist, exceedsNyquist, hasData, ...
        totalSpec.n, baselineSpec.n, totalSpec.fs, baselineSpec.fs, ...
        totalSpec.winLen, totalSpec.overlap, totalSpec.fs / totalSpec.winLen, ...
        chainParam.K_out, chainParam.L_ADC, chainParam.G, ...
        chainParam.scaleAdcInPerVout, asdLimit, negativeDiffPercent, ...
        noBaseAsdMedian, noBaseAsdMean, noBaseAsdMax, noBasePsdMedian, ...
        subAsdMedian, subAsdMean, subAsdMax, subPsdMedian, ...
        judgment, note, ...
        'VariableNames', {'Chain', 'ADC_Interface', 'DAC_Output', ...
        'BandName', 'StartHz', 'EndHz', 'NyquistHz', 'ExceedsNyquist', 'HasData', ...
        'TotalSamples', 'BaselineSamples', 'Total_fs_Hz', 'Baseline_fs_Hz', ...
        'WelchWindowSamples', 'WelchOverlapSamples', 'FrequencyResolutionHz', ...
        'K_out_V_per_code', 'L_ADC_V_per_code', 'G', ...
        'Scale_ADCIn_per_DACOut', 'AsdLimit_nV_per_sqrtHz', 'NegativeDiffPercent', ...
        'NoBaseline_ASD_median_nV_per_sqrtHz', 'NoBaseline_ASD_mean_nV_per_sqrtHz', ...
        'NoBaseline_ASD_max_nV_per_sqrtHz', 'NoBaseline_PSD_median_V2_per_Hz', ...
        'BaselineSub_ASD_median_nV_per_sqrtHz', 'BaselineSub_ASD_mean_nV_per_sqrtHz', ...
        'BaselineSub_ASD_max_nV_per_sqrtHz', 'BaselineSub_PSD_median_V2_per_Hz', ...
        'Judgment', 'Note'});
end

summaryTable = vertcat(rowList{:});
end

function [asdMedian, asdMean, asdMax, psdMedian] = localBandStats(asd, psd, mask, hasData)
if hasData
    asdMedian = median(asd(mask), 'omitnan');
    asdMean = mean(asd(mask), 'omitnan');
    asdMax = max(asd(mask), [], 'omitnan');
    psdMedian = median(psd(mask), 'omitnan');
else
    asdMedian = NaN;
    asdMean = NaN;
    asdMax = NaN;
    psdMedian = NaN;
end
end

function localPlotAsdCompare(freqHz, asdNoBase, asdSub, chainParam, cfg, fs, outPath)
fig = localCreateFigure(cfg);
maskNoBase = freqHz > 0 & isfinite(asdNoBase) & asdNoBase > 0;
maskSub = freqHz > 0 & isfinite(asdSub) & asdSub > 0;
loglog(freqHz(maskNoBase), asdNoBase(maskNoBase), '-', 'LineWidth', 1, ...
    'DisplayName', '未扣 DAC 本底');
hold on;
loglog(freqHz(maskSub), asdSub(maskSub), '--', 'LineWidth', 1.3, ...
    'DisplayName', '已扣 DAC 本底');
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on;
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent ASD (nV/sqrtHz)');
title(sprintf('%s ADC input ASD compare, G=%.0f, K/L from calibration table', ...
    chainParam.chainName, chainParam.G), 'Interpreter', 'none');
if cfg.targetBandHz(1) < fs / 2
    yline(cfg.targetAsd_nV, '--r', '300 nV/sqrtHz');
end
legend('Location', 'best', 'Interpreter', 'none');
hold off;
localSaveFigure(fig, outPath, cfg);
end

function localPlotPsdCompare(freqHz, psdNoBase, psdSub, chainParam, cfg, fs, outPath)
fig = localCreateFigure(cfg);
maskNoBase = freqHz > 0 & isfinite(psdNoBase) & psdNoBase > 0;
maskSub = freqHz > 0 & isfinite(psdSub) & psdSub > 0;
loglog(freqHz(maskNoBase), psdNoBase(maskNoBase), '-', 'LineWidth', 1, ...
    'DisplayName', '未扣 DAC 本底');
hold on;
loglog(freqHz(maskSub), psdSub(maskSub), '--', 'LineWidth', 1.3, ...
    'DisplayName', '已扣 DAC 本底');
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on;
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent PSD (V^2/Hz)');
title(sprintf('%s ADC input PSD compare, G=%.0f, K/L from calibration table', ...
    chainParam.chainName, chainParam.G), 'Interpreter', 'none');
if cfg.targetBandHz(1) < fs / 2
    yline((cfg.targetAsd_nV * 1e-9) ^ 2, '--r', '(300 nV/sqrtHz)^2');
end
legend('Location', 'best', 'Interpreter', 'none');
hold off;
localSaveFigure(fig, outPath, cfg);
end

function localPlotSubtractionCheck(freqHz, psdTotal, psdBaseline, psdSub, cfg, outPath)
fig = localCreateFigure(cfg);
maskTotal = freqHz > 0 & isfinite(psdTotal) & psdTotal > 0;
maskBaseline = freqHz > 0 & isfinite(psdBaseline) & psdBaseline > 0;
maskSub = freqHz > 0 & isfinite(psdSub) & psdSub > 0;
loglog(freqHz(maskTotal), psdTotal(maskTotal), 'LineWidth', 1, ...
    'DisplayName', 'S_{Vout,total}');
hold on;
loglog(freqHz(maskBaseline), psdBaseline(maskBaseline), 'LineWidth', 1, ...
    'DisplayName', 'S_{DAC,mid}');
loglog(freqHz(maskSub), psdSub(maskSub), 'LineWidth', 1, ...
    'DisplayName', 'S_{ADC->DACout}');
set(gca, 'XScale', 'log', 'YScale', 'log');
grid on;
xlabel('Frequency (Hz)');
ylabel('DAC output PSD (V^2/Hz)');
title('JG15/JG3 DAC output PSD subtraction check', 'Interpreter', 'none');
legend('Location', 'best', 'Interpreter', 'none');
hold off;
localSaveFigure(fig, outPath, cfg);
end

function fig = localCreateFigure(cfg)
visibleState = 'off';
if isfield(cfg, 'showFigures') && cfg.showFigures
    visibleState = 'on';
end
fig = figure('Visible', visibleState, 'Color', 'w', 'Position', [100, 100, 1100, 700]);
end

function localSaveFigure(fig, outPath, cfg)
exportgraphics(fig, outPath, 'Resolution', cfg.plotDpi);
if ~cfg.showFigures
    close(fig);
end
end

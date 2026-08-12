% s09_analyze_ad_input_equiv_noise_new_flow
% 按“DAC 输出端噪声 -> DAC 码值噪声 -> ADC 码值噪声 -> ADC 输入端电压噪声”
% 的新流程计算 AD2208/JG15 输入端等效噪声 ASD/PSD。
%
% 当前默认口径：
%   1) 分析 JG15 P100 链路，FPGA 常数增益 G = 100。
%   2) 暂不扣除 DAC 固定中码本底，因此结果是“未扣 DAC 本底”的估算。
%   3) K_out 使用 DAC 小信号幅度刻度 V/code，不使用 Vpp/code。

if exist('s09_cfg_override', 'var')
    cfgOverride = s09_cfg_override;
else
    cfgOverride = struct();
end
clearvars -except cfgOverride;
clc;

%% ======================== 用户参数区：通常只改这里 ========================

cfg.caseName = 'JG15';
cfg.totalMatFile = 'F:\01_Laser\DATA\SZSD_AD2208\20260703_ADC_2208_JG15_JG12_JG18_1\JG15_JG18_JG12_P100\JG15_50ms_10MSPS.mat';
cfg.outputDir = 'F:\01_Laser\DATA\SZSD_AD2208\20260703_ADC_2208_JG15_JG12_JG18_1\JG15_JG18_JG12_P100\ad_input_equiv_new_flow';

% 本次新流程的三个关键刻度/增益。
cfg.K_out = 9.96544e-05;   % DAC 输出刻度，单位 V/code，来自 JG3 DAC 正弦幅度刻度。
cfg.G = 100;                        % FPGA 常数增益。若后续是频率响应，改用 H_FPGA(f)。
cfg.L_ADC = 1.91343e-05;            % ADC 输入刻度，单位 V/code，来自 AD 多点正弦刻度。

% DAC 固定中码本底扣除模式：
%   'none'        : 本轮默认，不扣 DAC 本底。
%   'spectrumMat' : 从已有频谱 MAT 读取 DAC 本底 PSD，并插值到总链路频率轴。
%   'rawMat'      : 从 DAC 0V 原始 MAT 重新计算 PSD。
cfg.dacBaselineMode = 'none';
cfg.dacBaselineSpectrumMat = '';
cfg.dacBaselineRawMat = '';

% MAT 没有 Tinterval/fs 时才使用此手动采样率。
cfg.fsManual = 10e6;

% 噪声谱通常建议去直流均值。
cfg.removeMean = true;

% Welch 参数。与现有 s02/s04/s05 保持一致。
cfg.welch.numSegments = 100;
cfg.welch.overlapRatio = 0.5;
cfg.welch.nfft = [];

% 正式分析保持 inf；调试可改小，例如 1e6。
cfg.maxSamples = inf;

% 指标频段。当前 JG15 数据约 10 MSPS，Nyquist 约 5 MHz，因此该指标不能直接判定。
cfg.targetBandHz = [10e6, 25e6];
cfg.targetAsd_nV = 300;

% 摘要统计频段。
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
cfg.summaryBands(5).name = 'JG15 target 10M-25M';
cfg.summaryBands(5).rangeHz = cfg.targetBandHz;
cfg.summaryBands(5).asdLimit_nV = cfg.targetAsd_nV;

% 绘图开关。脚本始终保存 PNG；默认不弹窗，避免批处理运行后 MATLAB 不退出。
cfg.showFigures = false;
cfg = localApplyCfgOverride(cfg, cfgOverride);

%% ======================== 主流程：一般不用改 ========================

if ~exist(cfg.totalMatFile, 'file')
    error('找不到总链路 MAT 文件：%s', cfg.totalMatFile);
end
if cfg.K_out <= 0 || ~isfinite(cfg.K_out)
    error('cfg.K_out 必须是正的有限数值。');
end
if cfg.G == 0 || ~isfinite(cfg.G)
    error('cfg.G 必须是非零有限数值。');
end
if cfg.L_ADC <= 0 || ~isfinite(cfg.L_ADC)
    error('cfg.L_ADC 必须是正的有限数值。');
end
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

fprintf('\n=== AD input-equivalent noise, new flow ===\n');
fprintf('Case                 : %s\n', cfg.caseName);
fprintf('Total MAT            : %s\n', cfg.totalMatFile);
fprintf('Output dir           : %s\n', cfg.outputDir);
fprintf('DAC baseline mode    : %s\n', cfg.dacBaselineMode);
fprintf('K_out                : %.12g V/code\n', cfg.K_out);
fprintf('G                    : %.12g\n', cfg.G);
fprintf('L_ADC                : %.12g V/code\n', cfg.L_ADC);

total = localComputeSpectrumFromMat(cfg.totalMatFile, cfg, 'DAC output total');
freqHz = total.freqHz;
psdVoutTotal = total.psd;

[psdDacMid, baselineInfo] = localLoadDacBaselinePsd(freqHz, cfg, total);
psdDacMid = psdDacMid(:);

validSubtract = isfinite(psdVoutTotal) & isfinite(psdDacMid);
psdAdToDacout = nan(size(psdVoutTotal));
psdAdToDacout(validSubtract) = psdVoutTotal(validSubtract) - psdDacMid(validSubtract);

negativeMask = validSubtract & psdAdToDacout < 0;
if any(validSubtract)
    negativeDiffPercent = mean(negativeMask(validSubtract)) * 100;
else
    negativeDiffPercent = NaN;
end

psdAdToDacoutPositive = psdAdToDacout;
psdAdToDacoutPositive(psdAdToDacoutPositive < 0) = NaN;

% PSD 折算。ASD 折算等价于对下面每一级 PSD 开根号。
psdDacCode = psdAdToDacoutPositive ./ (cfg.K_out ^ 2);
psdAdcCode = psdDacCode ./ (abs(cfg.G) ^ 2);
psdAdcIn = psdAdcCode .* (cfg.L_ADC ^ 2);

asdVoutTotal_nV = sqrt(psdVoutTotal) * 1e9;
asdDacMid_nV = sqrt(psdDacMid) * 1e9;
asdAdToDacout_nV = sqrt(psdAdToDacoutPositive) * 1e9;
asdDacCode = sqrt(psdDacCode);
asdAdcCode = sqrt(psdAdcCode);
asdAdcIn_nV = sqrt(psdAdcIn) * 1e9;

scaleAdcInPerVout = cfg.L_ADC / (cfg.K_out * abs(cfg.G));
fprintf('Equivalent scale     : L_ADC / (K_out * G) = %.12g V_ADCin/V_DACout\n', ...
    scaleAdcInPerVout);
fprintf('fs                   : %.12g Hz\n', total.fs);
fprintf('Nyquist              : %.12g Hz\n', total.fs / 2);
fprintf('N                    : %d\n', total.n);
fprintf('Welch window         : %d samples\n', total.winLen);
fprintf('Welch overlap        : %d samples\n', total.overlap);
fprintf('Negative PSD diff    : %.6g %%\n', negativeDiffPercent);

if strcmpi(cfg.dacBaselineMode, 'none')
    warning(['当前 dacBaselineMode = ''none''，未扣除 DAC 固定中码本底。', ...
        ' 输出结果是 ADC 输入端等效噪声估算，不是严格扣本底后的 AD 噪声。']);
end
if cfg.targetBandHz(2) > total.fs / 2
    warning(['当前 Nyquist = %.6g Hz，低于 JG15 指标上限 %.6g Hz。', ...
        ' 本数据不能判定 10 MHz-25 MHz 指标。'], total.fs / 2, cfg.targetBandHz(2));
end

summaryTable = localMakeSummaryTable(freqHz, ...
    psdVoutTotal, asdVoutTotal_nV, ...
    psdAdToDacoutPositive, asdAdToDacout_nV, ...
    psdDacCode, asdDacCode, ...
    psdAdcCode, asdAdcCode, ...
    psdAdcIn, asdAdcIn_nV, ...
    cfg, total.fs, baselineInfo);

disp(summaryTable);

outputStem = localSafeFileStem(cfg.caseName);
resultMat = fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_new_flow.mat']);
summaryCsv = fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_new_flow_summary.csv']);
writetable(summaryTable, summaryCsv);
save(resultMat, 'cfg', 'total', 'baselineInfo', 'freqHz', ...
    'psdVoutTotal', 'psdDacMid', 'psdAdToDacout', 'psdAdToDacoutPositive', ...
    'psdDacCode', 'psdAdcCode', 'psdAdcIn', ...
    'asdVoutTotal_nV', 'asdDacMid_nV', 'asdAdToDacout_nV', ...
    'asdDacCode', 'asdAdcCode', 'asdAdcIn_nV', ...
    'scaleAdcInPerVout', 'negativeDiffPercent', 'summaryTable', '-v7.3');

localPlotFinalAsd(freqHz, asdAdcIn_nV, cfg, total.fs);
localPlotFinalPsd(freqHz, psdAdcIn, cfg, total.fs);
localPlotStageAsd(freqHz, asdVoutTotal_nV, asdDacCode, asdAdcCode, asdAdcIn_nV, cfg);

fprintf('\nSaved MAT     : %s\n', resultMat);
fprintf('Saved summary : %s\n', summaryCsv);
fprintf('Saved ASD     : %s\n', fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_ASD.png']));
fprintf('Saved PSD     : %s\n', fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_PSD.png']));
fprintf('Saved stages  : %s\n', fullfile(cfg.outputDir, [outputStem '_new_flow_stage_ASD.png']));

%% ======================== 本地函数 ========================

function spec = localComputeSpectrumFromMat(matFile, cfg, label)
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

y = data.A(:);
clear data;

if isfinite(cfg.maxSamples)
    y = y(1:min(numel(y), cfg.maxSamples));
end

y = y(isfinite(y));
if cfg.removeMean
    y = y - mean(y);
end

nx = numel(y);
if nx < 16
    error('有效数据点太少：%d。', nx);
end

[win, winLen, overlap] = localMakeWelchWindow(nx, cfg.welch);
[psd, freqHz] = pwelch(y, win, overlap, cfg.welch.nfft, fs);

spec = struct();
spec.label = label;
spec.file = matFile;
spec.fs = fs;
spec.n = nx;
spec.winLen = winLen;
spec.overlap = overlap;
spec.freqHz = freqHz;
spec.psd = psd;
end

function fs = localGetSampleRate(data, fsManual)
if isfield(data, 'Tinterval') && ~isempty(data.Tinterval)
    fs = 1 / data.Tinterval(1);
elseif isfield(data, 'fs') && ~isempty(data.fs)
    fs = data.fs(1);
else
    fs = fsManual;
end
if ~isfinite(fs) || fs <= 0
    error('采样率 fs 无效。');
end
end

function [win, winLen, overlap] = localMakeWelchWindow(nx, welchCfg)
if ~isfield(welchCfg, 'numSegments') || isempty(welchCfg.numSegments)
    error('cfg.welch.numSegments 不能为空。');
end
if ~isfinite(welchCfg.numSegments) || welchCfg.numSegments <= 0
    error('cfg.welch.numSegments 必须是正数。');
end
if ~isfield(welchCfg, 'overlapRatio') || isempty(welchCfg.overlapRatio)
    error('cfg.welch.overlapRatio 不能为空。');
end
if ~isfinite(welchCfg.overlapRatio) || welchCfg.overlapRatio < 0 || welchCfg.overlapRatio >= 1
    error('cfg.welch.overlapRatio 必须满足 0 <= overlapRatio < 1。');
end

winLen = max(8, floor(nx / welchCfg.numSegments));
winLen = min(winLen, nx);
overlap = min(floor(winLen * welchCfg.overlapRatio), winLen - 1);
win = hanning(winLen);
end

function [psdDacMid, info] = localLoadDacBaselinePsd(freqHz, cfg, totalSpec)
mode = lower(string(cfg.dacBaselineMode));
info = struct();
info.mode = char(mode);
info.file = '';
info.note = '';

switch mode
    case "none"
        psdDacMid = zeros(size(freqHz));
        info.note = 'DAC baseline is not subtracted.';

    case "spectrummat"
        if isempty(cfg.dacBaselineSpectrumMat) || ~exist(cfg.dacBaselineSpectrumMat, 'file')
            error('dacBaselineMode=spectrumMat 时 cfg.dacBaselineSpectrumMat 必须指向存在的 MAT 文件。');
        end
        [baseFreq, basePsd] = localReadSpectrumMat(cfg.dacBaselineSpectrumMat);
        psdDacMid = interp1(baseFreq, basePsd, freqHz, 'linear', NaN);
        info.file = cfg.dacBaselineSpectrumMat;
        info.note = 'DAC baseline PSD is loaded from spectrum MAT and interpolated.';

    case "rawmat"
        if isempty(cfg.dacBaselineRawMat) || ~exist(cfg.dacBaselineRawMat, 'file')
            error('dacBaselineMode=rawMat 时 cfg.dacBaselineRawMat 必须指向存在的 MAT 文件。');
        end
        baseSpec = localComputeSpectrumFromMat(cfg.dacBaselineRawMat, cfg, 'DAC mid-code baseline');
        psdDacMid = interp1(baseSpec.freqHz, baseSpec.psd, freqHz, 'linear', NaN);
        info.file = cfg.dacBaselineRawMat;
        info.note = 'DAC baseline PSD is computed from raw MAT and interpolated.';

        if abs(baseSpec.fs - totalSpec.fs) / totalSpec.fs > 1e-6
            warning('DAC 本底 fs 与总链路 fs 不完全一致：%.12g Hz vs %.12g Hz。', ...
                baseSpec.fs, totalSpec.fs);
        end

    otherwise
        error('未知 dacBaselineMode：%s。可选 none/spectrumMat/rawMat。', cfg.dacBaselineMode);
end
end

function [freqHz, psd] = localReadSpectrumMat(matFile)
data = load(matFile);
if isfield(data, 'freqHz') && isfield(data, 'psdDacMid')
    freqHz = data.freqHz(:);
    psd = data.psdDacMid(:);
elseif isfield(data, 'freqHz') && isfield(data, 'psd')
    freqHz = data.freqHz(:);
    psd = data.psd(:);
elseif isfield(data, 'daSpec') && isfield(data.daSpec, 'freqHz') && isfield(data.daSpec, 'psd')
    freqHz = data.daSpec.freqHz(:);
    psd = data.daSpec.psd(:);
elseif isfield(data, 'totalSpec') && isfield(data, 'daPsdOnTotalFreq')
    freqHz = data.totalSpec.freqHz(:);
    psd = data.daPsdOnTotalFreq(:);
else
    error(['无法从频谱 MAT 中识别 DAC 本底 PSD。支持变量组合：', ...
        'freqHz+psdDacMid、freqHz+psd、daSpec.freqHz+daSpec.psd、', ...
        'totalSpec.freqHz+daPsdOnTotalFreq。文件：%s'], matFile);
end

validMask = isfinite(freqHz) & isfinite(psd);
freqHz = freqHz(validMask);
psd = psd(validMask);
if isempty(freqHz)
    error('频谱 MAT 中没有有效 PSD 数据：%s', matFile);
end
end

function summaryTable = localMakeSummaryTable(freqHz, ...
    psdVoutTotal, asdVoutTotal, ...
    psdAdToDacout, asdAdToDacout, ...
    psdDacCode, asdDacCode, ...
    psdAdcCode, asdAdcCode, ...
    psdAdcIn, asdAdcIn, ...
    cfg, fs, baselineInfo)

sources = struct([]);
sources(1).name = 'Vout_total';
sources(1).unit = 'V or nV';
sources(1).psd = psdVoutTotal;
sources(1).asd = asdVoutTotal;
sources(1).asdUnit = 'nV/sqrtHz';
sources(2).name = 'ADC_to_DACout';
sources(2).unit = 'V or nV';
sources(2).psd = psdAdToDacout;
sources(2).asd = asdAdToDacout;
sources(2).asdUnit = 'nV/sqrtHz';
sources(3).name = 'DAC_code_equiv';
sources(3).unit = 'code';
sources(3).psd = psdDacCode;
sources(3).asd = asdDacCode;
sources(3).asdUnit = 'code/sqrtHz';
sources(4).name = 'ADC_code_equiv';
sources(4).unit = 'code';
sources(4).psd = psdAdcCode;
sources(4).asd = asdAdcCode;
sources(4).asdUnit = 'code/sqrtHz';
sources(5).name = 'ADC_input_equiv';
sources(5).unit = 'V or nV';
sources(5).psd = psdAdcIn;
sources(5).asd = asdAdcIn;
sources(5).asdUnit = 'nV/sqrtHz';

nRows = numel(cfg.summaryBands) * numel(sources);
bandName = strings(nRows, 1);
sourceName = strings(nRows, 1);
asdUnit = strings(nRows, 1);
bandStartHz = nan(nRows, 1);
bandEndHz = nan(nRows, 1);
exceedsNyquist = false(nRows, 1);
hasData = false(nRows, 1);
psdMedian = nan(nRows, 1);
psdMean = nan(nRows, 1);
psdMax = nan(nRows, 1);
asdMedian = nan(nRows, 1);
asdMean = nan(nRows, 1);
asdMax = nan(nRows, 1);
asdLimit_nV = nan(nRows, 1);
judgment = strings(nRows, 1);
note = strings(nRows, 1);

row = 0;
for b = 1:numel(cfg.summaryBands)
    band = cfg.summaryBands(b);
    if ~isfield(band, 'asdLimit_nV') || isempty(band.asdLimit_nV)
        limitValue = NaN;
    else
        limitValue = band.asdLimit_nV;
    end

    for s = 1:numel(sources)
        row = row + 1;
        bandName(row) = string(band.name);
        sourceName(row) = string(sources(s).name);
        asdUnit(row) = string(sources(s).asdUnit);
        bandStartHz(row) = band.rangeHz(1);
        bandEndHz(row) = band.rangeHz(2);
        exceedsNyquist(row) = band.rangeHz(2) > fs / 2;

        mask = freqHz >= band.rangeHz(1) & freqHz <= band.rangeHz(2);
        mask = mask & isfinite(freqHz);
        hasData(row) = any(mask);

        psdBand = sources(s).psd(mask);
        asdBand = sources(s).asd(mask);
        psdBand = psdBand(isfinite(psdBand));
        asdBand = asdBand(isfinite(asdBand));

        if ~isempty(psdBand)
            psdMedian(row) = median(psdBand);
            psdMean(row) = mean(psdBand);
            psdMax(row) = max(psdBand);
        end
        if ~isempty(asdBand)
            asdMedian(row) = median(asdBand);
            asdMean(row) = mean(asdBand);
            asdMax(row) = max(asdBand);
        end

        if strcmp(sources(s).name, 'ADC_input_equiv') && isfinite(limitValue)
            asdLimit_nV(row) = limitValue;
            if exceedsNyquist(row)
                judgment(row) = "无法判定";
                note(row) = "指标频段超出 Nyquist";
            elseif ~hasData(row)
                judgment(row) = "无法判定";
                note(row) = "该频段没有频点";
            elseif asdMax(row) <= limitValue
                judgment(row) = "通过";
                note(row) = "按当前数据频段统计";
            else
                judgment(row) = "未通过";
                note(row) = "按当前数据频段统计";
            end
        elseif ~hasData(row)
            judgment(row) = "无法判定";
            note(row) = "该频段没有频点";
        else
            judgment(row) = "仅统计";
            note(row) = "未设置指标线";
        end

        if strcmpi(baselineInfo.mode, 'none')
            note(row) = strtrim(note(row) + "; 未扣 DAC 固定中码本底");
        end
    end
end

summaryTable = table(bandName, sourceName, asdUnit, bandStartHz, bandEndHz, ...
    exceedsNyquist, hasData, psdMedian, psdMean, psdMax, ...
    asdMedian, asdMean, asdMax, asdLimit_nV, judgment, note, ...
    'VariableNames', {'Band', 'Source', 'AsdUnit', 'BandStartHz', 'BandEndHz', ...
    'ExceedsNyquist', 'HasData', 'PsdMedian', 'PsdMean', 'PsdMax', ...
    'AsdMedian', 'AsdMean', 'AsdMax', 'AsdLimit_nV', 'Judgment', 'Note'});
end

function localPlotFinalAsd(freqHz, asdAdcIn_nV, cfg, fs)
visibleState = localVisibleState(cfg.showFigures);
[freqPlot, asdPlot] = localThinForPlot(freqHz, asdAdcIn_nV);
outputStem = localSafeFileStem(cfg.caseName);

fig = figure('Name', [char(cfg.caseName) ' ADC input equivalent ASD'], ...
    'Visible', visibleState, 'Color', 'w');
loglog(freqPlot, asdPlot, 'LineWidth', 1.1);
grid on;
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent ASD (nV/sqrtHz)');
title([char(cfg.caseName) ' ADC input-equivalent ASD, DAC baseline not subtracted']);

if cfg.targetBandHz(1) <= fs / 2
    hold on;
    yline(cfg.targetAsd_nV, '--r', '300 nV/sqrtHz target', 'LineWidth', 1);
    xline(cfg.targetBandHz(1), ':k', '10 MHz');
    if cfg.targetBandHz(2) <= fs / 2
        xline(cfg.targetBandHz(2), ':k', '25 MHz');
    end
end

exportgraphics(fig, fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_ASD.png']), ...
    'Resolution', 180, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function localPlotFinalPsd(freqHz, psdAdcIn, cfg, fs)
visibleState = localVisibleState(cfg.showFigures);
[freqPlot, psdPlot] = localThinForPlot(freqHz, psdAdcIn);
outputStem = localSafeFileStem(cfg.caseName);

fig = figure('Name', [char(cfg.caseName) ' ADC input equivalent PSD'], ...
    'Visible', visibleState, 'Color', 'w');
loglog(freqPlot, psdPlot, 'LineWidth', 1.1);
grid on;
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent PSD (V^2/Hz)');
title([char(cfg.caseName) ' ADC input-equivalent PSD, DAC baseline not subtracted']);

if cfg.targetBandHz(1) <= fs / 2
    hold on;
    yline((cfg.targetAsd_nV * 1e-9) ^ 2, '--r', '300 nV/sqrtHz PSD target', 'LineWidth', 1);
    xline(cfg.targetBandHz(1), ':k', '10 MHz');
    if cfg.targetBandHz(2) <= fs / 2
        xline(cfg.targetBandHz(2), ':k', '25 MHz');
    end
end

exportgraphics(fig, fullfile(cfg.outputDir, [outputStem '_adc_input_equiv_PSD.png']), ...
    'Resolution', 180, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function localPlotStageAsd(freqHz, asdVout_nV, asdDacCode, asdAdcCode, asdAdcIn_nV, cfg)
visibleState = localVisibleState(cfg.showFigures);
outputStem = localSafeFileStem(cfg.caseName);

fig = figure('Name', [char(cfg.caseName) ' new flow stage ASD'], ...
    'Visible', visibleState, 'Color', 'w', 'Position', [80 80 1200 780]);

subplot(2, 2, 1);
localLogPlot(freqHz, asdVout_nV);
grid on;
xlabel('Frequency (Hz)');
ylabel('nV/sqrtHz');
title('1. DAC output Vout ASD');

subplot(2, 2, 2);
localLogPlot(freqHz, asdDacCode);
grid on;
xlabel('Frequency (Hz)');
ylabel('code/sqrtHz');
title('2. Equivalent DAC input code ASD');

subplot(2, 2, 3);
localLogPlot(freqHz, asdAdcCode);
grid on;
xlabel('Frequency (Hz)');
ylabel('code/sqrtHz');
title('3. Equivalent ADC code ASD');

subplot(2, 2, 4);
localLogPlot(freqHz, asdAdcIn_nV);
grid on;
xlabel('Frequency (Hz)');
ylabel('nV/sqrtHz');
title('4. ADC input-equivalent ASD');

sgtitle([char(cfg.caseName) ' new flow ASD stages, DAC baseline not subtracted']);
exportgraphics(fig, fullfile(cfg.outputDir, [outputStem '_new_flow_stage_ASD.png']), ...
    'Resolution', 180, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function localLogPlot(freqHz, y)
[freqPlot, yPlot] = localThinForPlot(freqHz, y);
loglog(freqPlot, yPlot, 'LineWidth', 1.0);
end

function visibleState = localVisibleState(showFigures)
if showFigures
    visibleState = 'on';
else
    visibleState = 'off';
end
end

function [freqPlot, yPlot] = localThinForPlot(freqHz, y)
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

function cfg = localApplyCfgOverride(cfg, cfgOverride)
if nargin < 2 || isempty(cfgOverride)
    return;
end

fields = fieldnames(cfgOverride);
for k = 1:numel(fields)
    cfg.(fields{k}) = cfgOverride.(fields{k});
end
end

function stem = localSafeFileStem(textValue)
stem = char(string(textValue));
stem = regexprep(stem, '[^\w.-]+', '_');
stem = regexprep(stem, '_+', '_');
stem = regexprep(stem, '^_+|_+$', '');
if isempty(stem)
    stem = 'case';
end
end

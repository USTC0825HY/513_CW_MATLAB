%s10_analyze_adc_grounded_csv_input_noise - 分析接地 ADC 输入等效噪声
%   s10_analyze_adc_grounded_csv_input_noise 直接读取一个或多个 ILA
%   CSV，在前级输入接地条件下把 ADC 码流换算为输入等效 PSD/ASD。
%
%   处理链路为：
%       CSV raw code -> signedCode
%       codeNoise = signedCode - mean(signedCode)
%       inputNoiseV = codeNoise*L_ADC
%       PSD_input = pwelch(inputNoiseV)
%       ASD_input = sqrt(PSD_input)
%   L_ADC 是最关键的标定斜率，单位 V/code。截距只影响直流工作点，
%   去均值频谱不使用截距，也不应再套用 ADC 手册满量程公式。
%
%   dataCol/validCol 可用列号或表头；dataRadix 必须和 CSV 文本一致。
%   outputCoding 决定 two's complement、offset binary 或 unipolar。
%   码型或位宽错误通常表现为码值跳变、均值异常或噪声显著偏大。
%
%   calibrationMode='manual' 时使用 L_ADC_manual；'summaryCsv' 时读取
%   s07 的 slope_v_per_code。使用 summary 前必须确认其 reference plane
%   是当前 ADC 外部输入端，避免前端增益被重复折算。
%
%   analysisBands 可以同时统计多个频段；频段超过 Nyquist 时返回
%   OUT_OF_RANGE，不形成 PASS/FAIL。每个输入 CSV 会输出 summary CSV、
%   完整 MAT、码流预览和 PSD/ASD PNG，并生成批量汇总。
%
%   可用 adcGroundedNoiseCfgOverride 覆盖顶层配置，例如：
%       adcGroundedNoiseCfgOverride.inputFiles = {'F:\path\data.csv'};
%       adcGroundedNoiseCfgOverride.fs = 100e6;
%       s10_analyze_adc_grounded_csv_input_noise
%
%   See also s07_calibrate_ila_multi_sine,
%   s09_analyze_ad_input_equiv_noise_new_flow
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% ======================== 用户参数区：通常只改这里 ========================

paths = laser_test_paths();
cfg.analysisName = 'AD2208_JG15_grounded';

% 输入 CSV。留空则弹窗选择一个或多个 CSV；也可直接写完整路径：
% cfg.inputFiles = {'F:\01_data_laser\DATA\SZSD_AD2208\replace_with_grounded.csv'};
cfg.inputFiles = {};
cfg.initialDir = paths.digitalLockDataRoot;
cfg.outFolderName = 'adc_grounded_input_noise';

% 截图所示 CSV：第 4 列 D 为目标 ADC 码值，形如 032f、0338。
cfg.dataCol = 4;
cfg.validCol = [];
cfg.validValue = 1;
cfg.firstDataRow = 'auto';
cfg.dataRadix = 'hex';       % 'hex' or 'decimal'

% ADC/FPGA 输出码型。
cfg.adcBits = 16;
cfg.outputCoding = 'twos_complement';
% outputCoding:
%   'twos_complement' : 原始二补码或已经按二补码导出的十六进制/十进制码值
%   'offset_binary'   : 原始 offset binary，总线中点 0x8000 表示 0
%   'unipolar'        : 直二进制，适合单极性 ADC

% 采样率。若 CSV 不是 100 MSPS，请修改这里。
cfg.fs = 100e6;

% ADC 输入刻度 L_ADC，单位 V/code。
% manual     : 使用 cfg.L_ADC_manual。
% summaryCsv : 从 s07_calibrate_ila_multi_sine 输出的 *_fit_summary_*.csv 读取 slope_v_per_code。
cfg.calibrationMode = 'manual';      % 'manual' or 'summaryCsv'
cfg.L_ADC_manual = 1.91572e-05;
cfg.calibrationSummaryCsv = '';

% 噪声谱设置。
cfg.removeMean = true;
cfg.welch.numSegments = 100;
cfg.welch.overlapRatio = 0.5;
cfg.welch.nfft = [];
cfg.maxSamples = inf;                % 调试可改成 1e6；正式保持 inf。

% 分析频段。JG15 指标示例：10 MHz-25 MHz，<=300 nV/sqrtHz。
cfg.analysisBands = struct([]);
cfg.analysisBands(1).name = '0-100k';
cfg.analysisBands(1).rangeHz = [0, 100e3];
cfg.analysisBands(1).asdLimit_nV = [];
cfg.analysisBands(2).name = '100k-1M';
cfg.analysisBands(2).rangeHz = [100e3, 1e6];
cfg.analysisBands(2).asdLimit_nV = [];
cfg.analysisBands(3).name = '1M-5M';
cfg.analysisBands(3).rangeHz = [1e6, 5e6];
cfg.analysisBands(3).asdLimit_nV = [];
cfg.analysisBands(4).name = '10M-25M target';
cfg.analysisBands(4).rangeHz = [10e6, 25e6];
cfg.analysisBands(4).asdLimit_nV = 300;

% 绘图开关。默认不弹窗，只保存 PNG。
cfg.showFigures = false;
cfg.previewPoints = 5000;
cfg.plotDpi = 180;

% 自动化测试或临时覆盖配置用；正常手动运行时不用管。
if exist('adcGroundedNoiseCfgOverride', 'var')
    cfg = localApplyOverrides(cfg, adcGroundedNoiseCfgOverride);
end

%% ======================== 主流程：一般不用改 ========================

L_ADC = localResolveLadc(cfg);
files = localResolveInputFiles(cfg);
allSummary = table();

fprintf('\n=== ADC grounded input-equivalent noise from ILA CSV ===\n');
fprintf('Analysis name       : %s\n', cfg.analysisName);
fprintf('File count          : %d\n', numel(files));
fprintf('dataCol             : %s\n', localValueToText(cfg.dataCol));
fprintf('dataRadix           : %s\n', cfg.dataRadix);
fprintf('outputCoding        : %s\n', cfg.outputCoding);
fprintf('fs                  : %.12g Hz\n', cfg.fs);
fprintf('L_ADC               : %.12g V/code\n', L_ADC);
fprintf('calibrationMode     : %s\n\n', cfg.calibrationMode);

for k = 1:numel(files)
    inPath = files{k};
    fprintf('[%d/%d] %s\n', k, numel(files), inPath);

    result = localAnalyzeOneCsv(inPath, cfg, L_ADC);
    allSummary = [allSummary; result.summaryTable]; %#ok<AGROW>

    fprintf('  Samples           : %d\n', result.sampleCount);
    fprintf('  signedCode mean   : %.9g code\n', result.signedCodeMean);
    fprintf('  signedCode std    : %.9g code\n', result.signedCodeStd);
    fprintf('  inputNoise std    : %.9g V\n', result.inputNoiseStdV);
    fprintf('  Output dir        : %s\n\n', result.outDir);
end

if ~isempty(allSummary)
    firstOutDir = char(allSummary.OutputDir(1));
    batchSummaryPath = fullfile(firstOutDir, 'batch_adc_grounded_input_noise_summary.csv');
    writetable(allSummary, batchSummaryPath, 'Encoding', 'UTF-8');
    fprintf('Batch summary       : %s\n', batchSummaryPath);
end

%% ======================== 本地函数 ========================

function result = localAnalyzeOneCsv(inPath, cfg, L_ADC)
%localAnalyzeOneCsv - 解析一个 ILA CSV 并导出输入等效噪声证据
if ~exist(inPath, 'file')
    error('找不到 CSV 文件：%s', inPath);
end

[inDir, stem, ~] = fileparts(inPath);
outDir = fullfile(inDir, cfg.outFolderName);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
safeStem = localSafeFileStem(stem);

rawCell = localReadCsv(inPath);
dataColIndex = localResolveColumn(rawCell, cfg.dataCol, 'dataCol');
validColIndex = localResolveOptionalColumn(rawCell, cfg.validCol, 'validCol');
firstDataRow = localResolveFirstDataRow(rawCell, cfg.firstDataRow);

rawWords = rawCell(firstDataRow:end, dataColIndex);
rawCode = localParseCodeColumn(rawWords, cfg.dataRadix, cfg.adcBits);

if isempty(validColIndex)
    validMask = true(size(rawCode));
else
    validValues = rawCell(firstDataRow:end, validColIndex);
    validMask = localParseNumericColumn(validValues) == cfg.validValue;
end

validMask = validMask & isfinite(rawCode);
rawCode = rawCode(validMask);

if isfinite(cfg.maxSamples)
    rawCode = rawCode(1:min(numel(rawCode), cfg.maxSamples));
end

if numel(rawCode) < 16
    error('有效数据点太少：%d。请检查 dataCol、dataRadix、firstDataRow 或 validCol。', numel(rawCode));
end

signedCode = localCodeToSigned(rawCode, cfg.adcBits, cfg.outputCoding);
signedCode = signedCode(:);

if cfg.removeMean
    codeNoise = signedCode - mean(signedCode);
else
    codeNoise = signedCode;
end
inputNoiseV = codeNoise * L_ADC;

[win, winLen, overlap] = localMakeWelchWindow(numel(inputNoiseV), cfg.welch);
[psdInput, freqHz] = pwelch(inputNoiseV, win, overlap, cfg.welch.nfft, cfg.fs);
asdInput_nV = sqrt(psdInput) * 1e9;

summaryTable = localMakeSummaryTable(freqHz, psdInput, asdInput_nV, ...
    cfg.analysisBands, cfg.fs);
summaryTable.InputFile = repmat(string(inPath), height(summaryTable), 1);
summaryTable.OutputDir = repmat(string(outDir), height(summaryTable), 1);
summaryTable.AnalysisName = repmat(string(cfg.analysisName), height(summaryTable), 1);
summaryTable.L_ADC_V_per_code = repmat(L_ADC, height(summaryTable), 1);
summaryTable = movevars(summaryTable, ...
    {'AnalysisName', 'InputFile', 'OutputDir', 'L_ADC_V_per_code'}, ...
    'Before', 1);

resultMat = fullfile(outDir, [safeStem '_adc_input_noise.mat']);
summaryCsv = fullfile(outDir, [safeStem '_adc_input_noise_summary.csv']);
asdPng = fullfile(outDir, [safeStem '_adc_input_noise_ASD.png']);
psdPng = fullfile(outDir, [safeStem '_adc_input_noise_PSD.png']);
previewPng = fullfile(outDir, [safeStem '_code_preview.png']);

writetable(summaryTable, summaryCsv, 'Encoding', 'UTF-8');
save(resultMat, 'cfg', 'L_ADC', 'inPath', 'rawCode', 'signedCode', ...
    'codeNoise', 'inputNoiseV', 'freqHz', 'psdInput', 'asdInput_nV', ...
    'summaryTable', 'winLen', 'overlap', '-v7.3');

localSaveAsdPlot(freqHz, asdInput_nV, cfg, summaryTable, asdPng, stem);
localSavePsdPlot(freqHz, psdInput, cfg, summaryTable, psdPng, stem);
localSaveCodePreview(signedCode, codeNoise, inputNoiseV, cfg, previewPng, stem);

result = struct();
result.summaryTable = summaryTable;
result.outDir = outDir;
result.sampleCount = numel(signedCode);
result.signedCodeMean = mean(signedCode);
result.signedCodeStd = std(signedCode);
result.inputNoiseStdV = std(inputNoiseV);
end

function L_ADC = localResolveLadc(cfg)
%localResolveLadc - 从手动值或标定 summary 解析 ADC 斜率
switch lower(string(cfg.calibrationMode))
    case "manual"
        L_ADC = cfg.L_ADC_manual;

    case "summarycsv"
        if isempty(cfg.calibrationSummaryCsv) || ~exist(cfg.calibrationSummaryCsv, 'file')
            error('calibrationMode=summaryCsv 时，cfg.calibrationSummaryCsv 必须指向存在的 CSV。');
        end
        summary = readtable(cfg.calibrationSummaryCsv, 'TextType', 'string');
        if ~ismember('slope_v_per_code', summary.Properties.VariableNames)
            error('标定 CSV 中没有 slope_v_per_code 列：%s', cfg.calibrationSummaryCsv);
        end
        L_ADC = summary.slope_v_per_code(1);

    otherwise
        error('cfg.calibrationMode 只能是 manual 或 summaryCsv。');
end

if ~isfinite(L_ADC) || L_ADC <= 0
    error('L_ADC 必须是正的有限数值。');
end
end

function files = localResolveInputFiles(cfg)
%localResolveInputFiles - 规范化固定路径或通过 GUI 选择 CSV
if isfield(cfg, 'inputFiles') && ~isempty(cfg.inputFiles)
    if ischar(cfg.inputFiles) || isstring(cfg.inputFiles)
        files = cellstr(cfg.inputFiles);
    else
        files = cfg.inputFiles;
    end
    files = files(:);
    return;
end

[fileNames, dataDir] = uigetfile({'*.csv', 'Vivado ILA CSV files (*.csv)'}, ...
    '请选择一个或多个 ADC 接地噪声 ILA CSV 文件', cfg.initialDir, ...
    'MultiSelect', 'on');
if isequal(fileNames, 0)
    error('已取消文件选择，未处理任何 CSV 文件。');
end
if ischar(fileNames) || isstring(fileNames)
    fileNames = cellstr(fileNames);
end

files = cell(numel(fileNames), 1);
for i = 1:numel(fileNames)
    files{i} = fullfile(dataDir, fileNames{i});
end
end

function rawCell = localReadCsv(filePath)
%localReadCsv - 以单元格形式读取 CSV，保留十六进制文本
rawCell = readcell(filePath, 'Delimiter', ',');
end

function colIndex = localResolveColumn(rawCell, colSpec, name)
%localResolveColumn - 将列号或表头名称解析为有效列索引
if isnumeric(colSpec)
    colIndex = colSpec;
elseif ischar(colSpec) || isstring(colSpec)
    header = string(rawCell(1, :));
    match = find(header == string(colSpec), 1);
    if isempty(match)
        error('找不到列 %s="%s"。', name, string(colSpec));
    end
    colIndex = match;
else
    error('%s 必须是列号或表头字符串。', name);
end

if colIndex < 1 || colIndex > size(rawCell, 2)
    error('%s 列号超出范围：%d。CSV 共有 %d 列。', name, colIndex, size(rawCell, 2));
end
end

function colIndex = localResolveOptionalColumn(rawCell, colSpec, name)
%localResolveOptionalColumn - 解析可以留空的 valid 列配置
if isempty(colSpec)
    colIndex = [];
else
    colIndex = localResolveColumn(rawCell, colSpec, name);
end
end

function firstDataRow = localResolveFirstDataRow(rawCell, firstDataRowSetting)
%localResolveFirstDataRow - 按手动值或 Radix 行定位数据起点
if isnumeric(firstDataRowSetting)
    firstDataRow = firstDataRowSetting;
    return;
end

if ~strcmpi(string(firstDataRowSetting), "auto")
    error('firstDataRow 只能是数值或 auto。');
end

firstDataRow = 2;
if size(rawCell, 1) >= 2 && ~localIsCellMissing(rawCell{2, 1})
    textValue = strtrim(char(string(rawCell{2, 1})));
    if strncmpi(textValue, 'Radix', 5)
        firstDataRow = 3;
    end
end
end

function code = localParseCodeColumn(values, dataRadix, adcBits)
%localParseCodeColumn - 按十六进制或十进制解析原始 ADC 码
code = NaN(numel(values), 1);
for i = 1:numel(values)
    value = values{i};
    if localIsCellMissing(value)
        continue;
    end

    if isnumeric(value) || islogical(value)
        textValue = sprintf('%.0f', double(value));
    else
        textValue = char(string(value));
    end
    textValue = regexprep(strtrim(textValue), '\s+', '');
    textValue = regexprep(textValue, '^0[xX]', '');

    if isempty(textValue)
        continue;
    end

    switch lower(string(dataRadix))
        case "hex"
            if ~all(isstrprop(textValue, 'xdigit'))
                continue;
            end
            code(i) = mod(hex2dec(textValue), 2^adcBits);

        case "decimal"
            codeValue = str2double(textValue);
            if isfinite(codeValue)
                code(i) = mod(codeValue, 2^adcBits);
            end

        otherwise
            error('dataRadix 只能是 hex 或 decimal。');
    end
end
end

function values = localParseNumericColumn(rawValues)
%localParseNumericColumn - 将 valid 等辅助列转换为 double
values = NaN(numel(rawValues), 1);
for i = 1:numel(rawValues)
    value = rawValues{i};
    if localIsCellMissing(value)
        continue;
    end
    if isnumeric(value) || islogical(value)
        values(i) = double(value);
    else
        values(i) = str2double(strtrim(char(string(value))));
    end
end
end

function signedCode = localCodeToSigned(rawCode, adcBits, outputCoding)
%localCodeToSigned - 按位宽和码型把原始码转换为有符号码
switch lower(string(outputCoding))
    case "twos_complement"
        signedCode = double(rawCode);
        wrapMask = signedCode >= 2^(adcBits - 1);
        signedCode(wrapMask) = signedCode(wrapMask) - 2^adcBits;

    case "offset_binary"
        signedCode = double(rawCode) - 2^(adcBits - 1);

    case "unipolar"
        signedCode = double(rawCode);

    otherwise
        error('outputCoding 只能是 twos_complement、offset_binary 或 unipolar。');
end
end

function [win, winLen, overlap] = localMakeWelchWindow(nx, welchCfg)
%localMakeWelchWindow - 按分段数、重叠率和可选 NFFT 构造 Welch 窗
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

function summaryTable = localMakeSummaryTable(freqHz, psd, asd_nV, bands, fs)
%localMakeSummaryTable - 统计每个频段并生成覆盖和限值判定
nBands = numel(bands);
bandName = strings(nBands, 1);
startHz = nan(nBands, 1);
endHz = nan(nBands, 1);
exceedsNyquist = false(nBands, 1);
hasData = false(nBands, 1);
asdLimit_nV = nan(nBands, 1);
asdMedian_nV = nan(nBands, 1);
asdMean_nV = nan(nBands, 1);
asdMax_nV = nan(nBands, 1);
psdMedian_V2Hz = nan(nBands, 1);
psdMean_V2Hz = nan(nBands, 1);
psdMax_V2Hz = nan(nBands, 1);
pointsLeLimitPercent = nan(nBands, 1);
judgment = strings(nBands, 1);
note = strings(nBands, 1);

for k = 1:nBands
    bandName(k) = string(bands(k).name);
    bandRange = double(bands(k).rangeHz(:)).';
    if numel(bandRange) ~= 2 || any(~isfinite(bandRange)) || bandRange(1) < 0 || bandRange(2) <= bandRange(1)
        error('cfg.analysisBands(%d).rangeHz 无效。', k);
    end

    startHz(k) = bandRange(1);
    endHz(k) = bandRange(2);
    exceedsNyquist(k) = endHz(k) > fs / 2;

    if isfield(bands(k), 'asdLimit_nV') && ~isempty(bands(k).asdLimit_nV)
        asdLimit_nV(k) = bands(k).asdLimit_nV(1);
    end

    bandMask = freqHz >= startHz(k) & freqHz <= endHz(k);
    hasData(k) = any(bandMask);

    if hasData(k)
        bandAsd = asd_nV(bandMask);
        bandPsd = psd(bandMask);
        asdMedian_nV(k) = median(bandAsd, 'omitnan');
        asdMean_nV(k) = mean(bandAsd, 'omitnan');
        asdMax_nV(k) = max(bandAsd, [], 'omitnan');
        psdMedian_V2Hz(k) = median(bandPsd, 'omitnan');
        psdMean_V2Hz(k) = mean(bandPsd, 'omitnan');
        psdMax_V2Hz(k) = max(bandPsd, [], 'omitnan');
    end

    if exceedsNyquist(k)
        judgment(k) = "无法判定";
        note(k) = "频段超出 Nyquist";
    elseif ~hasData(k)
        judgment(k) = "无法判定";
        note(k) = "该频段没有频点";
    elseif isnan(asdLimit_nV(k))
        judgment(k) = "仅统计";
        note(k) = "未设置指标线";
    else
        pointsLeLimitPercent(k) = mean(asd_nV(bandMask) <= asdLimit_nV(k), 'omitnan') * 100;
        if asdMedian_nV(k) <= asdLimit_nV(k)
            judgment(k) = "通过";
        else
            judgment(k) = "未通过";
        end
        note(k) = "按 ASD 中位数判定";
    end
end

summaryTable = table(bandName, startHz, endHz, exceedsNyquist, hasData, ...
    asdLimit_nV, asdMedian_nV, asdMean_nV, asdMax_nV, ...
    psdMedian_V2Hz, psdMean_V2Hz, psdMax_V2Hz, ...
    pointsLeLimitPercent, judgment, note, ...
    'VariableNames', {'BandName', 'StartHz', 'EndHz', 'ExceedsNyquist', 'HasData', ...
    'AsdLimit_nV', 'AsdMedian_nV', 'AsdMean_nV', 'AsdMax_nV', ...
    'PsdMedian_V2Hz', 'PsdMean_V2Hz', 'PsdMax_V2Hz', ...
    'PointsLeLimitPercent', 'Judgment', 'Note'});
end

function localSaveAsdPlot(freqHz, asd_nV, cfg, summaryTable, outPath, stem)
%localSaveAsdPlot - 保存 ADC 输入等效 ASD 频谱图
visibleState = localVisibleState(cfg.showFigures);
[freqPlot, asdPlot] = localThinForPlot(freqHz, asd_nV);

fig = figure('Name', [stem ' ADC input ASD'], 'Visible', visibleState, 'Color', 'w');
loglog(freqPlot, asdPlot, 'LineWidth', 1.1);
grid on;
hold on;
localDrawBandMarkers(summaryTable, true);
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent ASD (nV/sqrtHz)');
title(sprintf('%s ADC input-equivalent ASD', stem), 'Interpreter', 'none');
exportgraphics(fig, outPath, 'Resolution', cfg.plotDpi, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function localSavePsdPlot(freqHz, psd, cfg, summaryTable, outPath, stem)
%localSavePsdPlot - 保存 ADC 输入等效 PSD 频谱图
visibleState = localVisibleState(cfg.showFigures);
[freqPlot, psdPlot] = localThinForPlot(freqHz, psd);

fig = figure('Name', [stem ' ADC input PSD'], 'Visible', visibleState, 'Color', 'w');
loglog(freqPlot, psdPlot, 'LineWidth', 1.1);
grid on;
hold on;
localDrawBandMarkers(summaryTable, false);
xlabel('Frequency (Hz)');
ylabel('ADC input-equivalent PSD (V^2/Hz)');
title(sprintf('%s ADC input-equivalent PSD', stem), 'Interpreter', 'none');
exportgraphics(fig, outPath, 'Resolution', cfg.plotDpi, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function localDrawBandMarkers(summaryTable, isAsd)
%localDrawBandMarkers - 绘制频段边界及 ASD/PSD 对应限值线
for k = 1:height(summaryTable)
    if summaryTable.ExceedsNyquist(k)
        continue;
    end
    xline(summaryTable.StartHz(k), ':k');
    xline(summaryTable.EndHz(k), ':k');
    if isAsd && isfinite(summaryTable.AsdLimit_nV(k))
        yline(summaryTable.AsdLimit_nV(k), '--r', ...
            sprintf('%.4g nV/sqrtHz', summaryTable.AsdLimit_nV(k)), ...
            'LineWidth', 1);
    elseif ~isAsd && isfinite(summaryTable.AsdLimit_nV(k))
        yline((summaryTable.AsdLimit_nV(k) * 1e-9)^2, '--r', ...
            'ASD limit as PSD', 'LineWidth', 1);
    end
end
end

function localSaveCodePreview(signedCode, codeNoise, inputNoiseV, cfg, outPath, stem)
%localSaveCodePreview - 保存有限点数的码流和输入电压时域预览
visibleState = localVisibleState(cfg.showFigures);
previewN = min(numel(signedCode), cfg.previewPoints);
idx = 1:previewN;

fig = figure('Name', [stem ' code preview'], 'Visible', visibleState, ...
    'Color', 'w', 'Position', [80 80 1200 760]);

subplot(2, 2, 1);
plot(idx, signedCode(idx), 'LineWidth', 0.8);
grid on;
xlabel('Sample index');
ylabel('Signed code');
title('Signed code preview');

subplot(2, 2, 2);
histogram(signedCode, 100);
grid on;
xlabel('Signed code');
ylabel('Count');
title('Signed code histogram');

subplot(2, 2, 3);
plot(idx, codeNoise(idx), 'LineWidth', 0.8);
grid on;
xlabel('Sample index');
ylabel('Code noise');
title('Mean-removed code noise');

subplot(2, 2, 4);
plot(idx, inputNoiseV(idx) * 1e6, 'LineWidth', 0.8);
grid on;
xlabel('Sample index');
ylabel('Input noise (uV)');
title('Input-equivalent noise preview');

sgtitle(sprintf('%s code/data check', stem), 'Interpreter', 'none');
exportgraphics(fig, outPath, 'Resolution', cfg.plotDpi, 'BackgroundColor', 'white');
if ~cfg.showFigures
    close(fig);
end
end

function visibleState = localVisibleState(showFigures)
%localVisibleState - 将逻辑绘图开关转换为 figure Visible 值
if showFigures
    visibleState = 'on';
else
    visibleState = 'off';
end
end

function [freqPlot, yPlot] = localThinForPlot(freqHz, y)
%localThinForPlot - 对绘图数据抽点，不影响完整频谱保存和统计
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

function cfg = localApplyOverrides(cfg, overrides)
%localApplyOverrides - 用工作区结构覆盖顶层配置字段
fields = fieldnames(overrides);
for i = 1:numel(fields)
    name = fields{i};
    if isstruct(overrides.(name)) && isfield(cfg, name) && isstruct(cfg.(name))
        cfg.(name) = localApplyOverrides(cfg.(name), overrides.(name));
    else
        cfg.(name) = overrides.(name);
    end
end
end

function textValue = localValueToText(value)
%localValueToText - 将配置值格式化为控制台可读文本
if isnumeric(value)
    textValue = num2str(value);
elseif isstring(value) || ischar(value)
    textValue = char(string(value));
else
    textValue = '<unsupported>';
end
end

function safeStem = localSafeFileStem(stem)
%localSafeFileStem - 将输入文件名转换为安全输出前缀
safeStem = regexprep(stem, '[<>:"/\\|?*\s]+', '_');
safeStem = regexprep(safeStem, '_+', '_');
safeStem = regexprep(safeStem, '^_|_$', '');
if isempty(safeStem)
    safeStem = 'adc_grounded_noise';
end
end

function tf = localIsCellMissing(value)
%localIsCellMissing - 统一判断空值、missing 和 NaN 单元格
try
    tf = ismissing(value);
    tf = all(tf(:));
catch
    tf = false;
end
end

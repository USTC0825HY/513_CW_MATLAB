function results = adc_bandwidth_analysis(dataFolder, selectedFileNames)
%ADC_BANDWIDTH_ANALYSIS 用正弦拟合计算 ADC 频率响应和 -3 dB 带宽。
%   RESULTS = ADC_BANDWIDTH_ANALYSIS() 使用默认目录并弹窗选择 CSV。
%   RESULTS = ADC_BANDWIDTH_ANALYSIS(DATAFOLDER, FILES) 直接批量处理。
%
%   输入频率从文件名的 Hz/kHz/MHz/GHz 字段提取。

%% 用户配置区：更换 ADC 或测试条件时只修改这里
sampleRate = 25e6;                 % ADC 采样率，Hz
adcBits = 14;                      % ADC 分辨率，bit
adcCodeFormat = "signed";          % "signed" 或 "unsigned"
adcDataColumn = 0;                 % 0 表示 CSV 最后一列
minimumFitR2 = 0.99;               % 正弦拟合最低 R²
referenceUpperFrequencyHz = 1e6;   % 低频参考点上限，Hz
fitCycles = 20;                    % 参与拟合的正弦周期数
minimumFitSamples = 1024;          % 最少拟合样本数
saveFigures = true;                % 保存 PNG 和 FIG
showFigures = false;               % 批处理时建议 false

%% 选择数据
scriptFolder = fileparts(mfilename('fullpath'));
moduleFolder = fullfile(scriptFolder, '..', 'sfdr');
addpath(moduleFolder);
assert(exist('analyze_adc_metrics', 'file') == 2, ...
    '找不到公共计算模块：%s', moduleFolder);

defaultFolder = fullfile(scriptFolder, '..', '..', 'DATA_GS', '9245', ...
    'freq_scale', 'X3G');
if nargin < 1 || isempty(dataFolder)
    dataFolder = defaultFolder;
end
if nargin < 2
    selectedFileNames = [];
end
[fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, ...
    '选择频率响应 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，带宽分析已取消。\n');
    results = table;
    return;
end

frequencyHz = cellfun(@extractFrequencyHz, fileNames);
parseValid = isfinite(frequencyHz) & frequencyHz > 0;
if any(~parseValid)
    fprintf('以下文件名无法解析频率，已忽略：\n');
    fprintf('  %s\n', fileNames{~parseValid});
    fileNames = fileNames(parseValid);
    frequencyHz = frequencyHz(parseValid);
end
if isempty(fileNames)
    error('没有可解析频率的 CSV 文件。');
end

resultsFolder = fullfile(dataFolder, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

%% 正弦拟合：以下通常无需修改
adcFullScalePeakCode = 2^(adcBits - 1);
fileCount = numel(fileNames);
codePp = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);

for fileIndex = 1:fileCount
    adcCode = readAdcCode(fullfile(dataFolder, fileNames{fileIndex}), ...
        adcDataColumn, adcBits, adcCodeFormat);
    config = struct( ...
        'sampleRate', sampleRate, ...
        'adcFullScalePeakCode', adcFullScalePeakCode, ...
        'fitCycles', fitCycles, ...
        'minimumFitSamples', minimumFitSamples, ...
        'fitMode', 'known', ...
        'knownFrequencyHz', frequencyHz(fileIndex));
    metrics = analyze_adc_metrics(adcCode, config);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
end

[frequencyHz, sortIndex] = sort(frequencyHz(:));
fileNames = fileNames(sortIndex);
codePp = codePp(sortIndex);
fitR2 = fitR2(sortIndex);
fitResidualRmsCode = fitResidualRmsCode(sortIndex);

validForBandwidth = isfinite(codePp) & codePp > 0 & ...
    isfinite(fitR2) & fitR2 >= minimumFitR2;
if any(~validForBandwidth)
    fprintf('\n以下异常文件不参与带宽计算：\n');
    fprintf('  %s\n', fileNames{~validForBandwidth});
end
if nnz(validForBandwidth) < 2
    error('有效频率点少于 2 个，无法计算带宽。');
end

validFrequencyHz = frequencyHz(validForBandwidth);
validCodePp = codePp(validForBandwidth);
referenceMask = validFrequencyHz <= referenceUpperFrequencyHz;
if ~any(referenceMask)
    error('没有低于参考频率上限 %.6g Hz 的有效数据。', ...
        referenceUpperFrequencyHz);
end
referenceCodePp = median(validCodePp(referenceMask));
relativeDb = NaN(fileCount, 1);
relativeDb(validForBandwidth) = ...
    20 * log10(validCodePp / referenceCodePp);
bandwidth3dBHz = findThreeDbCrossing( ...
    validFrequencyHz, relativeDb(validForBandwidth));

results = table(string(fileNames(:)), frequencyHz, codePp, relativeDb, ...
    fitR2, fitResidualRmsCode, validForBandwidth, ...
    repmat(bandwidth3dBHz, fileCount, 1), ...
    'VariableNames', {'FileName', 'FrequencyHz', 'CodePp', 'RelativeDb', ...
    'FitR2', 'FitResidualRmsCode', 'ValidForBandwidth', ...
    'Bandwidth3dBHz'});
writetable(results, fullfile(resultsFolder, 'ADC_bandwidth_summary.csv'));
plotResult(results, bandwidth3dBHz, sampleRate, resultsFolder, ...
    saveFigures, showFigures);

disp(results);
fprintf('\n估算 -3 dB 带宽：%.6f MHz\n', bandwidth3dBHz / 1e6);
fprintf('带宽结果已保存至：%s\n', resultsFolder);
end

%% 本地辅助函数：通常无需修改
function [fileNames, dataFolder] = selectCsvFiles( ...
        dataFolder, selectedFileNames, dialogTitle)
if ~isfolder(dataFolder)
    error('数据目录不存在：%s', dataFolder);
end
if isempty(selectedFileNames)
    [selectedFileNames, selectedPath] = uigetfile( ...
        fullfile(dataFolder, '*.csv'), dialogTitle, 'MultiSelect', 'on');
    if isequal(selectedFileNames, 0)
        fileNames = {};
        return;
    end
    dataFolder = selectedPath;
end
if ischar(selectedFileNames) || isstring(selectedFileNames)
    selectedFileNames = cellstr(selectedFileNames);
end
fileNames = selectedFileNames(:).';
end

function frequencyHz = extractFrequencyHz(fileName)
token = regexp(char(fileName), ...
    '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz)', 'tokens', 'once');
if isempty(token)
    frequencyHz = NaN;
    return;
end
scales = struct('hz', 1, 'khz', 1e3, 'mhz', 1e6, 'ghz', 1e9);
frequencyHz = str2double(token{1}) * scales.(lower(token{2}));
end

function adcCode = readAdcCode(filePath, dataColumn, adcBits, codeFormat)
numericData = readmatrix(filePath);
if isempty(numericData)
    error('CSV 中没有数值数据：%s', filePath);
end
if dataColumn == 0
    dataColumn = size(numericData, 2);
end
if dataColumn < 1 || dataColumn > size(numericData, 2)
    error('ADC 数据列超出 CSV 列范围：%s', filePath);
end
adcCode = double(numericData(:, dataColumn));
adcCode = adcCode(isfinite(adcCode));
if strcmpi(codeFormat, "unsigned")
    adcCode = adcCode - 2^(adcBits - 1);
elseif ~strcmpi(codeFormat, "signed")
    error('adcCodeFormat 只能是 "signed" 或 "unsigned"。');
end
fullScalePeak = 2^(adcBits - 1);
if any(adcCode < -fullScalePeak | adcCode > fullScalePeak - 1)
    warning('文件 %s 的码值超出 %d 位 ADC 范围。', filePath, adcBits);
end
end

function bandwidthHz = findThreeDbCrossing(frequencyHz, relativeDb)
crossingIndex = find(relativeDb(1:end-1) >= -3 & ...
    relativeDb(2:end) <= -3, 1, 'first');
if isempty(crossingIndex)
    bandwidthHz = NaN;
    warning('测试范围内未找到 -3 dB 交点。');
    return;
end
f1 = frequencyHz(crossingIndex);
f2 = frequencyHz(crossingIndex + 1);
db1 = relativeDb(crossingIndex);
db2 = relativeDb(crossingIndex + 1);
bandwidthHz = f1 + (-3 - db1) * (f2 - f1) / (db2 - db1);
end

function plotResult(results, bandwidthHz, sampleRate, ...
        resultsFolder, saveFigures, showFigures)
if showFigures
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 频率响应', 'NumberTitle', 'off');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('ADC 频率响应，Fs = %.3f MHz', sampleRate / 1e6));

valid = results.ValidForBandwidth;
nexttile;
semilogx(results.FrequencyHz(valid), results.CodePp(valid), ...
    'bo-', 'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
semilogx(results.FrequencyHz(~valid), results.CodePp(~valid), ...
    'rx', 'LineWidth', 1.5, 'MarkerSize', 9);
hold off;
grid on;
xlabel('输入频率 (Hz)');
ylabel('拟合 Code_{pp} (LSB)');
title('ADC 码值峰峰值响应');
legend('有效数据', '异常数据', 'Location', 'best');

nexttile;
semilogx(results.FrequencyHz(valid), results.RelativeDb(valid), ...
    'ro-', 'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
yline(-3, '--k', '-3 dB');
if isfinite(bandwidthHz)
    xline(bandwidthHz, '--g', sprintf('带宽 %.4f MHz', bandwidthHz / 1e6), ...
        'LabelVerticalAlignment', 'middle');
end
hold off;
grid on;
xlabel('输入频率 (Hz)');
ylabel('相对幅度 (dB)');
title('归一化幅频响应');

if saveFigures
    outputStem = fullfile(resultsFolder, 'ADC_bandwidth_result');
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
if ~showFigures
    close(figureHandle);
end
end

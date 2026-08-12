function results = adc_power_scale_analysis(dataFolder, selectedFileNames)
%ADC_POWER_SCALE_ANALYSIS 建立输入 dBm 与 ADC 码值/dBFS 的标定关系。
%   RESULTS = ADC_POWER_SCALE_ANALYSIS() 使用默认目录并弹窗选择 CSV。
%   RESULTS = ADC_POWER_SCALE_ANALYSIS(DATAFOLDER, FILES) 直接批量处理。
%
%   输入功率从文件名提取，输出保存在数据目录的 results 子目录。

%% 用户配置区：更换 ADC 或测试条件时只修改这里
sampleRate = 25e6;                 % ADC 采样率，Hz
adcBits = 14;                      % ADC 分辨率，bit
adcCodeFormat = "signed";          % "signed" 或 "unsigned"
adcDataColumn = 0;                 % 0 表示 CSV 最后一列
testFrequencyHz = 1e6;             % 功率标定正弦频率，Hz
powerRangeDbm = [-10 6];           % 正式标定范围，dBm
clippingThreshold = 0.98;          % 接近满量程的码值比例
clippingFractionLimit = 0.01;      % 削顶样本占比门限
plateauChangeThreshold = 0.01;     % 相邻 Code_pp 平台判定门限
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
    'Power_Scale_1MHz');
if nargin < 1 || isempty(dataFolder)
    dataFolder = defaultFolder;
end
if nargin < 2
    selectedFileNames = [];
end
[fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, ...
    '选择输入功率标定 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，功率标定已取消。\n');
    results = table;
    return;
end

inputPowerDbm = cellfun(@extractPowerDbm, fileNames);
parseValid = isfinite(inputPowerDbm);
if any(~parseValid)
    fprintf('以下文件名无法解析 dBm，已忽略：\n');
    fprintf('  %s\n', fileNames{~parseValid});
    fileNames = fileNames(parseValid);
    inputPowerDbm = inputPowerDbm(parseValid);
end
if isempty(fileNames)
    error('没有可解析输入功率的 CSV 文件。');
end

resultsFolder = fullfile(dataFolder, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

%% 正弦拟合：以下通常无需修改
adcFullScalePeakCode = 2^(adcBits - 1);
fileCount = numel(fileNames);
channelNames = strings(fileCount, 1);
codePp = NaN(fileCount, 1);
codeRms = NaN(fileCount, 1);
codeRmsDbfs = NaN(fileCount, 1);
peakCode = NaN(fileCount, 1);
valleyCode = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);
nearFullScaleFraction = NaN(fileCount, 1);

for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(dataFolder, fileName);
    channelNames(fileIndex) = detectChannel(filePath, fileName, dataFolder);
    adcCode = readAdcCode(filePath, adcDataColumn, adcBits, adcCodeFormat);
    config = struct( ...
        'sampleRate', sampleRate, ...
        'adcFullScalePeakCode', adcFullScalePeakCode, ...
        'fitCycles', fitCycles, ...
        'minimumFitSamples', minimumFitSamples, ...
        'fitMode', 'known', ...
        'knownFrequencyHz', testFrequencyHz);
    metrics = analyze_adc_metrics(adcCode, config);

    codePp(fileIndex) = metrics.fit.codePp;
    codeRms(fileIndex) = codePp(fileIndex) / (2 * sqrt(2));
    codeRmsDbfs(fileIndex) = ...
        20 * log10(codeRms(fileIndex) / adcFullScalePeakCode);
    peakCode(fileIndex) = metrics.fit.peakCode;
    valleyCode(fileIndex) = metrics.fit.valleyCode;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    nearFullScaleFraction(fileIndex) = mean( ...
        abs(adcCode) >= clippingThreshold * adcFullScalePeakCode);
end

[inputPowerDbm, sortIndex] = sort(inputPowerDbm(:));
fileNames = fileNames(sortIndex);
channelNames = channelNames(sortIndex);
codePp = codePp(sortIndex);
codeRms = codeRms(sortIndex);
codeRmsDbfs = codeRmsDbfs(sortIndex);
peakCode = peakCode(sortIndex);
valleyCode = valleyCode(sortIndex);
fitR2 = fitR2(sortIndex);
fitResidualRmsCode = fitResidualRmsCode(sortIndex);
nearFullScaleFraction = nearFullScaleFraction(sortIndex);

clippingFlag = nearFullScaleFraction > clippingFractionLimit;
plateauFlag = false(fileCount, 1);
for fileIndex = 2:fileCount
    relativeChange = abs(codePp(fileIndex) - codePp(fileIndex - 1)) / ...
        max(codePp(fileIndex - 1), eps);
    plateauFlag(fileIndex) = relativeChange <= plateauChangeThreshold;
end
inSpecifiedRange = inputPowerDbm >= powerRangeDbm(1) & ...
    inputPowerDbm <= powerRangeDbm(2);
calibrationIncluded = inSpecifiedRange & ~clippingFlag & ~plateauFlag;
if nnz(calibrationIncluded) < 2
    error('正式范围内有效标定点少于 2 个。');
end

coefficient = polyfit(inputPowerDbm(calibrationIncluded), ...
    codeRmsDbfs(calibrationIncluded), 1);
predictedDbfs = polyval(coefficient, inputPowerDbm);
calibrationResidualDb = codeRmsDbfs - predictedDbfs;
measuredForFit = codeRmsDbfs(calibrationIncluded);
residualForFit = calibrationResidualDb(calibrationIncluded);
calibrationR2 = 1 - sum(residualForFit.^2) / ...
    max(sum((measuredForFit - mean(measuredForFit)).^2), eps);

uniqueChannels = unique(channelNames);
uniqueChannels(uniqueChannels == "") = [];
if isscalar(uniqueChannels)
    channelName = uniqueChannels(1);
else
    channelName = "Unknown";
    warning('无法确定唯一 ADC 通道，输出通道标记为 Unknown。');
end

results = table( ...
    repmat(channelName, fileCount, 1), string(fileNames(:)), ...
    inputPowerDbm, repmat(testFrequencyHz, fileCount, 1), ...
    codePp, codeRms, codeRmsDbfs, peakCode, valleyCode, fitR2, ...
    fitResidualRmsCode, nearFullScaleFraction, clippingFlag, plateauFlag, ...
    inSpecifiedRange, calibrationIncluded, calibrationResidualDb, ...
    repmat(coefficient(1), fileCount, 1), ...
    repmat(coefficient(2), fileCount, 1), ...
    repmat(calibrationR2, fileCount, 1), ...
    'VariableNames', {'Channel', 'FileName', 'InputPowerDbm', ...
    'FrequencyHz', 'CodePp', 'CodeRms', 'CodeRmsDbfs', 'PeakCode', ...
    'ValleyCode', 'FitR2', 'FitResidualRmsCode', ...
    'NearFullScaleFraction', 'ClippingFlag', 'PlateauFlag', ...
    'InSpecifiedRange', 'CalibrationIncluded', 'CalibrationResidualDb', ...
    'CalibrationSlopeDbPerDbm', 'CalibrationInterceptDb', ...
    'CalibrationR2'});
writetable(results, fullfile(resultsFolder, 'ADC_power_scale_summary.csv'));
plotResult(results, coefficient, calibrationR2, powerRangeDbm, ...
    adcFullScalePeakCode, channelName, resultsFolder, ...
    saveFigures, showFigures);

disp(results);
fprintf('\n通道：%s\n', channelName);
fprintf('标定斜率：%.6f dB/dBm\n', coefficient(1));
fprintf('标定截距：%.6f dBFS\n', coefficient(2));
fprintf('标定 R²：%.8f\n', calibrationR2);
fprintf('功率标定结果已保存至：%s\n', resultsFolder);
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

function powerDbm = extractPowerDbm(fileName)
token = regexp(char(fileName), ...
    '(?i)(-?\d+(?:\.\d+)?)\s*dBm', 'tokens', 'once');
if isempty(token)
    powerDbm = NaN;
else
    powerDbm = str2double(token{1});
end
end

function channelName = detectChannel(filePath, fileName, dataFolder)
channelName = extractChannel(fileName);
fileId = fopen(filePath, 'r');
if fileId < 0
    error('无法打开 CSV：%s', filePath);
end
header = fgetl(fileId);
fclose(fileId);
if ischar(header)
    token = regexp(header, ...
        '(?i)ad9245_test_module\[(\d+)\]', 'tokens', 'once');
    if ~isempty(token)
        moduleIndex = str2double(token{1});
        if ismember(moduleIndex, 0:3)
            channelName = "X" + string(moduleIndex + 1) + "G";
            return;
        end
    end
end
if strlength(channelName) == 0
    channelName = extractChannel(dataFolder);
end
end

function channelName = extractChannel(textValue)
token = regexp(upper(char(textValue)), 'X([1-4])G', 'tokens', 'once');
if isempty(token)
    channelName = "";
else
    channelName = "X" + string(token{1}) + "G";
end
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

function plotResult(results, coefficient, calibrationR2, powerRangeDbm, ...
        adcFullScalePeakCode, channelName, resultsFolder, ...
        saveFigures, showFigures)
if showFigures
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 输入功率标定', 'NumberTitle', 'off');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s | %.3f MHz 输入功率响应', ...
    channelName, results.FrequencyHz(1) / 1e6));

fitPowerDbm = linspace(powerRangeDbm(1), powerRangeDbm(2), 100);
fitDbfs = polyval(coefficient, fitPowerDbm);
fitCodeRms = adcFullScalePeakCode * 10.^(fitDbfs / 20);

nexttile;
plot(results.InputPowerDbm, results.CodePp, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
plot(results.InputPowerDbm(results.ClippingFlag), ...
    results.CodePp(results.ClippingFlag), 'rx', ...
    'LineWidth', 1.8, 'MarkerSize', 10);
plot(results.InputPowerDbm(results.PlateauFlag), ...
    results.CodePp(results.PlateauFlag), 'ks', ...
    'LineWidth', 1.4, 'MarkerSize', 8);
plot(fitPowerDbm, fitCodeRms * 2 * sqrt(2), 'g-', 'LineWidth', 1.2);
xline(powerRangeDbm(1), '--k');
xline(powerRangeDbm(2), '--k');
hold off;
grid on;
xlabel('输入功率 (dBm)');
ylabel('拟合 Code_{pp} (LSB)');
title('ADC 码值响应');
legend('测量值', '削顶风险', '平台点', '线性标定', ...
    '标定范围', 'Location', 'best');

nexttile;
plot(results.InputPowerDbm, results.CodeRmsDbfs, 'ro-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
plot(results.InputPowerDbm(results.ClippingFlag), ...
    results.CodeRmsDbfs(results.ClippingFlag), 'rx', ...
    'LineWidth', 1.8, 'MarkerSize', 10);
plot(results.InputPowerDbm(results.PlateauFlag), ...
    results.CodeRmsDbfs(results.PlateauFlag), 'ks', ...
    'LineWidth', 1.4, 'MarkerSize', 8);
plot(fitPowerDbm, fitDbfs, 'g-', 'LineWidth', 1.2);
xline(powerRangeDbm(1), '--k');
xline(powerRangeDbm(2), '--k');
hold off;
grid on;
xlabel('输入功率 (dBm)');
ylabel('ADC RMS 幅度 (dBFS)');
title(sprintf('dBFS 响应：斜率 %.3f dB/dBm，R² %.5f', ...
    coefficient(1), calibrationR2));
legend('测量值', '削顶风险', '平台点', '线性标定', ...
    '标定范围', 'Location', 'best');

if saveFigures
    outputStem = fullfile(resultsFolder, 'ADC_power_scale_result');
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
if ~showFigures
    close(figureHandle);
end
end

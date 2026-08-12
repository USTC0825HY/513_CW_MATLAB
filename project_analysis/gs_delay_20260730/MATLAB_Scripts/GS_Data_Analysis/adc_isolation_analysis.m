function results = adc_isolation_analysis(dataFolder, selectedFileNames)
%ADC_ISOLATION_ANALYSIS 计算四通道 ADC 的同频串扰隔离度。
%   RESULTS = ADC_ISOLATION_ANALYSIS() 使用默认目录并弹窗选择 CSV。
%   RESULTS = ADC_ISOLATION_ANALYSIS(DATAFOLDER, FILES) 直接批量处理。
%
%   隔离度 = 20*log10(激励通道 Code_pp / 安静通道 Code_pp)。

%% 用户配置区：更换 ADC 或测试条件时只修改这里
sampleRate = 25e6;                 % ADC 采样率，Hz
adcBits = 14;                      % ADC 分辨率，bit
adcCodeFormat = "signed";          % "signed" 或 "unsigned"
adcDataColumn = 0;                 % 0 表示 CSV 最后一列
isolationFrequencyHz = 1e6;        % 隔离度测试频率，Hz
drivenChannel = "X3G";             % 当前输入正弦信号的通道
minimumIsolationDb = 40;           % 合格门限，dB
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
    'GeLiDu', 'X3G_1MHz_7dBm');
if nargin < 1 || isempty(dataFolder)
    dataFolder = defaultFolder;
end
if nargin < 2
    selectedFileNames = [];
end
[fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, ...
    '选择四路隔离度测试 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，隔离度分析已取消。\n');
    results = table;
    return;
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
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);

for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(dataFolder, fileName);
    channelNames(fileIndex) = detectChannel(filePath, fileName, dataFolder);
    if strlength(channelNames(fileIndex)) == 0
        error('无法从文件名或文件头识别通道：%s', fileName);
    end
    adcCode = readAdcCode(filePath, adcDataColumn, adcBits, adcCodeFormat);
    config = struct( ...
        'sampleRate', sampleRate, ...
        'adcFullScalePeakCode', adcFullScalePeakCode, ...
        'fitCycles', fitCycles, ...
        'minimumFitSamples', minimumFitSamples, ...
        'fitMode', 'known', ...
        'knownFrequencyHz', isolationFrequencyHz);
    metrics = analyze_adc_metrics(adcCode, config);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
end

if numel(unique(channelNames)) ~= fileCount
    error('存在重复通道文件，请确保每个通道只选择一个 CSV。');
end
drivenMask = channelNames == drivenChannel;
if nnz(drivenMask) ~= 1
    error('必须且只能找到一个激励通道 %s。', drivenChannel);
end
quietMask = ~drivenMask;
if ~any(quietMask)
    error('没有安静通道数据，无法计算隔离度。');
end

drivenCodePp = codePp(drivenMask);
quietChannels = channelNames(quietMask);
quietCodePp = codePp(quietMask);
isolationDb = 20 * log10(drivenCodePp ./ quietCodePp);
pass = isolationDb >= minimumIsolationDb;

results = table( ...
    repmat(drivenChannel, nnz(quietMask), 1), quietChannels, ...
    repmat(isolationFrequencyHz, nnz(quietMask), 1), ...
    repmat(drivenCodePp, nnz(quietMask), 1), quietCodePp, isolationDb, ...
    fitR2(quietMask), fitResidualRmsCode(quietMask), pass, ...
    'VariableNames', {'DrivenChannel', 'QuietChannel', 'FrequencyHz', ...
    'DrivenCodePp', 'QuietCodePp', 'IsolationDb', 'QuietFitR2', ...
    'QuietResidualRmsCode', 'Pass'});
writetable(results, fullfile(resultsFolder, 'ADC_isolation_summary.csv'));
plotResult(results, drivenChannel, isolationFrequencyHz, ...
    minimumIsolationDb, resultsFolder, saveFigures, showFigures);

disp(results);
fprintf('\n最差隔离度：%.3f dB\n', min(isolationDb));
fprintf('隔离度结果已保存至：%s\n', resultsFolder);
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

function channelName = detectChannel(filePath, fileName, dataFolder)
channelName = extractChannel(fileName);
if strlength(channelName) > 0
    return;
end
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
channelName = extractChannel(dataFolder);
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

function plotResult(results, drivenChannel, frequencyHz, ...
        minimumIsolationDb, resultsFolder, saveFigures, showFigures)
allChannels = ["X1G"; "X2G"; "X3G"; "X4G"];
matrix = NaN(4, 4);
drivenIndex = find(allChannels == drivenChannel, 1);
for rowIndex = 1:height(results)
    quietIndex = find(allChannels == results.QuietChannel(rowIndex), 1);
    matrix(drivenIndex, quietIndex) = results.IsolationDb(rowIndex);
end

if showFigures
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 隔离度', 'NumberTitle', 'off');
imageHandle = imagesc(matrix);
set(imageHandle, 'AlphaData', isfinite(matrix));
axis equal tight;
colormap(parula);
colorbar;
xticks(1:4);
yticks(1:4);
xticklabels(allChannels);
yticklabels(allChannels);
xlabel('安静通道');
ylabel('激励通道');
title(sprintf('ADC %.3f MHz 隔离度，要求 ≥ %.1f dB', ...
    frequencyHz / 1e6, minimumIsolationDb));
set(gca, 'Color', [0.88 0.88 0.88]);
for rowIndex = 1:4
    for columnIndex = 1:4
        if isfinite(matrix(rowIndex, columnIndex))
            text(columnIndex, rowIndex, sprintf('%.2f', ...
                matrix(rowIndex, columnIndex)), ...
                'HorizontalAlignment', 'center', ...
                'Color', 'w', 'FontWeight', 'bold');
        else
            text(columnIndex, rowIndex, '-', ...
                'HorizontalAlignment', 'center');
        end
    end
end

if saveFigures
    outputStem = fullfile(resultsFolder, 'ADC_isolation_result');
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
if ~showFigures
    close(figureHandle);
end
end

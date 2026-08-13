function results = adc_sfdr_analysis(dataFolder, selectedFileNames)
%ADC_SFDR_ANALYSIS 批量计算 ADC 的 SFDR、SNR、SINAD、THD 和 ENOB。
%   RESULTS = ADC_SFDR_ANALYSIS() 使用默认目录并弹窗选择 CSV。
%   RESULTS = ADC_SFDR_ANALYSIS(DATAFOLDER) 在指定目录弹窗选择 CSV。
%   RESULTS = ADC_SFDR_ANALYSIS(DATAFOLDER, FILES) 直接处理指定文件。
%
%   CSV 默认最后一列为 ADC 码值。输出保存在数据目录的 results 子目录。

%% 配置区：更换 ADC 或采样条件时只修改这里
sampleRate = 25e6;                 % ADC 采样率，Hz
adcBits = 14;                      % ADC 分辨率，bit
adcCodeFormat = "signed";          % "signed" 或 "unsigned"
adcDataColumn = 0;                 % 0 表示 CSV 最后一列
nfft = 128 * 1024;                 % FFT 点数
dcSpan = 16;                       % 排除的直流频点数
signalSpan = 16;                   % 基波两侧积分频点数
harmonicSpan = 8;                  % 谐波两侧积分频点数
maxHarmonicOrder = 8;              % THD 最高谐波次数
saveFigures = true;                % 保存 PNG 和 FIG
showFigures = false;               % 批处理时建议 false

%% 选择数据
scriptFolder = fileparts(mfilename('fullpath'));
moduleFolder = fullfile(scriptFolder, '..', 'sfdr');
addpath(moduleFolder);
assert(exist('analyze_adc_metrics', 'file') == 2, ...
    '找不到公共计算模块：%s', moduleFolder);

defaultFolder = fullfile(scriptFolder, '..', '..', 'DATA_GS', '9245', ...
    'SFDR_25MHz_6dBm', 'X3G');
if nargin < 1 || isempty(dataFolder)
    dataFolder = defaultFolder;
end
if nargin < 2
    selectedFileNames = [];
end
[fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, ...
    '选择需要计算 SFDR 的 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，SFDR 分析已取消。\n');
    results = table;
    return;
end

resultsFolder = fullfile(dataFolder, 'results');
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

%% 计算指标：以下通常无需修改
adcFullScalePeakCode = 2^(adcBits - 1);
config = struct( ...
    'sampleRate', sampleRate, ...
    'nfft', nfft, ...
    'adcFullScalePeakCode', adcFullScalePeakCode, ...
    'dcSpan', dcSpan, ...
    'signalSpan', signalSpan, ...
    'harmonicSpan', harmonicSpan, ...
    'maxHarmonicOrder', maxHarmonicOrder, ...
    'fitCycles', 20, ...
    'minimumFitSamples', 1024, ...
    'fitMode', 'auto');

logPath = fullfile(resultsFolder, 'ADC_SFDR_log.txt');
diary(logPath);
diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>

fileCount = numel(fileNames);
fundamentalFrequencyHz = zeros(fileCount, 1);
codePp = zeros(fileCount, 1);
sfdrDb = zeros(fileCount, 1);
snrDb = zeros(fileCount, 1);
sinadDb = zeros(fileCount, 1);
thdDb = zeros(fileCount, 1);
enobBit = zeros(fileCount, 1);

for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(dataFolder, fileName);
    adcCode = readAdcCode(filePath, adcDataColumn, adcBits, adcCodeFormat);
    metrics = analyze_adc_metrics(adcCode, config);

    fundamentalFrequencyHz(fileIndex) = ...
        metrics.spectrum.fundamentalFrequencyHz;
    codePp(fileIndex) = metrics.fit.codePp;
    sfdrDb(fileIndex) = metrics.dynamic.SFDR;
    snrDb(fileIndex) = metrics.dynamic.SNR;
    sinadDb(fileIndex) = metrics.dynamic.SINAD;
    thdDb(fileIndex) = metrics.dynamic.THD;
    enobBit(fileIndex) = metrics.dynamic.ENOB;

    fprintf(['\n文件：%s\n基波：%.6f MHz\nCode_pp：%.3f LSB\n' ...
        'SFDR：%.3f dB，SNR：%.3f dB，SINAD：%.3f dB\n' ...
        'THD：%.3f dB，ENOB：%.3f bit\n'], ...
        fileName, fundamentalFrequencyHz(fileIndex) / 1e6, ...
        codePp(fileIndex), sfdrDb(fileIndex), snrDb(fileIndex), ...
        sinadDb(fileIndex), thdDb(fileIndex), enobBit(fileIndex));

    plotSpectrum(metrics, fileName, resultsFolder, saveFigures, showFigures);
end

results = table(string(fileNames(:)), fundamentalFrequencyHz, codePp, ...
    sfdrDb, snrDb, sinadDb, thdDb, enobBit, ...
    'VariableNames', {'FileName', 'FundamentalFrequencyHz', 'CodePp', ...
    'SFDR', 'SNR', 'SINAD', 'THD', 'ENOB'});
writetable(results, fullfile(resultsFolder, 'ADC_SFDR_summary.csv'));
plotSummary(results, resultsFolder, saveFigures, showFigures);
disp(results);
fprintf('\nSFDR 结果已保存至：%s\n', resultsFolder);
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

function plotSpectrum(metrics, fileName, resultsFolder, saveFigures, showFigures)
visibility = matlab.lang.OnOffSwitchState(showFigures);
figureHandle = figure('Color', 'w', 'Visible', char(visibility), ...
    'Name', ['SFDR - ' fileName], 'NumberTitle', 'off');
frequencyMHz = metrics.spectrum.frequencyHz / 1e6;
levelDbfs = metrics.spectrum.levelDb - ...
    metrics.spectrum.fundamentalLevelDb + metrics.dynamic.signalAmplitudeDbfs;
plot(frequencyMHz, levelDbfs, 'r-', 'LineWidth', 0.8);
hold on;
fundamentalIndex = metrics.spectrum.fundamentalIndex;
spurIndex = metrics.spectrum.largestSpurIndex;
plot(frequencyMHz(fundamentalIndex), levelDbfs(fundamentalIndex), ...
    'ko', 'MarkerFaceColor', 'y');
plot(frequencyMHz(spurIndex), levelDbfs(spurIndex), ...
    'ko', 'MarkerFaceColor', 'c');
yline(levelDbfs(spurIndex), '--g');
hold off;
grid on;
xlabel('频率 (MHz)');
ylabel('幅度 (dBFS)');
title(sprintf('%s | 基波 %.6f MHz', fileName, ...
    metrics.spectrum.fundamentalFrequencyHz / 1e6), 'Interpreter', 'none');
legend('频谱', '基波', '最大杂散', '杂散电平', 'Location', 'northwest');
ylim([-140 0]);
text(0.70, 0.96, sprintf(['SFDR = %.2f dB\nSNR = %.2f dB\n' ...
    'SINAD = %.2f dB\nTHD = %.2f dB\nENOB = %.2f bit'], ...
    metrics.dynamic.SFDR, metrics.dynamic.SNR, metrics.dynamic.SINAD, ...
    metrics.dynamic.THD, metrics.dynamic.ENOB), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'w');

if saveFigures
    [~, fileStem] = fileparts(fileName);
    outputStem = fullfile(resultsFolder, [fileStem '_spectrum']);
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
if ~showFigures
    close(figureHandle);
end
end

function plotSummary(results, resultsFolder, saveFigures, showFigures)
visibility = matlab.lang.OnOffSwitchState(showFigures);
figureHandle = figure('Color', 'w', 'Visible', char(visibility), ...
    'Name', 'SFDR 汇总', 'NumberTitle', 'off');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'ADC 动态指标汇总');
labels = cellstr(erase(results.FileName, ".csv"));

nexttile;
bar([results.SFDR results.SNR results.SINAD results.THD]);
grid on;
ylabel('动态指标 (dB)');
xticks(1:height(results));
xticklabels(labels);
xtickangle(20);
legend('SFDR', 'SNR', 'SINAD', 'THD', ...
    'Location', 'northoutside', 'Orientation', 'horizontal');

nexttile;
plot(1:height(results), results.ENOB, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
grid on;
ylabel('ENOB (bit)');
xlabel('输入文件');
xticks(1:height(results));
xticklabels(labels);
xtickangle(0);

if saveFigures
    outputStem = fullfile(resultsFolder, 'ADC_SFDR_result');
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
if ~showFigures
    close(figureHandle);
end
end

%% PLOT_AD2208_METASTABILITY
% 手动查看 AD2208 ILA 数据中的突变点、毛刺和疑似亚稳态。
%
% 使用方法：
% 1. 修改 dataFolder 为数据目录。
% 2. selectedFileIndex = 1 查看第 1 组；设为 2~60 查看指定组；设为 0 查看全部组概览。
% 3. 运行脚本，重点观察 raw code、Delta code 和 Second difference。
%
% 注意：每个 CSV 是一次独立 ILA 触发记录，文件之间可能有时间空洞。
% 本脚本不会跨文件边界计算差分，也不会把文件边界跳变判为毛刺。

clear;
clc;
close all;

%% 用户参数
dataFolder = ...
    'F:\01_Laser\20260727_513test\03_CW测试\02_Data_测试数据\513_CW_DATA\AD2208\05_INL_DNL\ADC1_JG15\JG15_6.5dBm\yb2208_ch01_20260812_154203';

selectedFileIndex = 1;       % 1~60：详细查看某一组；0：只画全部文件概览
adcDataColumn = 4;           % 当前 ILA CSV 的 ADC 数据在第 4 列
adcBits = 16;
adcCodeFormat = 'signed';     % 'signed' 或 'unsigned'
sampleRateHz = 100e6;

% 这些阈值只是“候选点”阈值，需要结合图形人工确认。
% 当前约 1 MHz、28k code 幅度的正常正弦，一阶差分约为 1800 code 以内。
jumpThresholdCode = 4000;     % 单点突变阈值
secondDifferenceThresholdCode = 500; % 二阶差分阈值

overviewPlotStride = 16;      % 全部文件概览的抽点间隔，1 表示不抽点
saveCandidateTable = true;
resultFolder = fullfile(dataFolder, 'manual_metastability_check');

%% 查找并排序 CSV
if ~isfolder(dataFolder)
    error('plot_ad2208_metastability:DataFolderNotFound', ...
        '数据目录不存在：%s', dataFolder);
end

fileInfo = dir(fullfile(dataFolder, '*.csv'));
if isempty(fileInfo)
    error('plot_ad2208_metastability:NoCsv', ...
        '数据目录中没有 CSV：%s', dataFolder);
end

[~, sortOrder] = sort({fileInfo.name});
fileInfo = fileInfo(sortOrder);
fileCount = numel(fileInfo);

if selectedFileIndex < 0 || selectedFileIndex > fileCount || ...
        selectedFileIndex ~= floor(selectedFileIndex)
    error('plot_ad2208_metastability:InvalidFileIndex', ...
        'selectedFileIndex 必须是 0 到 %d 的整数。', fileCount);
end

if saveCandidateTable && ~isfolder(resultFolder)
    mkdir(resultFolder);
end

%% 读取数据并逐文件分析
candidateRows = cell(0, 8);
overviewX = cell(fileCount, 1);
overviewCode = cell(fileCount, 1);
overviewSecondDifference = cell(fileCount, 1);

for fileIndex = 1:fileCount
    filePath = fullfile(fileInfo(fileIndex).folder, fileInfo(fileIndex).name);
    adcCode = readAdcCode(filePath, adcDataColumn, adcBits, adcCodeFormat);
    sampleCount = numel(adcCode);
    sampleIndex = (0:sampleCount - 1)';

    deltaCode = [NaN; diff(adcCode)];
    secondDifferenceCode = [NaN; NaN; diff(adcCode, 2)];
    candidateMask = abs(deltaCode) > jumpThresholdCode | ...
        abs(secondDifferenceCode) > secondDifferenceThresholdCode;
    candidateMask(1:min(2, sampleCount)) = false;
    candidateIndices = find(candidateMask);

    previousWord = uint16(int16(round(adcCode(max(1, candidateIndices - 1)))));
    currentWord = uint16(int16(round(adcCode(candidateIndices))));
    bitXorMask = bitxor(previousWord, currentWord);

    for candidateIndex = 1:numel(candidateIndices)
        sampleNumber = candidateIndices(candidateIndex) - 1;
        reason = candidateReason( ...
            deltaCode(candidateIndices(candidateIndex)), ...
            secondDifferenceCode(candidateIndices(candidateIndex)), ...
            jumpThresholdCode, secondDifferenceThresholdCode);
        candidateRows(end + 1, :) = { ... %#ok<AGROW>
            fileIndex, fileInfo(fileIndex).name, sampleNumber, ...
            adcCode(candidateIndices(candidateIndex)), ...
            deltaCode(candidateIndices(candidateIndex)), ...
            secondDifferenceCode(candidateIndices(candidateIndex)), ...
            sprintf('0x%04X', bitXorMask(candidateIndex)), reason};
    end

    plotIndices = 1:overviewPlotStride:sampleCount;
    overviewX{fileIndex} = sampleIndex(plotIndices) + (fileIndex - 1) * sampleCount;
    overviewCode{fileIndex} = adcCode(plotIndices);
    overviewSecondDifference{fileIndex} = secondDifferenceCode(plotIndices);

    if selectedFileIndex == fileIndex
        plotDetailedRecord(fileInfo(fileIndex).name, sampleIndex, adcCode, ...
            deltaCode, secondDifferenceCode, candidateIndices, ...
            jumpThresholdCode, secondDifferenceThresholdCode, sampleRateHz);
    end
end

%% 全部文件概览
plotOverview(fileInfo, overviewX, overviewCode, overviewSecondDifference, ...
    secondDifferenceThresholdCode, sampleRateHz);

%% 保存和打印候选点
if isempty(candidateRows)
    fprintf('\n未发现超过当前阈值的候选突变点。\n');
else
    candidateTable = cell2table(candidateRows, 'VariableNames', ...
        {'FileIndex','FileName','SampleIndex','Code', ...
        'DeltaCode','SecondDifferenceCode','BitXorMask','Reason'});
    fprintf('\n发现 %d 个候选点，请结合图形确认：\n', height(candidateTable));
    disp(candidateTable);
    if saveCandidateTable
        writetable(candidateTable, ...
            fullfile(resultFolder, 'metastability_candidates.csv'));
        fprintf('候选点已保存：%s\n', ...
            fullfile(resultFolder, 'metastability_candidates.csv'));
    end
end

fprintf('\n分析完成。请重点看：\n');
fprintf('1) raw code 是否出现单点大跳变；\n');
fprintf('2) Second difference 是否出现孤立尖峰；\n');
fprintf('3) BitXorMask 是否包含高位（尤其 bit15~bit12）翻转；\n');
fprintf('4) 候选点是否只出现在文件边界。文件边界不属于本脚本的突变判断范围。\n');

%% 局部函数
function adcCode = readAdcCode(filePath, dataColumn, adcBits, codeFormat)
headerRowCount = countHeaderRows(filePath);
try
    numericData = dlmread(filePath, ',', headerRowCount, 0); %#ok<DLMRD>
catch readError
    error('plot_ad2208_metastability:CsvReadFailed', ...
        '读取 CSV 失败：%s\n%s', filePath, readError.message);
end

if dataColumn < 1 || dataColumn > size(numericData, 2)
    error('plot_ad2208_metastability:ColumnOutOfRange', ...
        '数据列 %d 超出文件列数：%s', dataColumn, filePath);
end

adcCode = double(numericData(:, dataColumn));
adcCode = adcCode(isfinite(adcCode));
fullScalePeak = 2^(adcBits - 1);
if strcmpi(codeFormat, 'unsigned')
    adcCode = adcCode - fullScalePeak;
elseif ~strcmpi(codeFormat, 'signed')
    error('plot_ad2208_metastability:InvalidCodeFormat', ...
        'adcCodeFormat 只能是 signed 或 unsigned。');
end
end

function headerRowCount = countHeaderRows(filePath)
fileId = fopen(filePath, 'r');
if fileId < 0
    error('plot_ad2208_metastability:CannotOpenCsv', ...
        '无法打开 CSV：%s', filePath);
end
cleanupObject = onCleanup(@() fclose(fileId));
headerRowCount = 0;
while true
    currentLine = fgetl(fileId);
    if ~ischar(currentLine)
        break;
    end
    fields = strsplit(strtrim(currentLine), ',');
    values = cellfun(@str2double, fields);
    if all(~isnan(values))
        break;
    end
    headerRowCount = headerRowCount + 1;
end
end

function reason = candidateReason(deltaCode, secondDifferenceCode, ...
        jumpThresholdCode, secondDifferenceThresholdCode)
if abs(deltaCode) > jumpThresholdCode && ...
        abs(secondDifferenceCode) > secondDifferenceThresholdCode
    reason = 'DeltaAndSecondDifference';
elseif abs(deltaCode) > jumpThresholdCode
    reason = 'DeltaOnly';
else
    reason = 'SecondDifferenceOnly';
end
end

function plotDetailedRecord(fileName, sampleIndex, adcCode, deltaCode, ...
        secondDifferenceCode, candidateIndices, jumpThresholdCode, ...
        secondDifferenceThresholdCode, sampleRateHz)
figure('Color', 'w', 'Name', ['AD2208 detail: ' fileName], ...
    'NumberTitle', 'off');
tiledlayout(4, 1, 'TileSpacing', 'compact');

nexttile;
plot(sampleIndex, adcCode, 'b-');
hold on;
if ~isempty(candidateIndices)
    plot(sampleIndex(candidateIndices), adcCode(candidateIndices), ...
        'ro', 'MarkerSize', 7, 'LineWidth', 1.2);
end
hold off; grid on;
xlabel('Sample index'); ylabel('ADC code');
title(sprintf('%s, %.6g MSPS, candidates = %d', ...
    fileName, sampleRateHz / 1e6, numel(candidateIndices)), ...
    'Interpreter', 'none');
if ~isempty(candidateIndices), legend('Raw code', 'Candidate', 'Location', 'best'); end

nexttile;
plot(sampleIndex, deltaCode, 'k-');
hold on;
yline(jumpThresholdCode, 'r--');
yline(-jumpThresholdCode, 'r--');
hold off; grid on;
xlabel('Sample index'); ylabel('\Delta code');
title(sprintf('|Delta code| threshold = %d', jumpThresholdCode));

nexttile;
plot(sampleIndex, secondDifferenceCode, 'm-');
hold on;
yline(secondDifferenceThresholdCode, 'r--');
yline(-secondDifferenceThresholdCode, 'r--');
if ~isempty(candidateIndices)
    plot(sampleIndex(candidateIndices), secondDifferenceCode(candidateIndices), ...
        'ro', 'MarkerSize', 7, 'LineWidth', 1.2);
end
hold off; grid on;
xlabel('Sample index'); ylabel('\Delta^2 code');
title(sprintf('|Second difference| threshold = %d', ...
    secondDifferenceThresholdCode));

nexttile;
if numel(adcCode) >= 2
    bitXorMask = bitxor(uint16(int16(round(adcCode(2:end)))), ...
        uint16(int16(round(adcCode(1:end - 1)))));
    plot(sampleIndex(2:end), double(bitXorMask), 'g-');
else
    plot(sampleIndex, zeros(size(sampleIndex)), 'g-');
end
grid on;
xlabel('Sample index'); ylabel('Bit XOR mask (decimal)');
title('Adjacent-sample bit changes; large mask means multiple bits changed');
end

function plotOverview(fileInfo, overviewX, overviewCode, ...
        overviewSecondDifference, secondDifferenceThresholdCode, sampleRateHz)
figure('Color', 'w', 'Name', 'AD2208 all-record overview', ...
    'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact');

nexttile;
hold on;
for fileIndex = 1:numel(fileInfo)
    plot(overviewX{fileIndex}, overviewCode{fileIndex}, ...
        'DisplayName', sprintf('%02d', fileIndex));
end
hold off; grid on;
xlabel('Concatenated display index (file boundaries are not continuous)');
ylabel('ADC code');
title(sprintf('All %d records, %.6g MSPS', numel(fileInfo), sampleRateHz / 1e6));

nexttile;
hold on;
for fileIndex = 1:numel(fileInfo)
    plot(overviewX{fileIndex}, overviewSecondDifference{fileIndex});
end
yline(secondDifferenceThresholdCode, 'r--', 'Threshold');
yline(-secondDifferenceThresholdCode, 'r--');
hold off; grid on;
xlabel('Concatenated display index (do not inspect file boundaries as jumps)');
ylabel('Second difference (code)');
title('All-record second-difference overview');
end

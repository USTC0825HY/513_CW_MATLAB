function batchSummary = run_ad2208_isolation_batch(dataRoot)
%RUN_AD2208_ISOLATION_BATCH Analyze all AD2208 isolation capture groups.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot)
    dataRoot = uigetdir(pwd, '选择 AD2208 隔离度数据目录');
end
if isequal(dataRoot, 0) || ~isfolder(dataRoot)
    error('ad2208:IsolationRootNotFound', '隔离度数据目录不存在。');
end
dataRoot = char(dataRoot);
groupInfo = dir(fullfile(dataRoot, 'JG*shuru-*'));
groupInfo = groupInfo([groupInfo.isdir]);
if isempty(groupInfo)
    error('ad2208:IsolationGroupsNotFound', '未找到 JGxxshuru-{1M|15M} 隔离度数据目录。');
end

records = cell(0, 16);
sourceRecords = cell(0, 6);
for groupIndex = 1:numel(groupInfo)
    groupName = groupInfo(groupIndex).name;
    jgToken = regexp(groupName, '^JG(\d+)shuru-', 'tokens', 'once');
    freqToken = regexp(groupName, '-(\d+(?:\.\d+)?)([KMG])$', 'tokens', 'once');
    if isempty(jgToken) || isempty(freqToken)
        warning('ad2208:IsolationGroupSkipped', '跳过无法解析的目录：%s', groupName);
        continue;
    end
    jgNumber = str2double(jgToken{1});
    expectedFrequencyHz = str2double(freqToken{1}) * scaleFromUnit(freqToken{2});
    drivenChannel = channelFromJg(jgNumber);
    if isempty(drivenChannel)
        warning('ad2208:IsolationGroupSkipped', '跳过未知 JG 通道目录：%s', groupName);
        continue;
    end
    groupFolder = fullfile(dataRoot, groupName);
    files = dir(fullfile(groupFolder, '*.csv'));
    [~, order] = sort({files.name});
    files = files(order);
    if numel(files) ~= 5
        error('ad2208:IsolationInputCount', '%s 应包含 5 个 CSV，实际为 %d。', groupName, numel(files));
    end
    selectedFiles = {files.name};
    config = ad2208Config('isolation');
    config.isolationFrequencyHz = expectedFrequencyHz;
    config.drivenChannel = drivenChannel;
    outputFolder = fullfile(dataRoot, ['Drive_' drivenChannel], 'results');
    resultTable = adc_isolation_analysis(groupFolder, selectedFiles, outputFolder, config);
    runFolder = latestSuccessfulRun(outputFolder);
    inputHashes = strings(numel(files), 1);
    for fileIndex = 1:numel(files)
        filePath = fullfile(groupFolder, files(fileIndex).name);
        info = dir(filePath);
        inputHashes(fileIndex) = string(converter.runtime.sha256File(filePath));
        sourceRecords(end + 1, :) = {groupName, drivenChannel, files(fileIndex).name, ...
            info.bytes, datestr(info.datenum, 31), char(inputHashes(fileIndex))}; %#ok<AGROW>
    end
    inputSha256 = char(strjoin(inputHashes, ';'));
    for rowIndex = 1:height(resultTable)
        records(end + 1, :) = {groupName, drivenChannel, expectedFrequencyHz, ...
            char(resultTable.QuietChannel(rowIndex)), char(resultTable.DrivenChannel(rowIndex)), ...
            resultTable.FrequencyHz(rowIndex), resultTable.FrequencyMismatchFlag(rowIndex), ...
            resultTable.DrivenCodePp(rowIndex), resultTable.QuietCodePp(rowIndex), ...
            resultTable.IsolationDb(rowIndex), char(resultTable.FormalConclusion(rowIndex)), ...
            config.sampleRate, 'ADC digital output code', ...
            'Not required for dimensionless amplitude ratio', inputSha256, runFolder}; %#ok<AGROW>
    end
end

batchSummary = cell2table(records, 'VariableNames', { ...
    'InputFolder', 'DrivenChannel', 'ExpectedFrequencyHz', 'QuietChannel', ...
    'ResultDrivenChannel', 'MeasuredFrequencyHz', 'FrequencyMismatchFlag', ...
    'DrivenCodePp', 'QuietCodePp', 'IsolationDb', 'FormalConclusion', ...
    'sample_rate_hz', 'reference_plane', 'calibration_source', ...
    'input_sha256', 'RunFolder'});
sourceManifest = cell2table(sourceRecords, 'VariableNames', { ...
    'InputFolder', 'DrivenChannel', 'FileName', 'FileSizeBytes', ...
    'ModifiedAt', 'SHA256'});
batchFolder = createBatchFolder(dataRoot);
converter.report.writeTable(batchSummary, fullfile(batchFolder, 'AD2208_isolation_batch_summary.csv'));
converter.report.writeTable(sourceManifest, fullfile(batchFolder, 'AD2208_isolation_input_manifest.csv'));
converter.report.writeTable(sourceManifest, fullfile(batchFolder, 'run_manifest.csv'));
writeBatchParameters(batchFolder);
save(fullfile(batchFolder, 'AD2208_isolation_batch_result.mat'), ...
    'batchSummary', 'sourceManifest');
writeBatchInfo(batchFolder, dataRoot);
writeStatus(batchFolder, batchSummary);
converter.report.writeTable(batchSummary, fullfile(dataRoot, 'AD2208_isolation_batch_summary.csv'));
converter.report.writeTable(sourceManifest, fullfile(dataRoot, 'AD2208_isolation_input_manifest.csv'));
disp(batchSummary);
fprintf('AD2208 隔离度批处理汇总已保存至：%s\n', batchFolder);
end

function value = scaleFromUnit(unit)
switch upper(unit)
    case 'K', value = 1e3;
    case 'M', value = 1e6;
    case 'G', value = 1e9;
    otherwise, error('ad2208:InvalidFrequencyUnit', '未知频率单位：%s', unit);
end
end

function channelName = channelFromJg(jgNumber)
knownAdc = [1 2 3 5 6];
knownJg = [15 17 19 22 24];
index = find(knownJg == jgNumber, 1);
if isempty(index)
    channelName = '';
else
    channelName = sprintf('ADC%d_JG%d', knownAdc(index), jgNumber);
end
end

function runFolder = latestSuccessfulRun(resultBase)
runs = dir(fullfile(resultBase, 'run_*'));
runs = runs([runs.isdir]);
runFolder = '';
if isempty(runs), return; end
[~, order] = sort([runs.datenum], 'descend');
for index = order
    candidate = fullfile(runs(index).folder, runs(index).name);
    if isfile(fullfile(candidate, 'STATUS_SUCCESS.txt'))
        runFolder = candidate;
        return;
    end
end
end

function batchFolder = createBatchFolder(dataRoot)
base = fullfile(dataRoot, 'results');
if ~isfolder(base), mkdir(base); end
stem = ['run_' datestr(now, 'yyyymmdd_HHMMSS') '_isolation_batch']; %#ok<TNOW1>
batchFolder = fullfile(base, stem);
suffix = 1;
while isfolder(batchFolder)
    batchFolder = fullfile(base, sprintf('%s_%02d', stem, suffix));
    suffix = suffix + 1;
end
mkdir(batchFolder);
end

function writeStatus(batchFolder, summary)
fileId = fopen(fullfile(batchFolder, 'STATUS_SUCCESS.txt'), 'w');
if fileId < 0, error('ad2208:StatusWriteFailed', '无法写入批处理状态。'); end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'FinishedAt: %s\n', datestr(now, 31)); %#ok<TNOW1>
fprintf(fileId, 'Succeeded: 1\n');
fprintf(fileId, 'InputPairs: %d\n', height(summary));
fprintf(fileId, 'WorstIsolationDb: %.12g\n', min(summary.IsolationDb));
end

function writeBatchParameters(batchFolder)
parameterNames = {'Device'; 'Analysis'; 'Version'; 'SampleRateHz'; ...
    'AdcBits'; 'AdcCodeFormat'; 'MinimumIsolationDb'; 'FormalOperator'};
parameterValues = {'AD2208'; 'isolation'; '1.3.0'; '100000000'; ...
    '16'; 'signed'; '40'; '>'};
parameterTable = table(parameterNames, parameterValues, ...
    'VariableNames', {'Parameter', 'Value'});
converter.report.writeTable(parameterTable, ...
    fullfile(batchFolder, 'analysis_parameters.csv'));
end

function writeBatchInfo(batchFolder, dataRoot)
fileId = fopen(fullfile(batchFolder, 'run_info.txt'), 'w');
if fileId < 0, error('ad2208:RunInfoWriteFailed', '无法写入批处理运行信息。'); end
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'Device: AD2208\n');
fprintf(fileId, 'Analysis: isolation_batch\n');
fprintf(fileId, 'Version: 1.3.0\n');
fprintf(fileId, 'DataFolder: %s\n', dataRoot);
fprintf(fileId, 'EntryPoint: run_ad2208_isolation_batch.m\n');
end

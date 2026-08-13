function audit = audit_ad2208_results(dataRoot)
%AUDIT_AD2208_RESULTS Verify the latest successful AD2208 result bundles.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot) || ~isfolder(dataRoot)
    error('ad2208:DataRootNotFound', 'AD2208 数据根目录不存在。');
end
dataRoot = char(dataRoot);
batchPath = fullfile(dataRoot, 'AD2208_batch_summary.csv');
if ~isfile(batchPath)
    error('ad2208:BatchSummaryNotFound', '未找到 AD2208 批处理汇总。');
end
batchCells = readcell(batchPath, 'Delimiter', ',', 'Encoding', 'UTF-8');
batchCells = batchCells(2:end, :);

metric = strings(0, 1);
channel = strings(0, 1);
runFolder = strings(0, 1);
expectedInputCount = zeros(0, 1);
manifestInputCount = zeros(0, 1);
manifestMatch = false(0, 1);
requiredFilesPresent = false(0, 1);
auditStatus = strings(0, 1);
message = strings(0, 1);

for rowIndex = 1:size(batchCells, 1)
    currentStatus = char(string(batchCells{rowIndex, 3}));
    if ~strcmp(currentStatus, '成功')
        continue;
    end
    currentMetric = char(string(batchCells{rowIndex, 1}));
    currentChannel = char(string(batchCells{rowIndex, 2}));
    currentMessage = char(string(batchCells{rowIndex, 4}));
    expectedCount = sscanf(currentMessage, '%d', 1);
    resultBase = fullfile(dataRoot, currentMetric, currentChannel, 'results');
    latestRun = latestSuccessfulRun(resultBase);

    metric(end + 1, 1) = string(currentMetric); %#ok<AGROW>
    channel(end + 1, 1) = string(currentChannel); %#ok<AGROW>
    expectedInputCount(end + 1, 1) = expectedCount; %#ok<AGROW>
    if isempty(latestRun)
        runFolder(end + 1, 1) = ""; %#ok<AGROW>
        manifestInputCount(end + 1, 1) = 0; %#ok<AGROW>
        manifestMatch(end + 1, 1) = false; %#ok<AGROW>
        requiredFilesPresent(end + 1, 1) = false; %#ok<AGROW>
        auditStatus(end + 1, 1) = "失败"; %#ok<AGROW>
        message(end + 1, 1) = "未找到成功运行目录"; %#ok<AGROW>
        continue;
    end

    runFolder(end + 1, 1) = string(latestRun); %#ok<AGROW>
    [inputCount, manifestOk] = verifyManifest(latestRun);
    manifestInputCount(end + 1, 1) = inputCount; %#ok<AGROW>
    manifestMatch(end + 1, 1) = manifestOk; %#ok<AGROW>
    filesPresent = hasRequiredFiles(latestRun);
    requiredFilesPresent(end + 1, 1) = filesPresent; %#ok<AGROW>
    passed = filesPresent && manifestOk && inputCount == expectedCount;
    if passed
        auditStatus(end + 1, 1) = "通过"; %#ok<AGROW>
        message(end + 1, 1) = "成功标记、参数、摘要、MAT、图和输入清单均通过"; %#ok<AGROW>
    else
        auditStatus(end + 1, 1) = "失败"; %#ok<AGROW>
        message(end + 1, 1) = "结果文件、输入数量或输入清单校验不一致"; %#ok<AGROW>
    end
end

audit = table(metric, channel, runFolder, expectedInputCount, ...
    manifestInputCount, manifestMatch, requiredFilesPresent, auditStatus, ...
    message, 'VariableNames', {'Metric', 'Channel', 'RunFolder', ...
    'ExpectedInputCount', 'ManifestInputCount', 'ManifestMatch', ...
    'RequiredFilesPresent', 'AuditStatus', 'Message'});
writetable(audit, fullfile(dataRoot, 'AD2208_result_audit.csv'));
end

function value = tableText(column, rowIndex)
if iscell(column)
    value = char(column{rowIndex});
else
    value = char(string(column(rowIndex)));
end
end

function runFolder = latestSuccessfulRun(resultBase)
runFolder = '';
if ~isfolder(resultBase)
    return;
end
runs = dir(fullfile(resultBase, 'run_*'));
runs = runs([runs.isdir]);
[~, order] = sort([runs.datenum], 'descend');
for runIndex = order
    candidate = fullfile(runs(runIndex).folder, runs(runIndex).name);
    if isfile(fullfile(candidate, 'STATUS_SUCCESS.txt'))
        runFolder = candidate;
        return;
    end
end
end

function present = hasRequiredFiles(runFolder)
present = isfile(fullfile(runFolder, 'STATUS_SUCCESS.txt')) && ...
    isfile(fullfile(runFolder, 'analysis_parameters.csv')) && ...
    isfile(fullfile(runFolder, 'run_manifest.csv')) && ...
    ~isempty(dir(fullfile(runFolder, '*summary.csv'))) && ...
    ~isempty(dir(fullfile(runFolder, '*result.mat'))) && ...
    ~isempty(dir(fullfile(runFolder, '*.png'))) && ...
    ~isempty(dir(fullfile(runFolder, '*.fig')));
end

function [inputCount, hashesMatch] = verifyManifest(runFolder)
manifestPath = fullfile(runFolder, 'run_manifest.csv');
runInfoPath = fullfile(runFolder, 'run_info.txt');
if ~isfile(manifestPath) || ~isfile(runInfoPath)
    inputCount = 0;
    hashesMatch = false;
    return;
end
manifest = readtable(manifestPath);
inputCount = height(manifest);
runInfo = fileread(runInfoPath);
token = regexp(runInfo, '(?m)^DataFolder:\s*(.+?)\r?$', 'tokens', 'once');
if isempty(token)
    hashesMatch = false;
    return;
end
dataFolder = token{1};
hashesMatch = true;
for fileIndex = 1:inputCount
    fileName = tableText(manifest.FileName, fileIndex);
    filePath = fullfile(dataFolder, fileName);
    if ~isfile(filePath)
        hashesMatch = false;
        return;
    end
    if ismember('FileSizeBytes', manifest.Properties.VariableNames)
        info = dir(filePath);
        expectedBytes = manifest.FileSizeBytes(fileIndex);
        if info.bytes ~= expectedBytes
            hashesMatch = false;
            return;
        end
    end
end
end

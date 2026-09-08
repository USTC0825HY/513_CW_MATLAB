function audit = auditRun(runFolder, expectedInputCount)
%AUDITRUN Audit one result directory without project-specific helpers.
%   The audit is deliberately conservative: a missing status marker,
%   summary, result MAT, figure, or source manifest is not considered a
%   successful result.

if nargin < 2 || isempty(expectedInputCount)
    expectedInputCount = NaN;
end
runFolder = char(runFolder);
audit = struct('run_folder', string(runFolder), 'status_file_present', false, ...
    'required_files_present', false, 'manifest_input_count', 0, ...
    'expected_input_count', expectedInputCount, 'manifest_hashes_match', false, ...
    'passed', false, 'status', "失败", 'message', "");
if ~isfolder(runFolder)
    audit.message = "结果目录不存在";
    return;
end

audit.status_file_present = isfile(fullfile(runFolder, 'STATUS_SUCCESS.txt'));
audit.required_files_present = audit.status_file_present && ...
    ~isempty(dir(fullfile(runFolder, '*analysis_parameters.csv'))) && ...
    isfile(fullfile(runFolder, 'run_manifest.csv')) && ...
    isfile(fullfile(runFolder, 'run_info.txt')) && ...
    ~isempty(dir(fullfile(runFolder, '*summary.csv'))) && ...
    ~isempty(dir(fullfile(runFolder, '*result.mat'))) && ...
    ~isempty(dir(fullfile(runFolder, '*.png'))) && ...
    ~isempty(dir(fullfile(runFolder, '*.fig')));

[audit.manifest_input_count, audit.manifest_hashes_match] = ...
    verifyManifest(runFolder);
countMatches = isnan(expectedInputCount) || ...
    audit.manifest_input_count == expectedInputCount;
audit.passed = audit.status_file_present && audit.required_files_present && ...
    audit.manifest_hashes_match && countMatches;
if audit.passed
    audit.status = "通过";
    audit.message = "成功标记、结果文件和源文件清单均通过";
elseif ~audit.status_file_present
    audit.status = "未完成";
    audit.message = "未找到 STATUS_SUCCESS.txt";
else
    audit.message = "结果文件、输入数量或源文件 SHA-256 校验不一致";
end
end

function [inputCount, hashesMatch] = verifyManifest(runFolder)
inputCount = 0;
hashesMatch = false;
manifestPath = fullfile(runFolder, 'run_manifest.csv');
runInfoPath = fullfile(runFolder, 'run_info.txt');
if ~isfile(manifestPath) || ~isfile(runInfoPath)
    return;
end
try
    manifest = readtable(manifestPath);
catch
    return;
end
inputCount = height(manifest);
runInfo = fileread(runInfoPath);
token = regexp(runInfo, '(?m)^DataFolder:\s*(.+?)\r?$', 'tokens', 'once');
if isempty(token)
    return;
end
dataFolder = strtrim(token{1});
hashesMatch = true;
for fileIndex = 1:inputCount
    fileName = tableText(manifest.FileName, fileIndex);
    if isfile(fileName), filePath = fileName;
    else, filePath = fullfile(dataFolder, fileName); end
    if ~isfile(filePath)
        hashesMatch = false;
        return;
    end
    if ismember('FileSizeBytes', manifest.Properties.VariableNames)
        info = dir(filePath);
        if info.bytes ~= manifest.FileSizeBytes(fileIndex)
            hashesMatch = false;
            return;
        end
    end
    if ismember('SHA256', manifest.Properties.VariableNames) && ...
            ~strcmpi(tableText(manifest.SHA256, fileIndex), ...
            converter.runtime.sha256File(filePath))
        hashesMatch = false;
        return;
    end
end
end

function value = tableText(column, rowIndex)
if iscell(column)
    value = char(column{rowIndex});
else
    value = char(string(column(rowIndex)));
end
end

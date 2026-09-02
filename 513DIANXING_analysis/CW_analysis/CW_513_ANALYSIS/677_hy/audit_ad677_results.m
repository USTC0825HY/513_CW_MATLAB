function auditTable = audit_ad677_results(dataRoot)
%AUDIT_AD677_RESULTS Audit the latest four AD677 result bundles.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot) || ~isfolder(dataRoot)
    error('ad677:DataRootNotFound', 'AD677 数据根目录不存在。');
end
specs = {
    '02_FrequencyResponse', '677_1', 16;
    '02_FrequencyResponse', '677_2', 16;
    '03_InputPowerScale', '677_1', 10;
    '03_InputPowerScale', '677_2', 10};
metric = strings(size(specs, 1), 1);
channel = strings(size(specs, 1), 1);
runFolder = strings(size(specs, 1), 1);
status = strings(size(specs, 1), 1);
message = strings(size(specs, 1), 1);
passed = false(size(specs, 1), 1);
for specIndex = 1:size(specs, 1)
    metric(specIndex) = specs{specIndex, 1};
    channel(specIndex) = specs{specIndex, 2};
    resultFolder = fullfile(dataRoot, specs{specIndex, 1}, ...
        specs{specIndex, 2}, 'result');
    runFolder(specIndex) = string(latestSuccessfulRun(resultFolder));
    audit = converter.runtime.auditRun(runFolder(specIndex), ...
        specs{specIndex, 3});
    status(specIndex) = audit.status;
    message(specIndex) = audit.message;
    passed(specIndex) = audit.passed;
    if strlength(runFolder(specIndex)) > 0
        perRunAudit = struct2table(audit, 'AsArray', true);
        converter.report.writeTable(perRunAudit, ...
            fullfile(runFolder(specIndex), 'bundle_audit.csv'));
    end
end
auditTable = table(metric, channel, runFolder, passed, status, message, ...
    'VariableNames', {'Metric', 'Channel', 'RunFolder', 'Passed', ...
    'AuditStatus', 'Message'});
disp(auditTable);
end

function runFolder = latestSuccessfulRun(resultFolder)
runFolder = '';
if ~isfolder(resultFolder), return; end
runInfo = dir(fullfile(resultFolder, 'run_*'));
runInfo = runInfo([runInfo.isdir]);
[~, order] = sort([runInfo.datenum], 'descend');
for runIndex = order
    candidate = fullfile(runInfo(runIndex).folder, runInfo(runIndex).name);
    if isfile(fullfile(candidate, 'STATUS_SUCCESS.txt'))
        runFolder = candidate;
        return;
    end
end
end

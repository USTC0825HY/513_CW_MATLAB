function audit = audit_da9726_results(resultRoot)
%AUDIT_DA9726_RESULTS Audit the latest DA9726 result directory.
bootstrapRuntime();
if nargin < 1 || isempty(resultRoot)
    error('cw513:ResultRootRequired', '必须提供DA9726结果目录或其父目录。');
end
resultRoot = char(resultRoot);
runFolder = localLatestRun(resultRoot);
row = converter.runtime.auditRun(runFolder);
row.device = "DA9726";
audit = struct2table(row);
converter.report.writeTable(audit, fullfile(resultRoot, 'DA9726_result_audit.csv'));
end

function runFolder = localLatestRun(rootFolder)
if isfile(fullfile(rootFolder, 'STATUS_SUCCESS.txt'))
    runFolder = rootFolder;
    return;
end
candidateRoots = {rootFolder, fullfile(rootFolder, 'results')};
runFolder = '';
for rootIndex = 1:numel(candidateRoots)
    runs = dir(fullfile(candidateRoots{rootIndex}, 'run_*'));
    runs = runs([runs.isdir]);
    if isempty(runs), continue; end
    [~, order] = sort([runs.datenum], 'descend');
    for runIndex = order
        candidate = fullfile(runs(runIndex).folder, runs(runIndex).name);
        if isfile(fullfile(candidate, 'STATUS_SUCCESS.txt'))
            runFolder = candidate;
            return;
        end
    end
end
end

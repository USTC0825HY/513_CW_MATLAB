function output = write_evidence_bundle( ...
    cfg, summaryTable, detailTable, curveTable, sourceTable)
%WRITE_EVIDENCE_BUNDLE Write the common s26-s35 evidence files.
%   OUTPUT contains the resolved run directory and generated file paths.
%   Tables may be empty but are still exported with their declared schema.

arguments
    cfg (1, 1) struct
    summaryTable table
    detailTable table
    curveTable table
    sourceTable table
end

if ~isfield(cfg, 'outputDir') || strlength(string(cfg.outputDir)) == 0
    error('laser_analysis:OutputDir', 'cfg.outputDir is required.');
end
runId = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
if isfield(cfg, 'timestampedOutput') && cfg.timestampedOutput
    runDir = fullfile(cfg.outputDir, char(string(cfg.testId) + "_" + runId));
else
    runDir = char(cfg.outputDir);
end
if ~exist(runDir, 'dir'), mkdir(runDir); end

parameterTable = localFlattenConfig(cfg);
parametersPath = fullfile(runDir, 'parameters.csv');
summaryPath = fullfile(runDir, 'summary.csv');
detailPath = fullfile(runDir, 'details.csv');
curvePath = fullfile(runDir, 'full_curve.csv');
sourcePath = fullfile(runDir, 'source_manifest.csv');
resultPath = fullfile(runDir, 'result.mat');
conflictPath = fullfile(runDir, 'requirement_conflicts.csv');

writetable(parameterTable, parametersPath, 'Encoding', 'UTF-8');
writetable(summaryTable, summaryPath, 'Encoding', 'UTF-8');
writetable(detailTable, detailPath, 'Encoding', 'UTF-8');
writetable(curveTable, curvePath, 'Encoding', 'UTF-8');
writetable(sourceTable, sourcePath, 'Encoding', 'UTF-8');

requirementConflicts = table();
if isfield(cfg, 'requirements') && istable(cfg.requirements)
    requirementConflicts = cfg.requirements(cfg.requirements.state ~= "approved", :);
end
writetable(requirementConflicts, conflictPath, 'Encoding', 'UTF-8');

output = struct;
output.runDir = string(runDir);
output.parameters = string(parametersPath);
output.summary = string(summaryPath);
output.details = string(detailPath);
output.fullCurve = string(curvePath);
output.sourceManifest = string(sourcePath);
output.requirementConflicts = string(conflictPath);
output.resultMat = string(resultPath);
save(resultPath, 'cfg', 'summaryTable', 'detailTable', 'curveTable', ...
    'sourceTable', 'requirementConflicts', 'output');
end

function out = localFlattenConfig(cfg)
%LOCALFLATTENCONFIG Convert scalar configuration fields to parameter rows.
names = string(fieldnames(cfg));
parameter = strings(0, 1);
value = strings(0, 1);
for k = 1:numel(names)
    fieldName = char(names(k));
    raw = cfg.(fieldName);
    if istable(raw) || isstruct(raw) || iscell(raw)
        continue;
    end
    if ischar(raw) || isstring(raw)
        textValue = strjoin(string(raw(:)), ';');
    elseif isnumeric(raw) || islogical(raw)
        textValue = strjoin(compose('%.12g', double(raw(:))), ';');
    else
        continue;
    end
    parameter(end + 1, 1) = names(k); %#ok<AGROW>
    value(end + 1, 1) = textValue; %#ok<AGROW>
end
out = table(parameter, value);
end

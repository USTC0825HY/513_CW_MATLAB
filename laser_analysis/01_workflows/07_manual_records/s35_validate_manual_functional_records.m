function result = s35_validate_manual_functional_records(cfg)
%S35_VALIDATE_MANUAL_FUNCTIONAL_RECORDS Validate structured manual records.
%   RESULT = s35_validate_manual_functional_records(CFG) checks impedance,
%   power, clock, reset, DDR, RS422, LVDS, and other manually acquired
%   records from one manifest. Numeric rows use operator with limit_value
%   or lower_limit/upper_limit. Non-numeric rows must already use one of
%   满足, 不满足, 暂不能判定, or 未测试.
%
%   This entry does not control instruments or Vivado. It hashes the record
%   manifest itself and preserves notes, requirement ids, and source
%   conflicts in the evidence bundle.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "metric"]);
rows = cell(height(manifest), 12);
for k = 1:height(manifest)
    row = manifest(k, :);
    measured = row.measured_value;
    if ~isfinite(measured), measured = row.value; end
    [status, reason] = localEvaluate(row, measured);
    requirement = laser_analysis.resolve_requirement( ...
        cfg, row.requirement_id, row.metric, "");
    if height(requirement) == 1
        status = laser_analysis.evaluate_requirement( ...
            measured, requirement, cfg.formalEnabled);
        if requirement.state ~= "approved"
            status = "暂不能判定";
        end
    end
    rows(k, :) = {row.case_id, row.channel, row.metric, measured, ...
        row.operator, row.limit_value, row.lower_limit, row.upper_limit, ...
        row.unit, row.requirement_id, status, reason};
end

details = cell2table(rows, 'VariableNames', { ...
    'case_id', 'channel', 'metric', 'measured_value', 'operator', ...
    'limit_value', 'lower_limit', 'upper_limit', 'unit', ...
    'requirement_id', 'status', 'reason'});
summary = groupsummary(details, 'status');
summary.Properties.VariableNames{2} = 'record_count';
curves = table();
manifestHash = laser_analysis.sha256_file(cfg.manifestFile);
sources = table(string(cfg.manifestFile), manifestHash, height(manifest), ...
    'VariableNames', {'source_file', 'sha256', 'record_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(summary);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "manual_functional_records", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [status, reason] = localEvaluate(row, measured)
%LOCALEVALUATE Apply explicit row limits without inferring a requirement.
status = string(row.status);
reason = "";
allowed = ["满足", "不满足", "暂不能判定", "未测试"];
if ismember(status, allowed)
    return;
end
status = "暂不能判定";
if ~isfinite(measured)
    reason = "无数值结果且未给出标准状态";
    return;
end
operator = strtrim(row.operator);
switch operator
    case "<"
        if ~isfinite(row.limit_value), reason = "限值缺失"; return; end
        pass = measured < row.limit_value;
    case "<="
        if ~isfinite(row.limit_value), reason = "限值缺失"; return; end
        pass = measured <= row.limit_value;
    case ">"
        if ~isfinite(row.limit_value), reason = "限值缺失"; return; end
        pass = measured > row.limit_value;
    case ">="
        if ~isfinite(row.limit_value), reason = "限值缺失"; return; end
        pass = measured >= row.limit_value;
    case "between"
        if ~isfinite(row.lower_limit) || ~isfinite(row.upper_limit)
            reason = "限值缺失";
            return;
        end
        pass = measured >= row.lower_limit && measured <= row.upper_limit;
    otherwise
        reason = "operator 或限值缺失";
        return;
end
if pass
    status = "满足";
else
    status = "不满足";
end
end

function figureHandle = localPlot(summary)
%LOCALPLOT Plot record counts by formal status.
figureHandle = figure('Visible', 'off', 'Color', 'w');
bar(categorical(summary.status), summary.record_count);
ylabel('Record count');
title('Manual functional record validation');
grid on;
end

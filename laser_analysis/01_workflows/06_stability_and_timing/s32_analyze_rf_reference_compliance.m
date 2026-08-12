function result = s32_analyze_rf_reference_compliance(cfg)
%S32_ANALYZE_RF_REFERENCE_COMPLIANCE Summarize CW RF reference evidence.
%   RESULT = s32_analyze_rf_reference_compliance(CFG) combines frequency,
%   power, harmonic suppression, and ADEV/MDEV evidence. Frequency-log rows
%   require source_file, data_column, tau0_s, and center_frequency_hz.
%   Scalar power and harmonic rows use measured_value.
%
%   requirement_id must identify the correct 100 MHz or GTH requirement
%   when several channel classes share one metric. A 10000 s result is
%   暂不能判定 when the record is too short; no long-tau extrapolation is
%   performed.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "data_role"]);
detailRows = cell(0, 10);
curveRows = cell(0, 6);
sourceRows = cell(0, 7);

for k = 1:height(manifest)
    row = manifest(k, :);
    role = lower(strtrim(row.data_role));
    if role == "frequency_log"
        [frequencyData, hash] = localReadFrequency(row);
        sourceRows(end + 1, :) = {row.case_id, row.channel, ...
            row.source_file, hash, row.reference_plane, ...
            row.calibration_source, numel(frequencyData)}; %#ok<AGROW>
        if isfinite(row.tau0_s) && isfinite(row.center_frequency_hz)
            allan = laser_analysis.overlapping_allan(frequencyData, ...
                row.tau0_s, row.center_frequency_hz, cfg.allanTargetTauS(:));
        else
            allan = localEmptyAllan(cfg.allanTargetTauS(:));
        end
        for j = 1:height(allan)
            metric = "adev_" + localTauName(allan.tau_s(j));
            requirement = laser_analysis.resolve_requirement( ...
                cfg, row.requirement_id, metric, "rf");
            status = laser_analysis.evaluate_requirement( ...
                allan.adev(j), requirement, cfg.formalEnabled);
            if strlength(strtrim(row.reference_plane)) == 0 || ...
                    ~isfinite(row.tau0_s) || ...
                    ~isfinite(row.center_frequency_hz)
                status = "暂不能判定";
            end
            detailRows(end + 1, :) = {row.case_id, row.channel, metric, ...
                allan.tau_s(j), allan.adev(j), allan.mdev(j), NaN, ...
                localRequirementId(requirement), status, ...
                allan.calculation_status(j)}; %#ok<AGROW>
            curveRows(end + 1, :) = {row.case_id, row.channel, ...
                "ADEV", allan.tau_s(j), allan.adev(j), "1"}; %#ok<AGROW>
            curveRows(end + 1, :) = {row.case_id, row.channel, ...
                "MDEV", allan.tau_s(j), allan.mdev(j), "1"}; %#ok<AGROW>
        end
    else
        metric = localScalarMetric(row);
        requirement = laser_analysis.resolve_requirement( ...
            cfg, row.requirement_id, metric, "rf");
        status = laser_analysis.evaluate_requirement( ...
            row.measured_value, requirement, cfg.formalEnabled);
        if strlength(strtrim(row.reference_plane)) == 0
            status = "暂不能判定";
        end
        detailRows(end + 1, :) = {row.case_id, row.channel, metric, ...
            NaN, NaN, NaN, row.measured_value, ...
            localRequirementId(requirement), status, ""}; %#ok<AGROW>
    end
end

details = cell2table(detailRows, 'VariableNames', { ...
    'case_id', 'channel', 'metric', 'tau_s', 'adev', 'mdev', ...
    'measured_value', 'requirement_id', 'status', 'reason'});
summary = localSummary(details);
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(curves);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "rf_reference_compliance", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [frequencyData, hash] = localReadFrequency(row)
%LOCALREADFREQUENCY Read one explicit frequency-counter column.
if strlength(strtrim(row.source_file)) == 0 || ~isfile(row.source_file)
    frequencyData = [];
    hash = "";
    return;
end
matrix = readmatrix(row.source_file);
if ~isfinite(row.data_column) || row.data_column > size(matrix, 2)
    frequencyData = [];
else
    frequencyData = matrix(:, round(row.data_column));
    frequencyData = frequencyData(isfinite(frequencyData));
end
hash = laser_analysis.sha256_file(row.source_file);
end

function allan = localEmptyAllan(tau)
%LOCALEMPTYALLAN Return unavailable target-tau rows.
allan = table(tau, round(tau), nan(size(tau)), nan(size(tau)), ...
    zeros(size(tau)), repmat("暂不能判定", size(tau)), ...
    'VariableNames', {'tau_s', 'm', 'adev', 'mdev', ...
    'sample_pairs', 'calculation_status'});
end

function metric = localScalarMetric(row)
%LOCALSCALARMETRIC Resolve power or harmonic scalar data roles.
if strlength(strtrim(row.metric)) > 0
    metric = lower(strtrim(row.metric));
elseif contains(lower(row.data_role), "harmonic")
    metric = "harmonic_suppression";
elseif contains(lower(row.data_role), "power")
    metric = "power";
else
    metric = lower(strtrim(row.data_role));
end
end

function name = localTauName(tau)
%LOCALTAUNAME Convert supported tau values to requirement suffixes.
if abs(tau - 1) < eps
    name = "1s";
elseif abs(tau - 10000) < eps(10000)
    name = "10000s";
else
    name = lower(string(tau)) + "s";
end
end

function id = localRequirementId(requirement)
%LOCALREQUIREMENTID Return one selected requirement id.
if height(requirement) == 1, id = requirement.requirement_id; else, id = ""; end
end

function summary = localSummary(details)
%LOCALSUMMARY Combine all metrics for each channel.
channels = unique(details.channel, 'stable');
rows = cell(numel(channels), 4);
for k = 1:numel(channels)
    part = details(details.channel == channels(k), :);
    if any(part.status == "暂不能判定")
        status = "暂不能判定";
    elseif any(part.status == "不满足")
        status = "不满足";
    elseif all(part.status == "满足")
        status = "满足";
    else
        status = "未测试";
    end
    rows(k, :) = {channels(k), status, height(part), ...
        nnz(part.status == "暂不能判定")};
end
summary = cell2table(rows, 'VariableNames', { ...
    'channel', 'status', 'metric_count', 'undetermined_count'});
end

function figureHandle = localPlot(curves)
%LOCALPLOT Plot ADEV and MDEV evidence when available.
figureHandle = figure('Visible', 'off', 'Color', 'w');
if isempty(curves)
    text(0.5, 0.5, 'No stability curve data', ...
        'HorizontalAlignment', 'center');
    axis off;
    return;
end
groups = unique(curves(:, {'channel', 'curve_type'}), 'rows', 'stable');
hold on;
for k = 1:height(groups)
    mask = curves.channel == groups.channel(k) & ...
        curves.curve_type == groups.curve_type(k);
    loglog(curves.x_value(mask), curves.y_value(mask), 'o-', ...
        'DisplayName', groups.channel(k) + " " + groups.curve_type(k));
end
xlabel('Tau (s)');
ylabel('Fractional stability');
grid on;
legend('Location', 'best');
end

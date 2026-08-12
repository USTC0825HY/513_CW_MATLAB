function result = s30_analyze_dac_dc_transfer(cfg)
%S30_ANALYZE_DAC_DC_TRANSFER Analyze static DAC and switch DC sweeps.
%   RESULT = s30_analyze_dac_dc_transfer(CFG) computes output range,
%   code-step statistics, endpoint and best-fit INL, monotonicity,
%   saturation evidence, and load current. This is the required static
%   method for DAC INL; a full-scale sine capture is not substituted.
%
%   Each manifest row supplies code_value and either measured_value or a
%   source capture whose steady mean is used. reference_plane is required.
%   load_ohm is required before load-current compliance can be claimed.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "code_value"]);
pointRows = cell(height(manifest), 8);
sourceRows = cell(0, 7);
for k = 1:height(manifest)
    measured = manifest.measured_value(k);
    source = "";
    hash = "";
    if ~isfinite(measured) && strlength(strtrim(manifest.source_file(k))) > 0
        capture = laser_analysis.load_test_capture(manifest(k, :));
        measured = mean(capture.value);
        source = capture.source_file;
        hash = capture.sha256;
        sourceRows(end + 1, :) = {manifest.case_id(k), ...
            manifest.channel(k), source, hash, capture.reference_plane, ...
            manifest.calibration_source(k), capture.sample_count}; %#ok<AGROW>
    end
    pointRows(k, :) = {manifest.case_id(k), manifest.channel(k), ...
        manifest.code_value(k), measured, manifest.load_ohm(k), ...
        manifest.reference_plane(k), source, hash};
end
points = cell2table(pointRows, 'VariableNames', { ...
    'case_id', 'channel', 'code', 'voltage_v', 'load_ohm', ...
    'reference_plane', 'source_file', 'sha256'});

channels = unique(points.channel, 'stable');
summaryRows = cell(numel(channels), 13);
detailRows = cell(0, 9);
curveRows = cell(0, 6);
for k = 1:numel(channels)
    part = points(points.channel == channels(k), :);
    valid = isfinite(part.code) & isfinite(part.voltage_v);
    part = sortrows(part(valid, :), 'code');
    [endpointFit, bestFit, endpointResidual, bestResidual] = ...
        localTransferFits(part.code, part.voltage_v);
    step = diff(part.voltage_v);
    monotonic = all(step >= 0) || all(step <= 0);
    outputRange = range(part.voltage_v);
    load = unique(part.load_ohm(isfinite(part.load_ohm)));
    if isscalar(load) && load > 0
        maximumLoadCurrentMa = max(abs(part.voltage_v)) / load * 1e3;
    else
        maximumLoadCurrentMa = NaN;
    end
    maximumEndpointInlMv = localMaxAbs(endpointResidual) * 1e3;
    maximumBestInlMv = localMaxAbs(bestResidual) * 1e3;
    requirement = laser_analysis.find_requirement(cfg, "inl", "dac");
    status = laser_analysis.evaluate_requirement( ...
        maximumEndpointInlMv, requirement, cfg.formalEnabled);
    reason = "";
    if height(part) < 3 || any(strlength(strtrim(part.reference_plane)) == 0)
        status = "暂不能判定";
        reason = "DC 码点不足或参考面缺失";
    elseif ~isfinite(maximumLoadCurrentMa)
        status = "暂不能判定";
        reason = "负载阻抗缺失或不一致";
    end
    saturationCount = nnz(abs(step) <= eps(max(abs(part.voltage_v))));
    firstFit = NaN;
    if ~isempty(endpointFit), firstFit = endpointFit(1); end
    summaryRows(k, :) = {channels(k), localFiniteMin(part.voltage_v), ...
        localFiniteMax(part.voltage_v), outputRange, mean(abs(step)), ...
        maximumEndpointInlMv, maximumBestInlMv, monotonic, ...
        saturationCount, maximumLoadCurrentMa, firstFit, status, reason};
    for j = 1:height(part)
        detailRows(end + 1, :) = {channels(k), part.case_id(j), ...
            part.code(j), part.voltage_v(j), endpointResidual(j) * 1e3, ...
            bestResidual(j) * 1e3, endpointFit(j), bestFit(j), ...
            part.load_ohm(j)}; %#ok<AGROW>
        curveRows(end + 1, :) = {part.case_id(j), channels(k), ...
            "dc_transfer", part.code(j), part.voltage_v(j), "V"}; %#ok<AGROW>
    end
end

summary = cell2table(summaryRows, 'VariableNames', { ...
    'channel', 'minimum_output_v', 'maximum_output_v', 'output_range_v', ...
    'mean_abs_step_v', 'maximum_abs_inl_endpoint_mv', ...
    'maximum_abs_inl_best_fit_mv', 'monotonic', 'saturation_step_count', ...
    'maximum_load_current_ma', 'endpoint_fit_first_v', 'status', 'reason'});
details = cell2table(detailRows, 'VariableNames', { ...
    'channel', 'case_id', 'code', 'voltage_v', 'endpoint_residual_mv', ...
    'best_fit_residual_mv', 'endpoint_fit_v', 'best_fit_v', 'load_ohm'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(details);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "dac_dc_transfer", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [endpointFit, bestFit, endpointResidual, bestResidual] = ...
        localTransferFits(code, voltage)
%LOCALTRANSFERFITS Return endpoint and least-squares transfer fits.
if numel(code) < 2
    endpointFit = nan(size(code));
    bestFit = endpointFit;
    endpointResidual = endpointFit;
    bestResidual = endpointFit;
    return;
end
endpointFit = interp1(code([1, end]), voltage([1, end]), code);
coefficient = polyfit(code, voltage, 1);
bestFit = polyval(coefficient, code);
endpointResidual = voltage - endpointFit;
bestResidual = voltage - bestFit;
end

function value = localMaxAbs(input)
%LOCALMAXABS Return maximum absolute finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(abs(input)); end
end

function value = localFiniteMin(input)
%LOCALFINITEMIN Return minimum finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = min(input); end
end

function value = localFiniteMax(input)
%LOCALFINITEMAX Return maximum finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(input); end
end

function figureHandle = localPlot(details)
%LOCALPLOT Plot DC transfer and endpoint residual.
figureHandle = figure('Visible', 'off', 'Color', 'w');
tiledlayout(2, 1);
channels = unique(details.channel, 'stable');
nexttile;
hold on;
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.code(mask), details.voltage_v(mask), ...
        'o-', 'DisplayName', channels(k));
end
ylabel('Output (V)');
grid on;
legend('Location', 'best');
nexttile;
hold on;
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.code(mask), details.endpoint_residual_mv(mask), ...
        'o-', 'DisplayName', channels(k));
end
xlabel('DAC code');
ylabel('Endpoint residual (mV)');
grid on;
end

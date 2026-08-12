function result = s29_analyze_temperature_drift(cfg)
%S29_ANALYZE_TEMPERATURE_DRIFT Fit channel drift against temperature.
%   RESULT = s29_analyze_temperature_drift(CFG) reduces each capture to a
%   steady-state mean, fits voltage versus measured temperature for each
%   channel and cycle, and reports slope, 95% confidence interval,
%   heating/cooling hysteresis, and cycle repeatability.
%
%   temperature_c and cycle are explicit manifest fields. Voltage-domain
%   data and a reference_plane are required for formal uV/degC judgment.
%   Folder or set-point names are never used as measured temperature.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "source_file", "temperature_c", "cycle"]);
pointRows = cell(height(manifest), 10);
sourceRows = cell(height(manifest), 7);
for k = 1:height(manifest)
    capture = laser_analysis.load_test_capture(manifest(k, :));
    pointRows(k, :) = {manifest.case_id(k), manifest.channel(k), ...
        manifest.temperature_c(k), manifest.cycle(k), ...
        string(manifest.direction(k)), mean(capture.value), ...
        std(capture.value), capture.unit, capture.reference_plane, ...
        capture.sample_count};
    sourceRows(k, :) = {manifest.case_id(k), manifest.channel(k), ...
        capture.source_file, capture.sha256, capture.reference_plane, ...
        manifest.calibration_source(k), capture.sample_count};
end
points = cell2table(pointRows, 'VariableNames', { ...
    'case_id', 'channel', 'temperature_c', 'cycle', 'direction', ...
    'steady_mean', 'steady_std', 'unit', 'reference_plane', 'sample_count'});

groups = unique(points(:, {'channel', 'cycle'}), 'rows', 'stable');
fitRows = cell(height(groups), 11);
curveRows = cell(0, 6);
for k = 1:height(groups)
    mask = points.channel == groups.channel(k) & ...
        points.cycle == groups.cycle(k);
    part = points(mask, :);
    valid = isfinite(part.temperature_c) & isfinite(part.steady_mean);
    [slope, intercept, ciLow, ciHigh, rSquared] = ...
        localRegression(part.temperature_c(valid), part.steady_mean(valid));
    if all(part.unit(valid) == "V")
        slopeUv = slope * 1e6;
        ciLowUv = ciLow * 1e6;
        ciHighUv = ciHigh * 1e6;
    else
        slopeUv = NaN;
        ciLowUv = NaN;
        ciHighUv = NaN;
    end
    hysteresisUv = localHysteresis(part) * 1e6;
    requirement = laser_analysis.find_requirement( ...
        cfg, "temperature_drift", "adc");
    status = laser_analysis.evaluate_requirement( ...
        abs(slopeUv), requirement, cfg.formalEnabled);
    reason = "";
    if nnz(valid) < 3 || any(strlength(strtrim(part.reference_plane)) == 0)
        status = "暂不能判定";
        reason = "温度点不足或参考面缺失";
    elseif ~isfinite(slopeUv)
        status = "暂不能判定";
        reason = "数据未标定为电压";
    end
    fitRows(k, :) = {groups.channel(k), groups.cycle(k), slopeUv, ...
        ciLowUv, ciHighUv, intercept, rSquared, hysteresisUv, ...
        nnz(valid), status, reason};
    for j = find(valid).'
        curveRows(end + 1, :) = {part.case_id(j), part.channel(j), ...
            "temperature_response", part.temperature_c(j), ...
            part.steady_mean(j) * 1e6, "uV"}; %#ok<AGROW>
    end
end
fits = cell2table(fitRows, 'VariableNames', { ...
    'channel', 'cycle', 'slope_uv_per_degc', 'ci95_low_uv_per_degc', ...
    'ci95_high_uv_per_degc', 'intercept_v', 'fit_r_squared', ...
    'hysteresis_uv', 'temperature_point_count', 'status', 'reason'});
summary = localSummary(fits, points);
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, fits, curves, sources);
figureHandle = localPlot(points);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "temperature_drift", cfg);
result = struct('config', cfg, 'summary', summary, 'details', fits, ...
    'points', points, 'curves', curves, 'sources', sources, ...
    'output', output, 'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [slope, intercept, ciLow, ciHigh, rSquared] = localRegression(x, y)
%LOCALREGRESSION Fit a line and approximate its 95 percent slope interval.
slope = NaN;
intercept = NaN;
ciLow = NaN;
ciHigh = NaN;
rSquared = NaN;
if numel(x) < 3 || range(x) == 0, return; end
design = [x(:), ones(numel(x), 1)];
coefficient = design \ y(:);
fitted = design * coefficient;
residual = y(:) - fitted;
dof = numel(x) - 2;
variance = sum(residual .^ 2) / dof;
covariance = variance * ((design.' * design) \ eye(2));
critical = tinv(0.975, dof);
standardError = sqrt(covariance(1, 1));
slope = coefficient(1);
intercept = coefficient(2);
ciLow = slope - critical * standardError;
ciHigh = slope + critical * standardError;
sst = sum((y(:) - mean(y)) .^ 2);
if sst > 0, rSquared = 1 - sum(residual .^ 2) / sst; end
end

function value = localHysteresis(points)
%LOCALHYSTERESIS Compare heating and cooling means at common temperatures.
value = NaN;
up = points(lower(strtrim(points.direction)) == "up", :);
down = points(lower(strtrim(points.direction)) == "down", :);
common = intersect(up.temperature_c, down.temperature_c);
if isempty(common), return; end
difference = nan(numel(common), 1);
for k = 1:numel(common)
    difference(k) = mean(up.steady_mean(up.temperature_c == common(k))) - ...
        mean(down.steady_mean(down.temperature_c == common(k)));
end
value = max(abs(difference));
end

function summary = localSummary(fits, points)
%LOCALSUMMARY Report worst slope, hysteresis, and cycle repeatability.
channels = unique(fits.channel, 'stable');
rows = cell(numel(channels), 7);
for k = 1:numel(channels)
    part = fits(fits.channel == channels(k), :);
    slopes = part.slope_uv_per_degc;
    finite = find(isfinite(slopes));
    if isempty(finite)
        worstSlope = NaN;
        status = "暂不能判定";
    else
        [~, index] = max(abs(slopes(finite)));
        worstSlope = slopes(finite(index));
        status = part.status(finite(index));
    end
    pointPart = points(points.channel == channels(k), :);
    cycleMeans = groupsummary(pointPart, 'cycle', 'mean', 'steady_mean');
    repeatability = range(cycleMeans.mean_steady_mean) * 1e6;
    rows(k, :) = {channels(k), worstSlope, ...
        localFiniteMax(part.hysteresis_uv), repeatability, status, ...
        height(part), height(pointPart)};
end
summary = cell2table(rows, 'VariableNames', { ...
    'channel', 'worst_slope_uv_per_degc', 'maximum_hysteresis_uv', ...
    'cycle_repeatability_uv', 'status', 'cycle_count', 'point_count'});
end

function value = localFiniteMax(input)
%LOCALFINITEMAX Return maximum finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(input); end
end

function figureHandle = localPlot(points)
%LOCALPLOT Plot steady-state voltage against measured temperature.
figureHandle = figure('Visible', 'off', 'Color', 'w');
channels = unique(points.channel, 'stable');
hold on;
for k = 1:numel(channels)
    mask = points.channel == channels(k);
    scatter(points.temperature_c(mask), points.steady_mean(mask) * 1e6, ...
        28, points.cycle(mask), 'filled', 'DisplayName', channels(k));
end
xlabel('Measured temperature (degC)');
ylabel('Steady mean (uV)');
title('Temperature drift');
grid on;
legend('Location', 'best');
end

function result = s33_analyze_loop_delay(cfg)
%S33_ANALYZE_LOOP_DELAY Measure dual-channel threshold-crossing delay.
%   RESULT = s33_analyze_loop_delay(CFG) detects rising and falling 50
%   percent crossings, linearly interpolates each crossing time, pairs
%   input and output edges, and subtracts cable_skew_s. It reports median,
%   P95, maximum, and acquisition resolution.
%
%   Each row contains one capture with value as output and reference as
%   input. CSV uses data_column/reference_column; MAT may use A/C2_data or
%   configured variables. requirement_id selects the 250 ns, 5 us, or
%   20 us limit. Resolution coarser than cfg.delayResolutionFraction of
%   the limit forces 暂不能判定.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "source_file"]);
summaryRows = cell(height(manifest), 11);
detailRows = cell(0, 7);
curveRows = cell(0, 6);
sourceRows = cell(height(manifest), 7);

for k = 1:height(manifest)
    row = manifest(k, :);
    capture = laser_analysis.load_test_capture(row);
    reason = "";
    delay = [];
    if isempty(capture.reference)
        reason = "缺少同步输入参考通道";
    elseif numel(capture.time_s) < cfg.minimumSamples
        reason = "样本数不足";
    else
        inputEdges = localCrossings(capture.time_s, capture.reference);
        outputEdges = localCrossings(capture.time_s, capture.value);
        delay = localPairEdges(inputEdges, outputEdges) - ...
            localZeroIfMissing(row.cable_skew_s);
    end
    resolution = localResolution(capture.time_s, row.measurement_resolution_s);
    medianDelay = localPercentile(delay, 50);
    p95Delay = localPercentile(delay, 95);
    maximumDelay = localFiniteMax(delay);
    requirement = laser_analysis.resolve_requirement( ...
        cfg, row.requirement_id, "delay", localDelaySubsystem(row.data_role));
    status = laser_analysis.evaluate_requirement( ...
        maximumDelay, requirement, cfg.formalEnabled);
    limit = localRequirementLimit(requirement);
    if strlength(reason) > 0 || strlength(strtrim(row.reference_plane)) == 0
        status = "暂不能判定";
    elseif ~isfinite(limit) || ...
            resolution > limit * cfg.delayResolutionFraction
        status = "暂不能判定";
        reason = "测量分辨率不足或需求行不唯一";
    end
    summaryRows(k, :) = {row.case_id, row.channel, numel(delay), ...
        medianDelay, p95Delay, maximumDelay, resolution, ...
        row.cable_skew_s, localRequirementId(requirement), status, reason};
    for j = 1:numel(delay)
        detailRows(end + 1, :) = {row.case_id, row.channel, j, ...
            delay(j), medianDelay, p95Delay, status}; %#ok<AGROW>
        curveRows(end + 1, :) = {row.case_id, row.channel, ...
            "edge_delay", j, delay(j), "s"}; %#ok<AGROW>
    end
    sourceRows(k, :) = {row.case_id, row.channel, capture.source_file, ...
        capture.sha256, capture.reference_plane, row.calibration_source, ...
        capture.sample_count};
end

summary = cell2table(summaryRows, 'VariableNames', { ...
    'case_id', 'channel', 'edge_count', 'median_delay_s', 'p95_delay_s', ...
    'maximum_delay_s', 'measurement_resolution_s', 'cable_skew_s', ...
    'requirement_id', 'status', 'reason'});
details = cell2table(detailRows, 'VariableNames', { ...
    'case_id', 'channel', 'edge_index', 'delay_s', 'median_delay_s', ...
    'p95_delay_s', 'status'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(details);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "loop_delay", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function edges = localCrossings(time, value)
%LOCALCROSSINGS Return interpolated rising and falling 50 percent edges.
threshold = 0.5 * (min(value) + max(value));
below = value < threshold;
indices = find(diff(below) ~= 0);
edges = nan(numel(indices), 2);
for k = 1:numel(indices)
    index = indices(k);
    edges(k, 1) = interp1(value(index:index + 1), ...
        time(index:index + 1), threshold);
    edges(k, 2) = sign(value(index + 1) - value(index));
end
end

function delay = localPairEdges(inputEdges, outputEdges)
%LOCALPAIREDGES Pair each input edge to the next output edge of same type.
delay = zeros(0, 1);
for k = 1:size(inputEdges, 1)
    candidates = find(outputEdges(:, 2) == inputEdges(k, 2) & ...
        outputEdges(:, 1) >= inputEdges(k, 1), 1, 'first');
    if ~isempty(candidates)
        delay(end + 1, 1) = ...
            outputEdges(candidates, 1) - inputEdges(k, 1); %#ok<AGROW>
    end
end
end

function value = localZeroIfMissing(value)
%LOCALZEROIFMISSING Treat omitted skew correction as zero, not measured.
if ~isfinite(value), value = 0; end
end

function value = localResolution(time, configured)
%LOCALRESOLUTION Return explicit resolution or median sample interval.
if isfinite(configured)
    value = configured;
elseif numel(time) >= 2
    value = median(diff(time));
else
    value = NaN;
end
end

function value = localPercentile(input, percentile)
%LOCALPERCENTILE Return a finite percentile or NaN.
input = sort(input(isfinite(input)));
if isempty(input)
    value = NaN;
else
    index = 1 + (numel(input) - 1) * percentile / 100;
    value = interp1(1:numel(input), input, index);
end
end

function value = localFiniteMax(input)
%LOCALFINITEMAX Return maximum finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(input); end
end

function subsystem = localDelaySubsystem(role)
%LOCALDELAYSUBSYSTEM Select loop or AD677 from explicit role metadata.
if contains(lower(role), "ad677")
    subsystem = "ad677";
else
    subsystem = "loop";
end
end

function limit = localRequirementLimit(requirement)
%LOCALREQUIREMENTLIMIT Return one scalar upper delay limit.
if height(requirement) == 1, limit = requirement.limit_a; else, limit = NaN; end
end

function id = localRequirementId(requirement)
%LOCALREQUIREMENTID Return one selected requirement id.
if height(requirement) == 1, id = requirement.requirement_id; else, id = ""; end
end

function figureHandle = localPlot(details)
%LOCALPLOT Plot delay by edge index.
figureHandle = figure('Visible', 'off', 'Color', 'w');
channels = unique(details.channel, 'stable');
hold on;
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.edge_index(mask), details.delay_s(mask) * 1e6, ...
        'o-', 'DisplayName', channels(k));
end
xlabel('Edge index');
ylabel('Delay (us)');
title('Loop delay');
grid on;
legend('Location', 'best');
end

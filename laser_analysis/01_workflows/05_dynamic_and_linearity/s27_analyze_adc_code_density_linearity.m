function result = s27_analyze_adc_code_density_linearity(cfg)
%S27_ANALYZE_ADC_CODE_DENSITY_LINEARITY Compute sine-histogram DNL/INL.
%   RESULT = s27_analyze_adc_code_density_linearity(CFG) combines code
%   captures by channel and estimates ideal sine-wave code occupancy.
%   DNL[k]=Nactual[k]/Nideal[k]-1. INL is the cumulative DNL with both
%   endpoint and best-fit line removal.
%
%   Each manifest row must identify bits, coding, source_file, and channel.
%   Near-full-scale coverage and adequate expected counts are required for
%   a formal result. The script reports missing codes and endpoint
%   overdrive evidence; it never treats a sparse histogram as passing.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["channel", "source_file", "bits"]);
channels = unique(manifest.channel, 'stable');
summaryRows = cell(numel(channels), 10);
detailRows = cell(0, 8);
curveRows = cell(0, 6);
sourceRows = cell(height(manifest), 7);

for k = 1:height(manifest)
    capture = laser_analysis.load_test_capture(manifest(k, :));
    sourceRows(k, :) = {manifest.case_id(k), manifest.channel(k), ...
        capture.source_file, capture.sha256, capture.reference_plane, ...
        manifest.calibration_source(k), capture.sample_count};
end

for k = 1:numel(channels)
    rowMask = manifest.channel == channels(k);
    rows = manifest(rowMask, :);
    allCodes = zeros(0, 1);
    for j = 1:height(rows)
        capture = laser_analysis.load_test_capture(rows(j, :));
        codes = capture.raw_code;
        if isempty(codes) && capture.unit == "code", codes = capture.value; end
        allCodes = [allCodes; round(codes(:))]; %#ok<AGROW>
    end
    bits = unique(rows.bits(isfinite(rows.bits)));
    if numel(bits) ~= 1 || isempty(allCodes)
        summaryRows(k, :) = {channels(k), numel(allCodes), NaN, NaN, ...
            NaN, NaN, NaN, NaN, "暂不能判定", ...
            "bits 不唯一或没有原始码"};
        continue;
    end
    bits = round(bits);
    [codeAxis, count, expected, dnl, inlEndpoint, inlBestFit] = ...
        localSineHistogram(allCodes, bits, rows.coding(1), cfg);
    valid = isfinite(dnl);
    coverage = nnz(count > 0) / numel(count);
    missingCodeCount = nnz(count(valid) == 0);
    maxDnl = localMaxAbs(dnl);
    maxEndpoint = localMaxAbs(inlEndpoint);
    maxBestFit = localMaxAbs(inlBestFit);
    enoughCounts = all(expected(valid) >= cfg.minimumExpectedCountsPerCode);
    requirementDnl = laser_analysis.find_requirement(cfg, "dnl", "adc");
    requirementInl = laser_analysis.find_requirement(cfg, "inl", "adc");
    dnlStatus = laser_analysis.evaluate_requirement( ...
        maxDnl, requirementDnl, cfg.formalEnabled);
    inlStatus = laser_analysis.evaluate_requirement( ...
        maxEndpoint, requirementInl, cfg.formalEnabled);
    reason = "";
    if coverage < cfg.minimumCodeCoverage || ~enoughCounts
        dnlStatus = "暂不能判定";
        inlStatus = "暂不能判定";
        reason = "码覆盖或每码期望计数不足";
    end
    combinedStatus = localCombineStatus([dnlStatus, inlStatus]);
    summaryRows(k, :) = {channels(k), numel(allCodes), coverage, ...
        missingCodeCount, maxDnl, maxEndpoint, maxBestFit, enoughCounts, ...
        combinedStatus, reason};
    for j = 1:numel(codeAxis)
        detailRows(end + 1, :) = {channels(k), codeAxis(j), count(j), ...
            expected(j), dnl(j), inlEndpoint(j), inlBestFit(j), ...
            valid(j)}; %#ok<AGROW>
        curveRows(end + 1, :) = {channels(k), channels(k), ...
            "DNL", codeAxis(j), dnl(j), "LSB"}; %#ok<AGROW>
        curveRows(end + 1, :) = {channels(k), channels(k), ...
            "INL_endpoint", codeAxis(j), inlEndpoint(j), "LSB"}; %#ok<AGROW>
    end
end

summary = cell2table(summaryRows, 'VariableNames', { ...
    'channel', 'sample_count', 'code_coverage_ratio', ...
    'missing_code_count', 'maximum_abs_dnl_lsb', ...
    'maximum_abs_inl_endpoint_lsb', 'maximum_abs_inl_best_fit_lsb', ...
    'expected_counts_adequate', 'status', 'reason'});
details = cell2table(detailRows, 'VariableNames', { ...
    'channel', 'code', 'actual_count', 'ideal_count', 'dnl_lsb', ...
    'inl_endpoint_lsb', 'inl_best_fit_lsb', 'valid_code'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(details);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "adc_code_density_linearity", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [axis, count, expected, dnl, endpoint, bestFit] = ...
        localSineHistogram(codes, bits, coding, cfg)
%LOCALSINEHISTOGRAM Estimate ideal arcsine occupancy and code linearity.
if lower(strtrim(coding)) == "unipolar"
    minimumCode = 0;
    maximumCode = 2 ^ bits - 1;
else
    minimumCode = -2 ^ (bits - 1);
    maximumCode = 2 ^ (bits - 1) - 1;
end
axis = (minimumCode:maximumCode).';
count = histcounts(codes, ...
    (minimumCode - 0.5):(maximumCode + 0.5)).';
center = 0.5 * (min(codes) + max(codes));
amplitude = 0.5 * (max(codes) - min(codes));
lowEdge = axis - 0.5;
highEdge = axis + 0.5;
cdfLow = localSineCdf(lowEdge, center, amplitude);
cdfHigh = localSineCdf(highEdge, center, amplitude);
expected = numel(codes) * (cdfHigh - cdfLow);
valid = expected >= cfg.minimumExpectedCountsPerCode;
dnl = nan(size(axis));
dnl(valid) = count(valid) ./ expected(valid) - 1;
endpoint = nan(size(axis));
bestFit = nan(size(axis));
active = find(valid);
if numel(active) < 3, return; end
cumulative = cumsum(dnl(active));
x = axis(active);
endpointLine = interp1(x([1, end]), cumulative([1, end]), x);
endpoint(active) = cumulative - endpointLine;
coefficient = polyfit(x, cumulative, 1);
bestFit(active) = cumulative - polyval(coefficient, x);
end

function probability = localSineCdf(edge, center, amplitude)
%LOCALSINECDF Return the CDF of a sinusoid sampled at uniform phase.
if amplitude <= 0
    probability = nan(size(edge));
    return;
end
normalized = max(-1, min(1, (edge - center) / amplitude));
probability = 0.5 + asin(normalized) / pi;
end

function value = localMaxAbs(input)
%LOCALMAXABS Return maximum absolute finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(abs(input)); end
end

function status = localCombineStatus(values)
%LOCALCOMBINESTATUS Combine metric judgments conservatively.
if any(values == "暂不能判定")
    status = "暂不能判定";
elseif any(values == "不满足")
    status = "不满足";
elseif all(values == "满足")
    status = "满足";
else
    status = "未测试";
end
end

function figureHandle = localPlot(details)
%LOCALPLOT Plot DNL and endpoint INL for each channel.
figureHandle = figure('Visible', 'off', 'Color', 'w');
tiledlayout(2, 1);
nexttile;
hold on;
channels = unique(details.channel, 'stable');
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.code(mask), details.dnl_lsb(mask), ...
        'DisplayName', channels(k));
end
ylabel('DNL (LSB)');
grid on;
legend('Location', 'best');
nexttile;
hold on;
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.code(mask), details.inl_endpoint_lsb(mask), ...
        'DisplayName', channels(k));
end
xlabel('ADC code');
ylabel('INL endpoint (LSB)');
grid on;
end

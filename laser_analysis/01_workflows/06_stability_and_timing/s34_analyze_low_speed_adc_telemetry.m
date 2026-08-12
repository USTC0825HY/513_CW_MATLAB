function result = s34_analyze_low_speed_adc_telemetry(cfg)
%S34_ANALYZE_LOW_SPEED_ADC_TELEMETRY Analyze ADC128, AD677, and telemetry.
%   RESULT = s34_analyze_low_speed_adc_telemetry(CFG) supports data_role
%   values adc128_noise, ad677_noise, frequency_response, and telemetry.
%   It reports RMS noise, 1 Hz-10 kHz ASD, effective sample rate, response
%   amplitude, and maximum absolute telemetry error.
%
%   Noise captures require explicit sample rate and reference plane.
%   Telemetry rows use reference_value and measured_value. Frequency
%   response rows require stimulus_frequency_hz and are normalized within
%   each channel; 12 kHz coverage is not extrapolated.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "data_role"]);
detailRows = cell(0, 13);
curveRows = cell(0, 6);
sourceRows = cell(0, 7);

for k = 1:height(manifest)
    row = manifest(k, :);
    role = lower(strtrim(row.data_role));
    if role == "telemetry"
        errorMv = abs(row.measured_value - row.reference_value) * 1e3;
        requirement = laser_analysis.resolve_requirement( ...
            cfg, row.requirement_id, "accuracy", "telemetry");
        status = laser_analysis.evaluate_requirement( ...
            errorMv, requirement, cfg.formalEnabled);
        if strlength(strtrim(row.reference_plane)) == 0
            status = "暂不能判定";
        end
        detailRows(end + 1, :) = localDetailRow(row, NaN, NaN, ...
            NaN, NaN, errorMv, NaN, "未测试", requirement, ...
            status, ""); %#ok<AGROW>
        continue;
    end
    if strlength(strtrim(row.source_file)) == 0
        detailRows(end + 1, :) = localDetailRow(row, NaN, NaN, ...
            NaN, NaN, NaN, NaN, "未测试", table(), "暂不能判定", ...
            "缺少源文件"); %#ok<AGROW>
        continue;
    end
    capture = laser_analysis.load_test_capture(row);
    sourceRows(end + 1, :) = {row.case_id, row.channel, ...
        capture.source_file, capture.sha256, capture.reference_plane, ...
        row.calibration_source, capture.sample_count}; %#ok<AGROW>
    rmsMv = rms(capture.value - mean(capture.value)) * 1e3;
    maximumAsd = NaN;
    amplitude = NaN;
    bandwidth = NaN;
    sampleRateStatus = "未测试";
    reason = "";
    if role == "adc128_noise"
        requirement = laser_analysis.resolve_requirement( ...
            cfg, row.requirement_id, "rms_noise", "adc128");
        value = rmsMv;
    elseif role == "ad677_noise"
        [frequency, asd] = localAsd(capture);
        band = frequency >= 1 & frequency <= 10e3;
        if ~isfinite(capture.fs_hz) || capture.fs_hz / 2 < 10e3 || ...
                numel(frequency) < 2 || frequency(2) > 1
            reason = "1 Hz-10 kHz 频段覆盖不足";
        elseif any(band)
            maximumAsd = max(asd(band)) * 1e6;
        end
        for j = 1:numel(frequency)
            curveRows(end + 1, :) = {row.case_id, row.channel, ...
                "ASD", frequency(j), asd(j) * 1e6, ...
                "uV/sqrt(Hz)"}; %#ok<AGROW>
        end
        requirement = laser_analysis.resolve_requirement( ...
            cfg, row.requirement_id, "asd_1_10khz", "ad677");
        value = maximumAsd;
        sampleRateRequirement = laser_analysis.find_requirement( ...
            cfg, "sample_rate", "ad677");
        sampleRateStatus = laser_analysis.evaluate_requirement( ...
            capture.fs_hz, sampleRateRequirement, cfg.formalEnabled);
    elseif role == "frequency_response"
        if isfinite(capture.fs_hz) && isfinite(row.stimulus_frequency_hz) && ...
                row.stimulus_frequency_hz < capture.fs_hz / 2
            fit = laser_analysis.fit_tone(capture.time_s, ...
                capture.value, row.stimulus_frequency_hz);
            amplitude = fit.amplitude;
        else
            reason = "采样率或激励频率无效";
        end
        requirement = table();
        value = amplitude;
    else
        requirement = table();
        value = NaN;
        reason = "未知 data_role";
    end
    status = laser_analysis.evaluate_requirement( ...
        value, requirement, cfg.formalEnabled);
    if role == "frequency_response"
        status = "未测试";
    elseif role == "ad677_noise"
        status = localCombineStatus([status; sampleRateStatus]);
    end
    if strlength(strtrim(capture.reference_plane)) == 0 || ...
            strlength(reason) > 0
        status = "暂不能判定";
    end
    detailRows(end + 1, :) = localDetailRow(row, capture.fs_hz, ...
        rmsMv, maximumAsd, amplitude, NaN, bandwidth, sampleRateStatus, ...
        requirement, status, reason); %#ok<AGROW>
end

details = cell2table(detailRows, 'VariableNames', { ...
    'case_id', 'channel', 'data_role', 'fs_hz', 'rms_noise_mv', ...
    'maximum_asd_uv_per_sqrthz', 'tone_amplitude', ...
    'telemetry_error_mv', 'bandwidth_hz', 'sample_rate_status', ...
    'requirement_id', 'status', 'reason'});
[summary, responseCurves] = localSummary(details, manifest, cfg);
curves = [cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'}); ...
    responseCurves];
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(curves);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "low_speed_adc_telemetry", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function row = localDetailRow(manifestRow, fs, rmsMv, asd, amplitude, ...
        errorMv, bandwidth, sampleRateStatus, requirement, status, reason)
%LOCALDETAILROW Build one stable detail row.
row = {manifestRow.case_id, manifestRow.channel, manifestRow.data_role, ...
    fs, rmsMv, asd, amplitude, errorMv, bandwidth, ...
    sampleRateStatus, localRequirementId(requirement), status, reason};
end

function [frequency, asd] = localAsd(capture)
%LOCALASD Compute a full-record one-sided ASD.
frequency = [];
asd = [];
if ~isfinite(capture.fs_hz) || numel(capture.value) < 16, return; end
x = capture.value - mean(capture.value);
[psd, frequency] = periodogram(x, hann(numel(x), 'periodic'), ...
    numel(x), capture.fs_hz, 'onesided');
asd = sqrt(psd);
end

function [summary, curves] = localSummary(details, manifest, cfg)
%LOCALSUMMARY Combine role results and derive response bandwidth.
channels = unique(details.channel, 'stable');
rows = cell(numel(channels), 8);
curveRows = cell(0, 6);
for k = 1:numel(channels)
    part = details(details.channel == channels(k), :);
    response = part(lower(part.data_role) == "frequency_response", :);
    bandwidth = NaN;
    responseStatus = "未测试";
    if ~isempty(response)
        frequencies = manifest.stimulus_frequency_hz( ...
            manifest.channel == channels(k) & ...
            lower(manifest.data_role) == "frequency_response");
        amplitudes = response.tone_amplitude;
        valid = isfinite(frequencies) & isfinite(amplitudes) & amplitudes > 0;
        frequencies = frequencies(valid);
        amplitudes = amplitudes(valid);
        [frequencies, order] = sort(frequencies);
        amplitudes = amplitudes(order);
        if ~isempty(amplitudes)
            responseDb = 20 * log10(amplitudes / amplitudes(1));
            bandwidth = localCrossing(frequencies, responseDb, -3);
            for j = 1:numel(frequencies)
                curveRows(end + 1, :) = {channels(k), channels(k), ...
                    "response_db", frequencies(j), responseDb(j), ...
                    "dB"}; %#ok<AGROW>
            end
            requirement = laser_analysis.find_requirement( ...
                cfg, "input_bandwidth", "ad677");
            responseStatus = laser_analysis.evaluate_requirement( ...
                bandwidth, requirement, cfg.formalEnabled);
        end
    end
    statuses = [part.status; responseStatus];
    overall = localCombineStatus(statuses);
    rows(k, :) = {channels(k), localFiniteMax(part.rms_noise_mv), ...
        localFiniteMax(part.maximum_asd_uv_per_sqrthz), ...
        localFiniteMax(part.telemetry_error_mv), bandwidth, ...
        responseStatus, overall, height(part)};
end
summary = cell2table(rows, 'VariableNames', { ...
    'channel', 'maximum_rms_noise_mv', ...
    'maximum_asd_uv_per_sqrthz', 'maximum_telemetry_error_mv', ...
    'bandwidth_3db_hz', 'bandwidth_status', 'status', 'record_count'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
end

function crossing = localCrossing(x, y, threshold)
%LOCALCROSSING Interpolate the first descending response crossing.
crossing = NaN;
for k = 2:numel(x)
    if y(k - 1) > threshold && y(k) <= threshold
        crossing = interp1(y(k - 1:k), x(k - 1:k), threshold);
        return;
    end
end
end

function id = localRequirementId(requirement)
%LOCALREQUIREMENTID Return one selected requirement id.
if height(requirement) == 1, id = requirement.requirement_id; else, id = ""; end
end

function status = localCombineStatus(values)
%LOCALCOMBINESTATUS Combine low-speed test judgments conservatively.
values = values(values ~= "未测试");
if isempty(values)
    status = "未测试";
elseif any(values == "暂不能判定")
    status = "暂不能判定";
elseif any(values == "不满足")
    status = "不满足";
elseif all(values == "满足")
    status = "满足";
else
    status = "未测试";
end
end

function value = localFiniteMax(input)
%LOCALFINITEMAX Return maximum finite value or NaN.
input = input(isfinite(input));
if isempty(input), value = NaN; else, value = max(input); end
end

function figureHandle = localPlot(curves)
%LOCALPLOT Plot low-speed ASD and response curves.
figureHandle = figure('Visible', 'off', 'Color', 'w');
if isempty(curves)
    text(0.5, 0.5, 'No curve data', 'HorizontalAlignment', 'center');
    axis off;
    return;
end
groups = unique(curves(:, {'channel', 'curve_type'}), 'rows', 'stable');
hold on;
for k = 1:height(groups)
    mask = curves.channel == groups.channel(k) & ...
        curves.curve_type == groups.curve_type(k);
    semilogx(curves.x_value(mask), curves.y_value(mask), ...
        'DisplayName', groups.channel(k) + " " + groups.curve_type(k));
end
xlabel('Frequency (Hz)');
ylabel('Metric value');
grid on;
legend('Location', 'best');
end

function result = s31_analyze_phase_noise_compliance(cfg)
%S31_ANALYZE_PHASE_NOISE_COMPLIANCE Assess 1 Hz and 100 kHz phase noise.
%   RESULT = s31_analyze_phase_noise_compliance(CFG) accepts phase-noise
%   CSV files or TimeLab .tim time-error records. Direct curves use
%   frequency_column and phase_noise_column. Time-error data use
%   phi(t)=2*pi*f0*x(t), then L(f)=10*log10(Sphi(f)/2).
%
%   TimeLab rows require tau0_s and carrier_frequency_hz unless the carrier
%   is present as "Input Freq" metadata. A target offset is judged only
%   when it lies between the first positive Fourier bin and Nyquist.
%   Instrument-floor values may be supplied as reference_value; no floor
%   is invented when absent.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "source_file"]);
summaryRows = cell(height(manifest), 12);
detailRows = cell(0, 8);
curveRows = cell(0, 6);
sourceRows = cell(height(manifest), 7);

for k = 1:height(manifest)
    row = manifest(k, :);
    [frequencyHz, phaseNoise, resolutionHz, carrierHz, sampleCount] = ...
        localReadPhaseNoise(row);
    hash = laser_analysis.sha256_file(row.source_file);
    sourceRows(k, :) = {row.case_id, row.channel, row.source_file, ...
        hash, row.reference_plane, row.calibration_source, sampleCount};
    values = nan(size(cfg.targetOffsetsHz));
    actualOffsets = nan(size(cfg.targetOffsetsHz));
    statuses = repmat("暂不能判定", size(cfg.targetOffsetsHz));
    for j = 1:numel(cfg.targetOffsetsHz)
        target = cfg.targetOffsetsHz(j);
        [values(j), actualOffsets(j)] = ...
            localValueAtOffset(frequencyHz, phaseNoise, target);
        metric = "phase_noise_" + localOffsetName(target);
        requirement = laser_analysis.resolve_requirement( ...
            cfg, row.requirement_id, metric, "dac");
        statuses(j) = laser_analysis.evaluate_requirement( ...
            values(j), requirement, cfg.formalEnabled);
        if strlength(strtrim(row.reference_plane)) == 0 || ...
                ~isfinite(values(j))
            statuses(j) = "暂不能判定";
        end
        detailRows(end + 1, :) = {row.case_id, row.channel, target, ...
            actualOffsets(j), values(j), resolutionHz, ...
            localFloorMargin(values(j), row.reference_value), ...
            statuses(j)}; %#ok<AGROW>
    end
    for j = 1:numel(frequencyHz)
        curveRows(end + 1, :) = {row.case_id, row.channel, ...
            "phase_noise", frequencyHz(j), phaseNoise(j), ...
            "dBc/Hz"}; %#ok<AGROW>
    end
    summaryRows(k, :) = {row.case_id, row.channel, carrierHz, ...
        resolutionHz, localFiniteMin(frequencyHz(frequencyHz > 0)), ...
        localFiniteMax(frequencyHz), values(1), values(end), ...
        statuses(1), statuses(end), ...
        localCombineStatus(statuses), row.reference_value};
end

summary = cell2table(summaryRows, 'VariableNames', { ...
    'case_id', 'channel', 'carrier_frequency_hz', ...
    'frequency_resolution_hz', 'minimum_offset_hz', 'maximum_offset_hz', ...
    'phase_noise_1hz_dbc_per_hz', 'phase_noise_100khz_dbc_per_hz', ...
    'status_1hz', 'status_100khz', 'status', ...
    'instrument_floor_dbc_per_hz'});
details = cell2table(detailRows, 'VariableNames', { ...
    'case_id', 'channel', 'target_offset_hz', 'actual_offset_hz', ...
    'phase_noise_dbc_per_hz', 'frequency_resolution_hz', ...
    'instrument_floor_margin_db', 'status'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(curves);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "phase_noise_compliance", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [frequency, phaseNoise, resolution, carrier, sampleCount] = ...
        localReadPhaseNoise(row)
%LOCALREADPHASENOISE Read a direct curve or derive one from TimeLab TIC.
[~, ~, extension] = fileparts(row.source_file);
format = lower(strtrim(row.format));
if strlength(format) == 0, format = erase(lower(string(extension)), "."); end
carrier = row.carrier_frequency_hz;
if format == "tim"
    [timeError, embeddedCarrier] = localReadTimeLab(row.source_file, ...
        row.data_column);
    if ~isfinite(carrier), carrier = embeddedCarrier; end
    if ~isfinite(row.tau0_s) || ~isfinite(carrier)
        frequency = [];
        phaseNoise = [];
        resolution = NaN;
        sampleCount = numel(timeError);
        return;
    end
    phase = 2 * pi * carrier * detrend(timeError, 1);
    sampleCount = numel(phase);
    fsHz = 1 / row.tau0_s;
    [phasePsd, frequency] = periodogram(phase, ...
        hann(sampleCount, 'periodic'), sampleCount, fsHz, 'onesided');
    phaseNoise = 10 * log10(phasePsd / 2);
else
    matrix = readmatrix(row.source_file);
    if ~isfinite(row.frequency_column) || ~isfinite(row.phase_noise_column)
        error('laser_analysis:ManifestValue', ...
            'Phase-noise CSV requires frequency_column and phase_noise_column.');
    end
    frequency = matrix(:, round(row.frequency_column));
    phaseNoise = matrix(:, round(row.phase_noise_column));
    valid = isfinite(frequency) & isfinite(phaseNoise) & frequency > 0;
    frequency = frequency(valid);
    phaseNoise = phaseNoise(valid);
    [frequency, order] = sort(frequency);
    phaseNoise = phaseNoise(order);
    sampleCount = numel(frequency);
end
if numel(frequency) >= 2
    resolution = min(diff(frequency));
else
    resolution = NaN;
end
end

function [timeError, carrier] = localReadTimeLab(filePath, dataColumn)
%LOCALREADTIMELAB Parse Input Freq metadata and the numeric TIC block.
text = fileread(filePath);
carrierToken = regexp(text, ...
    '"Input Freq"\s+([-+0-9.Ee]+)', 'tokens', 'once');
if isempty(carrierToken), carrier = NaN; else, carrier = str2double(carrierToken{1}); end
header = regexp(text, '(?m)^TIC\s+(\d+)\s+(\d+)\s*$', 'tokens', 'once');
startIndex = regexp(text, '(?m)^TIC\s+\d+\s+\d+\s*$', 'end', 'once');
if isempty(header) || isempty(startIndex)
    error('laser_analysis:TimeLabFormat', 'TimeLab TIC block not found.');
end
rowCount = str2double(header{1});
columnCount = str2double(header{2});
values = sscanf(text(startIndex + 1:end), '%f');
values = values(1:min(numel(values), rowCount * columnCount));
matrix = reshape(values, columnCount, []).';
if ~isfinite(dataColumn), dataColumn = 1; end
if dataColumn > size(matrix, 2)
    error('laser_analysis:ManifestColumn', ...
        'data_column exceeds TimeLab TIC channels.');
end
timeError = matrix(:, round(dataColumn));
end

function [value, actual] = localValueAtOffset(frequency, curve, target)
%LOCALVALUEATOFFSET Interpolate only within measured offset coverage.
value = NaN;
actual = NaN;
if numel(frequency) < 2 || target < min(frequency) || target > max(frequency)
    return;
end
value = interp1(log10(frequency), curve, log10(target), 'linear');
actual = target;
end

function name = localOffsetName(offset)
%LOCALOFFSETNAME Convert supported target offsets to requirement suffixes.
if abs(offset - 1) < eps
    name = "1hz";
elseif abs(offset - 100e3) < eps(100e3)
    name = "100khz";
else
    name = lower(string(offset)) + "hz";
end
end

function margin = localFloorMargin(value, floorValue)
%LOCALFLOORMARGIN Return DUT-to-instrument-floor margin when supplied.
if isfinite(value) && isfinite(floorValue)
    margin = value - floorValue;
else
    margin = NaN;
end
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

function status = localCombineStatus(values)
%LOCALCOMBINESTATUS Combine phase-noise judgments conservatively.
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

function figureHandle = localPlot(curves)
%LOCALPLOT Plot complete phase-noise curves.
figureHandle = figure('Visible', 'off', 'Color', 'w');
channels = unique(curves.channel, 'stable');
hold on;
for k = 1:numel(channels)
    mask = curves.channel == channels(k);
    semilogx(curves.x_value(mask), curves.y_value(mask), ...
        'DisplayName', channels(k));
end
xlabel('Offset frequency (Hz)');
ylabel('L(f) (dBc/Hz)');
title('Phase-noise compliance');
grid on;
legend('Location', 'best');
end

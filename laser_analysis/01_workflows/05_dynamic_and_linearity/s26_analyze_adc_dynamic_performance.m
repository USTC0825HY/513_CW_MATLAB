function result = s26_analyze_adc_dynamic_performance(cfg)
%S26_ANALYZE_ADC_DYNAMIC_PERFORMANCE Analyze ADC tones and response.
%   RESULT = s26_analyze_adc_dynamic_performance(CFG) reads the explicit
%   manifest in CFG.manifestFile and reports tone fit, SFDR, response,
%   phase, clipping, and 1 dB compression evidence. Harmonics are treated
%   as spurs. A formal judgment requires an approved requirement, sample
%   rate, in-band tone, and a nonempty reference plane.
%
%   Create CFG with laser_analysis.make_test_config. Each capture row needs
%   case_id, channel, source_file, fs_hz or time data, and
%   stimulus_frequency_hz. A reference column is required for phase
%   transfer and -45 degree bandwidth. stimulus_level is required for
%   compression analysis.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "source_file"]);
nRows = height(manifest);
detailRows = cell(nRows, 16);
curveRows = cell(0, 6);
sourceRows = cell(nRows, 7);

for k = 1:nRows
    row = manifest(k, :);
    capture = laser_analysis.load_test_capture(row);
    toneHz = row.stimulus_frequency_hz;
    fit = localEmptyFit();
    spectrum = localEmptySpectrum();
    reason = "";
    if ~isfinite(capture.fs_hz)
        reason = "缺少采样率";
    elseif ~isfinite(toneHz) || toneHz <= 0 || toneHz >= capture.fs_hz / 2
        reason = "激励频率缺失或超出 Nyquist";
    elseif capture.sample_count < cfg.minimumSamples
        reason = "样本数不足";
    else
        fit = laser_analysis.fit_tone(capture.time_s, capture.value, toneHz);
        transferPhaseDeg = NaN;
        hasReference = ~isempty(capture.reference);
        if hasReference
            referenceFit = laser_analysis.fit_tone( ...
                capture.time_s, capture.reference, toneHz);
            transferPhaseDeg = rad2deg(angle(fit.phasor / referenceFit.phasor));
        end
        spectrum = laser_analysis.spectrum_metrics(capture.value, ...
            capture.fs_hz, toneHz, cfg.sfdrGuardBins);
        count = numel(spectrum.frequency_hz);
        newRows = cell(count, 6);
        for j = 1:count
            newRows(j, :) = {row.case_id, row.channel, "PSD", ...
                spectrum.frequency_hz(j), spectrum.psd_per_hz(j), ...
                capture.unit + "^2/Hz"};
        end
        curveRows = [curveRows; newRows]; %#ok<AGROW>
    end
    if ~exist('transferPhaseDeg', 'var')
        transferPhaseDeg = NaN;
        hasReference = false;
    end

    requirement = laser_analysis.find_requirement(cfg, "sfdr", "adc");
    status = laser_analysis.evaluate_requirement( ...
        spectrum.sfdr_db, requirement, cfg.formalEnabled);
    if strlength(strtrim(row.reference_plane)) == 0 || strlength(reason) > 0
        status = "暂不能判定";
    end
    detailRows(k, :) = {row.case_id, row.channel, toneHz, capture.fs_hz, ...
        fit.frequency_hz, fit.amplitude, transferPhaseDeg, hasReference, ...
        fit.r_squared, ...
        spectrum.sfdr_db, spectrum.maximum_spur_frequency_hz, ...
        spectrum.df_hz, row.stimulus_level, localClipped(capture, row, cfg), ...
        status, reason};
    sourceRows(k, :) = {row.case_id, row.channel, capture.source_file, ...
        capture.sha256, capture.reference_plane, row.calibration_source, ...
        capture.sample_count};
    clear transferPhaseDeg hasReference
end

details = cell2table(detailRows, 'VariableNames', { ...
    'case_id', 'channel', 'stimulus_frequency_hz', 'fs_hz', ...
    'fitted_frequency_hz', 'amplitude_peak', 'transfer_phase_deg', ...
    'has_reference', 'fit_r_squared', ...
    'sfdr_db', 'maximum_spur_frequency_hz', 'frequency_resolution_hz', ...
    'stimulus_level', 'clipped', 'status', 'reason'});
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
[summary, responseCurve] = localSummarize(details, manifest, cfg);
curves = [curves; responseCurve];

output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(details);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "adc_dynamic_performance", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function [summary, curve] = localSummarize(details, manifest, cfg)
%LOCALSUMMARIZE Derive per-channel worst SFDR and response bandwidth.
channels = unique(details.channel, 'stable');
rows = cell(0, 9);
curveRows = cell(0, 6);
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    part = details(mask, :);
    valid = isfinite(part.amplitude_peak) & part.amplitude_peak > 0;
    if any(valid)
        frequencies = part.stimulus_frequency_hz(valid);
        amplitudes = part.amplitude_peak(valid);
        [frequencies, order] = sort(frequencies);
        amplitudes = amplitudes(order);
        reference = localReferenceAmplitude( ...
            frequencies, amplitudes, cfg.responseReferenceHz);
        responseDb = 20 * log10(amplitudes / reference);
        bandwidth3Db = localCrossing(frequencies, responseDb, -3);
        phasePart = part.transfer_phase_deg(valid);
        phasePart = phasePart(order);
        hasReference = part.has_reference(valid);
        hasReference = hasReference(order);
        bandwidth45Deg = NaN;
        if all(hasReference)
            unwrappedPhase = rad2deg(unwrap(deg2rad(phasePart)));
            bandwidth45Deg = localCrossing(frequencies, unwrappedPhase, -45);
        end
        for j = 1:numel(frequencies)
            curveRows(end + 1, :) = {channels(k), channels(k), ...
                "response_db", frequencies(j), responseDb(j), "dB"}; ...
                %#ok<AGROW>
        end
    else
        bandwidth3Db = NaN;
        bandwidth45Deg = NaN;
    end
    sfdrValues = part.sfdr_db(isfinite(part.sfdr_db));
    if isempty(sfdrValues), worstSfdr = NaN; else, worstSfdr = min(sfdrValues); end
    sfdrRequirement = laser_analysis.find_requirement(cfg, "sfdr", "adc");
    sfdrStatus = laser_analysis.evaluate_requirement( ...
        worstSfdr, sfdrRequirement, cfg.formalEnabled);
    if any(strlength(strtrim(part.reason)) > 0) || ...
            any(strlength(strtrim(manifest.reference_plane(mask))) == 0)
        sfdrStatus = "暂不能判定";
    end
    phaseRequirement = laser_analysis.find_requirement( ...
        cfg, "phase_bandwidth", "adc");
    phaseStatus = laser_analysis.evaluate_requirement( ...
        bandwidth45Deg, phaseRequirement, cfg.formalEnabled);
    compressionDb = localCompression(part, cfg.compressionThresholdDb);
    rows(end + 1, :) = {channels(k), worstSfdr, sfdrStatus, ...
        bandwidth3Db, bandwidth45Deg, phaseStatus, compressionDb, ...
        sum(part.clipped), height(part)}; %#ok<AGROW>
end
summary = cell2table(rows, 'VariableNames', { ...
    'channel', 'worst_sfdr_db', 'sfdr_status', 'bandwidth_3db_hz', ...
    'bandwidth_45deg_hz', 'phase_bandwidth_status', ...
    'compression_input_level', 'clipped_case_count', 'case_count'});
curve = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
end

function reference = localReferenceAmplitude(frequency, amplitude, referenceHz)
%LOCALREFERENCEAMPLITUDE Select an explicit or lowest-frequency reference.
if isfinite(referenceHz)
    [~, index] = min(abs(frequency - referenceHz));
else
    index = 1;
end
reference = amplitude(index);
end

function crossing = localCrossing(x, y, threshold)
%LOCALCROSSING Linearly interpolate the first descending threshold crossing.
crossing = NaN;
for k = 2:numel(x)
    if y(k - 1) > threshold && y(k) <= threshold
        crossing = interp1(y(k - 1:k), x(k - 1:k), threshold);
        return;
    end
end
end

function level = localCompression(part, thresholdDb)
%LOCALCOMPRESSION Estimate the first input level with threshold gain loss.
level = NaN;
valid = isfinite(part.stimulus_level) & ...
    isfinite(part.amplitude_peak) & part.amplitude_peak > 0;
if nnz(valid) < 3, return; end
x = part.stimulus_level(valid);
y = 20 * log10(part.amplitude_peak(valid));
[x, order] = sort(x);
y = y(order);
baselineCount = max(2, floor(numel(x) / 3));
coefficient = polyfit(x(1:baselineCount), y(1:baselineCount), 1);
loss = polyval(coefficient, x) - y;
index = find(loss >= thresholdDb, 1, 'first');
if ~isempty(index), level = x(index); end
end

function clipped = localClipped(capture, row, cfg)
%LOCALCLIPPED Detect repeated ADC rail samples when code metadata is present.
clipped = false;
if isempty(capture.raw_code) || ~isfinite(row.bits), return; end
minimum = min(capture.raw_code);
maximum = max(capture.raw_code);
if lower(strtrim(row.coding)) == "unipolar"
    lowRail = 0;
    highRail = 2 ^ row.bits - 1;
else
    lowRail = -2 ^ (row.bits - 1);
    highRail = 2 ^ (row.bits - 1) - 1;
end
clipped = minimum <= lowRail + cfg.clipRailMarginCode || ...
    maximum >= highRail - cfg.clipRailMarginCode;
end

function fit = localEmptyFit()
%LOCALEMPTYFIT Return NaN fields for an uncomputed tone fit.
fit = struct('frequency_hz', NaN, 'amplitude', NaN, ...
    'phase_deg', NaN, 'r_squared', NaN);
end

function spectrum = localEmptySpectrum()
%LOCALEMPTYSPECTRUM Return NaN fields for an uncomputed spectrum.
spectrum = struct('sfdr_db', NaN, 'maximum_spur_frequency_hz', NaN, ...
    'df_hz', NaN, 'frequency_hz', [], 'psd_per_hz', []);
end

function figureHandle = localPlot(details)
%LOCALPLOT Plot SFDR against stimulus frequency for all channels.
figureHandle = figure('Visible', 'off', 'Color', 'w');
channels = unique(details.channel, 'stable');
hold on;
for k = 1:numel(channels)
    mask = details.channel == channels(k);
    plot(details.stimulus_frequency_hz(mask), details.sfdr_db(mask), ...
        'o-', 'DisplayName', channels(k));
end
grid on;
xlabel('Stimulus frequency (Hz)');
ylabel('SFDR (dB)');
title('ADC dynamic performance');
legend('Location', 'best');
end

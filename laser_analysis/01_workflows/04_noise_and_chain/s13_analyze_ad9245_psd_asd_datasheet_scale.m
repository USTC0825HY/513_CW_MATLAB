function result = s13_analyze_ad9245_psd_asd_datasheet_scale(mode, outputDir)
% Recalculate AD9245 PSD/ASD with the data-sheet theoretical ADC scale.
%
% The board schematic uses VREF = 1.0 V and an AD8138 front end marked G=+1.
% AD9245 differential span is therefore 2 Vpp and the theoretical scale is:
%   L_ADC = 2 Vpp / 2^14 = 122.0703125 uV/code.
%
% Modes:
%   "full"            Load time-domain MAT files and recalculate spectra.
%   "summary_rescale" Rescale the audited 2026-07-10 band summaries when the
%                     data drive is unavailable. This mode does not create a
%                     synthetic full-resolution spectrum.

if nargin < 1 || strlength(string(mode)) == 0
    mode = "full";
end
paths = laser_test_paths();
if nargin < 2 || strlength(string(outputDir)) == 0
    outputDir = fullfile(paths.dataRoot, 'YCQD_AD_9245', ...
        'AD9245_datasheet_scale_20260712');
end

mode = lower(string(mode));
outputDir = char(outputDir);
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

cfg = makeConfig(outputDir);
writeParameterTable(cfg);
writeFpgaTransferAudit(cfg);

switch mode
    case "full"
        result = runFullAnalysis(cfg);
    case "summary_rescale"
        result = runSummaryRescale(cfg);
    otherwise
        error('Unsupported mode: %s. Use full or summary_rescale.', mode);
end

save(fullfile(outputDir, 'AD9245_datasheet_scale_result.mat'), ...
    'cfg', 'result');
fprintf('\nAD9245 theoretical-scale analysis completed.\n');
fprintf('Mode       : %s\n', mode);
fprintf('L_ADC      : %.12g V/code (%.9f uV/code)\n', ...
    cfg.L_ADC_V_per_code, cfg.L_ADC_V_per_code * 1e6);
fprintf('FPGA gain  : G=%.12g is an unverified P1000-label assumption.\n', ...
    cfg.fpgaGain);
fprintf('Output dir : %s\n', outputDir);
end


function cfg = makeConfig(outputDir)
paths = laser_test_paths();
cfg.outputDir = outputDir;
cfg.dataRoot = fullfile(paths.dataRoot, 'YCQD_AD_9245');
cfg.adcBits = 14;
cfg.adcSpanVpp = 2.0;
cfg.L_ADC_V_per_code = cfg.adcSpanVpp / 2^cfg.adcBits;
cfg.legacyL_ADC_V_per_code = 0.00160758650123;
cfg.scaleRatioNewToLegacy = cfg.L_ADC_V_per_code / ...
    cfg.legacyL_ADC_V_per_code;
cfg.fpgaGain = 1000;
cfg.fpgaGainEvidence = 'unverified_P1000_folder_label';
cfg.fpgaGainScope = [ ...
    'Conditional calculation only. The active test-firmware transfer from ' ...
    'raw AD9245 code to DA9726 code has not been verified.'];
cfg.lowWideSplitHz = 100;
cfg.requiredDurationS = 50;
cfg.showFigures = false;

cfg.channels = struct( ...
    'name', {'X1G/JG11', 'X2G/JG3', 'X3G/JG2', 'X4G/JG32'}, ...
    'stem', {'X1G_JG11', 'X2G_JG3', 'X3G_JG2', 'X4G_JG32'}, ...
    'dac', {'JG11', 'JG3', 'JG2', 'JG32'}, ...
    'K_out_V_per_code', {NaN, 9.651899e-05, 9.797634e-05, 9.802444e-05}, ...
    'sourceFile', { ...
        fullfile(cfg.dataRoot, 'X1G_JG11_P1000', ...
            '9726_20s_100k_X1G', '9726_20s_100k_X1G_1.mat'), ...
        fullfile(cfg.dataRoot, 'X2G_jg3_P1000', ...
            '9726_20s_100k_X2G_P1000', '9726_20s_100k_X2G_P1000_1.mat'), ...
        fullfile(cfg.dataRoot, 'X3G_jg2_P1000', ...
            '9726_20s_100k_X3g.mat'), ...
        fullfile(cfg.dataRoot, 'X4G_JG32_P1000', ...
            '9726_20s_100k_X4G_P1000.mat')});

cfg.bands = struct( ...
    'name', {'0.05-1Hz', 'around_1Hz_0.8-1.2Hz', '1-10Hz', ...
        '10-100Hz', '100Hz-1kHz', '1-10kHz', '10-50kHz'}, ...
    'startHz', {0.05, 0.8, 1, 10, 100, 1e3, 10e3}, ...
    'endHz', {1, 1.2, 10, 100, 1e3, 10e3, 50e3}, ...
    'method', {'low', 'low', 'low', 'low', 'wide', 'wide', 'wide'});
end


function writeParameterTable(cfg)
parameter = [ ...
    "adc_model"; "adc_bits"; "adc_span_vpp"; ...
    "theoretical_L_ADC_V_per_code"; "theoretical_L_ADC_uV_per_code"; ...
    "legacy_L_ADC_V_per_code"; "new_to_legacy_scale_ratio"; ...
    "fpga_gain_assumption"; "fpga_gain_evidence"; ...
    "fpga_gain_scope"; "dac_baseline_subtracted"; ...
    "minimum_required_duration_s"];
value = [ ...
    "AD9245"; string(cfg.adcBits); string(cfg.adcSpanVpp); ...
    string(sprintf('%.12g', cfg.L_ADC_V_per_code)); ...
    string(sprintf('%.9f', cfg.L_ADC_V_per_code * 1e6)); ...
    string(sprintf('%.12g', cfg.legacyL_ADC_V_per_code)); ...
    string(sprintf('%.12g', cfg.scaleRatioNewToLegacy)); ...
    string(cfg.fpgaGain); string(cfg.fpgaGainEvidence); ...
    string(cfg.fpgaGainScope); "false"; string(cfg.requiredDurationS)];
notes = [ ...
    "Data sheet Rev. E"; "14-bit converter"; ...
    "VREF=1.0 V, differential full-scale span"; ...
    "2/2^14"; "2/2^14 converted to uV/code"; ...
    "Invalid X2G mult_ans calibration retained only for comparison"; ...
    "ASD and integrated RMS scale by this ratio; PSD by ratio squared"; ...
    "P1000 directory label; not a verified transfer function"; ...
    "Current RTL contains channel-dependent fixed-point shifts"; ...
    "Do not use for final compliance until test-bitstream transfer is verified"; ...
    "Stage estimate only"; "Test logic requirement"];
T = table(parameter, value, notes);
writetable(T, fullfile(cfg.outputDir, ...
    'AD9245_datasheet_scale_parameters.csv'));
end


function writeFpgaTransferAudit(cfg)
channel = ["X1G/JG11"; "X2G/JG3"; "X3G/JG2"; "X4G/JG32"];
functionMapping = ["experimental chamber B"; "cavity front"; ...
    "time-frequency"; "experimental chamber A"];
rtlInstance = ["FNC_sycB"; "FNC_qq"; "FNC_sp"; "FNC_sycA"];
rtlShiftBits = [16; 0; 16; 16];
p1000Label = repmat(1000, numel(channel), 1);
hypotheticalPOnlyGain = p1000Label ./ (2 .^ rtlShiftBits);
rawAdcNode = repmat("data_FNC = adc_data - 14'h2000", numel(channel), 1);
gainEvidence = repmat("hypothesis_from_current_RTL_not_test_bitstream", ...
    numel(channel), 1);
applicability = repmat( ...
    "Test routing to DA9726 is unverified; confirm the active bitstream before using this hypothetical gain.", ...
    numel(channel), 1);
T = table(channel, functionMapping, rtlInstance, rtlShiftBits, p1000Label, ...
    hypotheticalPOnlyGain, rawAdcNode, gainEvidence, applicability, ...
    'VariableNames', {'channel', 'function_mapping', 'rtl_instance', ...
    'rtl_shift_bits', 'P1000_label', ...
    'hypothetical_P_only_gain_if_raw_parameter_is_1000', ...
    'raw_adc_node', 'gain_evidence', 'applicability'});
writetable(T, fullfile(cfg.outputDir, ...
    'AD9245_fpga_transfer_audit.csv'));
end


function result = runFullAnalysis(cfg)
summaryRows = table();
metadataRows = table();
allCurves = struct('channel', {}, 'frequencyHz', {}, 'asdNV', {}, 'psdV2Hz', {});

for i = 1:numel(cfg.channels)
    ch = cfg.channels(i);
    fprintf('\n[%d/%d] Loading %s\n', i, numel(cfg.channels), ch.sourceFile);
    if ~exist(ch.sourceFile, 'file')
        error('Source MAT does not exist: %s', ch.sourceFile);
    end

    [values, fsHz, meta] = loadPicoMat(ch.sourceFile);
    spec = makeSpectrumPair(values, fsHz);
    meta.channel = string(ch.name);
    meta.nyquist_hz = fsHz / 2;
    meta.low_resolution_hz = spec.lowResolutionHz;
    meta.wide_resolution_hz = spec.wideResolutionHz;
    meta.meets_50s_requirement = meta.duration_s >= cfg.requiredDurationS;
    metadataRows = [metadataRows; struct2table(meta, 'AsArray', true)]; %#ok<AGROW>

    plotOutputSpectrum(ch, spec, meta, cfg);
    writeOutputSpectrumCsv(ch, spec, cfg);

    if ~isfinite(ch.K_out_V_per_code)
        fprintf('Skipping ADC input-equivalent conversion for %s: missing %s K_out.\n', ...
            ch.name, ch.dac);
        continue;
    end

    scale = cfg.L_ADC_V_per_code / ...
        (ch.K_out_V_per_code * cfg.fpgaGain);
    [frequencyHz, psdInput] = combineSpectrum(spec, cfg.lowWideSplitHz);
    psdInput = psdInput * scale^2;
    asdInput = sqrt(max(psdInput, 0));

    writeInputSpectrumCsv(ch, frequencyHz, psdInput, asdInput, scale, cfg);
    plotInputSpectrum(ch, frequencyHz, psdInput, asdInput, meta, scale, cfg);
    summaryRows = [summaryRows; makeBandSummary(ch, spec, scale, cfg)]; %#ok<AGROW>

    curve.channel = string(ch.name);
    curve.frequencyHz = frequencyHz;
    curve.asdNV = asdInput * 1e9;
    curve.psdV2Hz = psdInput;
    allCurves(end + 1) = curve; %#ok<AGROW>
end

writetable(metadataRows, fullfile(cfg.outputDir, ...
    'AD9245_datasheet_scale_source_metadata.csv'));
writetable(summaryRows, fullfile(cfg.outputDir, ...
    'AD9245_datasheet_scale_band_summary.csv'));
plotCombinedCurves(allCurves, cfg);

result.mode = "full";
result.bandSummary = summaryRows;
result.metadata = metadataRows;
result.notes = [ ...
    "Full time-domain recalculation; DAC baseline not subtracted. " ...
    "ADC input-equivalent conversion is conditional on unverified G=1000."];
end


function result = runSummaryRescale(cfg)
% Audited values from the 2026-07-10 report. These are medians of the prior
% input-equivalent ASD bands calculated with legacyL_ADC_V_per_code.
channels = ["X2G/JG3"; "X3G/JG2"; "X4G/JG32"];
bandNames = ["around_1Hz_0.8-1.2Hz", "100Hz-1kHz", ...
    "1-10kHz", "10-50kHz"];
legacyAsdNV = [ ...
    53.46, 14.82, 14.51, 14.47; ...
    44.98, 14.77, 14.58, 14.59; ...
    19.08, 13.02, 12.48, 12.45];
legacyNearest1HzNV = [127.49; 79.50; 8.37];

newAsdNV = legacyAsdNV * cfg.scaleRatioNewToLegacy;
newPsdV2Hz = (newAsdNV * 1e-9).^2;
newNearest1HzNV = legacyNearest1HzNV * cfg.scaleRatioNewToLegacy;
nearestTransferStatus = repmat( ...
    "conditional_on_unverified_G_equals_1000", numel(channels), 1);

rows = table();
for i = 1:numel(channels)
    for j = 1:numel(bandNames)
        row = table(channels(i), bandNames(j), legacyAsdNV(i, j), ...
            newAsdNV(i, j), newPsdV2Hz(i, j), ...
            cfg.scaleRatioNewToLegacy, ...
            "conditional_on_unverified_G_equals_1000", ...
            "rescaled_from_20260710_audited_band_summary", ...
            'VariableNames', {'channel', 'band', ...
            'legacy_asd_nV_per_sqrtHz', ...
            'theoretical_asd_nV_per_sqrtHz', ...
            'theoretical_psd_V2_per_Hz', 'scale_ratio', ...
            'fpga_transfer_status', 'data_basis'});
        rows = [rows; row]; %#ok<AGROW>
    end
end
writetable(rows, fullfile(cfg.outputDir, ...
    'AD9245_datasheet_scale_band_summary_rescaled.csv'));

nearestTable = table(channels, legacyNearest1HzNV, newNearest1HzNV, ...
    nearestTransferStatus, ...
    'VariableNames', {'channel', 'legacy_nearest_1Hz_asd_nV_per_sqrtHz', ...
    'theoretical_nearest_1Hz_asd_nV_per_sqrtHz', ...
    'fpga_transfer_status'});
writetable(nearestTable, fullfile(cfg.outputDir, ...
    'AD9245_datasheet_scale_nearest_1Hz_rescaled.csv'));

plotSummaryAsd(channels, bandNames, newAsdNV, cfg);
plotSummaryPsd(channels, bandNames, newPsdV2Hz, cfg);
plotLegacyComparison(channels, legacyAsdNV(:, 1), ...
    newAsdNV(:, 1), legacyNearest1HzNV, newNearest1HzNV, cfg);

result.mode = "summary_rescale";
result.bandSummary = rows;
result.nearest1Hz = nearestTable;
result.notes = [ ...
    "Constant rescale of audited 2026-07-10 statistics. " ...
    "No synthetic full-resolution spectrum was generated. " ...
    "DAC baseline remains unsubtracted and records are about 20 s. " ...
    "Input-equivalent values are conditional on unverified G=1000."];
end


function [values, fsHz, meta] = loadPicoMat(path)
s = load(path, 'A', 'Tinterval');
if ~isfield(s, 'A')
    error('Variable A is missing from %s.', path);
end
values = double(s.A(:));
values = values(isfinite(values));
if isfield(s, 'Tinterval')
    dt = double(s.Tinterval(1));
else
    dt = 1 / 100e3;
end
fsHz = 1 / dt;
meta.source_file = string(path);
meta.sample_count = numel(values);
meta.sample_rate_hz = fsHz;
meta.duration_s = numel(values) / fsHz;
meta.mean_v = mean(values);
meta.std_v = std(values);
meta.min_v = min(values);
meta.max_v = max(values);
end


function spec = makeSpectrumPair(values, fsHz)
y = values - mean(values);
n = numel(y);
[psdLow, fLow] = periodogram(y, hann(n, 'periodic'), n, fsHz, 'onesided');
nperseg = max(8, floor(n / 100));
noverlap = floor(nperseg / 2);
[psdWide, fWide] = pwelch(y, hann(nperseg, 'periodic'), ...
    noverlap, nperseg, fsHz, 'onesided');
spec.fLow = fLow;
spec.psdLow = psdLow;
spec.fWide = fWide;
spec.psdWide = psdWide;
spec.lowResolutionHz = fLow(2) - fLow(1);
spec.wideResolutionHz = fWide(2) - fWide(1);
spec.wideNperseg = nperseg;
spec.wideNoverlap = noverlap;
end


function [frequencyHz, psd] = combineSpectrum(spec, splitHz)
lowMask = spec.fLow > 0 & spec.fLow <= splitHz;
wideMask = spec.fWide > splitHz;
frequencyHz = [spec.fLow(lowMask); spec.fWide(wideMask)];
psd = [spec.psdLow(lowMask); spec.psdWide(wideMask)];
end


function rows = makeBandSummary(ch, spec, scale, cfg)
rows = table();
for i = 1:numel(cfg.bands)
    band = cfg.bands(i);
    if strcmp(band.method, 'low')
        f = spec.fLow;
        psd = spec.psdLow * scale^2;
    else
        f = spec.fWide;
        psd = spec.psdWide * scale^2;
    end
    mask = f >= band.startHz & f <= band.endHz;
    if ~any(mask)
        continue;
    end
    fb = f(mask);
    pb = psd(mask);
    asd = sqrt(max(pb, 0));
    if numel(fb) > 1
        integratedRms = sqrt(trapz(fb, pb));
    else
        integratedRms = NaN;
    end
    row = table(string(ch.name), string(ch.dac), string(band.name), ...
        band.startHz, band.endHz, string(band.method), sum(mask), ...
        ch.K_out_V_per_code, cfg.L_ADC_V_per_code, cfg.fpgaGain, scale, ...
        median(asd), mean(asd), max(asd), median(pb), integratedRms, ...
        "conditional_theoretical_scale_no_DAC_baseline_G_unverified", ...
        'VariableNames', {'channel', 'dac_interface', 'band', ...
        'start_hz', 'end_hz', 'spectrum_method', 'point_count', ...
        'K_out_V_per_code', 'L_ADC_V_per_code', 'G', ...
        'scale_ADC_input_per_DAC_output', ...
        'asd_median_V_per_sqrtHz', 'asd_mean_V_per_sqrtHz', ...
        'asd_max_V_per_sqrtHz', 'psd_median_V2_per_Hz', ...
        'integrated_rms_V', 'status'});
    rows = [rows; row]; %#ok<AGROW>
end
end


function writeOutputSpectrumCsv(ch, spec, cfg)
low = table(spec.fLow, spec.psdLow, sqrt(max(spec.psdLow, 0)), ...
    'VariableNames', {'frequency_hz', 'psd_V2_per_Hz', 'asd_V_per_sqrtHz'});
wide = table(spec.fWide, spec.psdWide, sqrt(max(spec.psdWide, 0)), ...
    'VariableNames', {'frequency_hz', 'psd_V2_per_Hz', 'asd_V_per_sqrtHz'});
writetable(low, fullfile(cfg.outputDir, ...
    [ch.stem '_DAC_output_low_frequency_spectrum.csv']));
writetable(wide, fullfile(cfg.outputDir, ...
    [ch.stem '_DAC_output_wideband_spectrum.csv']));
end


function writeInputSpectrumCsv(ch, f, psd, asd, scale, cfg)
T = table(f, psd, asd, repmat(scale, numel(f), 1), ...
    'VariableNames', {'frequency_hz', 'psd_V2_per_Hz', ...
    'asd_V_per_sqrtHz', 'scale_ADC_input_per_DAC_output'});
writetable(T, fullfile(cfg.outputDir, ...
    [ch.stem '_ADC_input_theoretical_scale_spectrum.csv']));
end


function plotOutputSpectrum(ch, spec, meta, cfg)
[f, psd] = combineSpectrum(spec, cfg.lowWideSplitHz);
asd = sqrt(max(psd, 0));
fig = newFigure(cfg);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; loglog(f, asd * 1e9, 'LineWidth', 0.9); grid on;
xlabel('Frequency (Hz)'); ylabel('ASD (nV/sqrt(Hz))'); title('DAC output ASD');
nexttile; loglog(f, psd, 'LineWidth', 0.9); grid on;
xlabel('Frequency (Hz)'); ylabel('PSD (V^2/Hz)'); title('DAC output PSD');
sgtitle(sprintf('%s measured chain output, fs=%.3f kS/s, T=%.2f s', ...
    ch.name, meta.sample_rate_hz / 1e3, meta.duration_s));
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    [ch.stem '_DAC_output_ASD_PSD']), cfg);
end


function plotInputSpectrum(ch, f, psd, asd, meta, scale, cfg)
fig = newFigure(cfg);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; loglog(f, asd * 1e9, 'LineWidth', 0.95); grid on; hold on;
xline(1, '--'); yline(10e3, '--r', '10 uV/sqrt(Hz)');
xlabel('Frequency (Hz)'); ylabel('ADC input ASD (nV/sqrt(Hz))');
title('Input-equivalent ASD');
nexttile; loglog(f, psd, 'LineWidth', 0.95); grid on; hold on;
xline(1, '--'); yline((10e-6)^2, '--r', '(10 uV/sqrt(Hz))^2');
xlabel('Frequency (Hz)'); ylabel('ADC input PSD (V^2/Hz)');
title('Input-equivalent PSD');
sgtitle(sprintf(['%s, AD9245 data-sheet scale, scale=%.6g V/V, ' ...
    'T=%.2f s, G=1000 unverified, DAC baseline not subtracted'], ...
    ch.name, scale, meta.duration_s));
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    [ch.stem '_ADC_input_theoretical_scale_ASD_PSD']), cfg);
end


function plotCombinedCurves(curves, cfg)
if isempty(curves)
    return;
end
fig = newFigure(cfg);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; hold on;
for i = 1:numel(curves)
    loglog(curves(i).frequencyHz, curves(i).asdNV, ...
        'LineWidth', 0.9, 'DisplayName', curves(i).channel);
end
grid on; xline(1, '--'); yline(10e3, '--r', '10 uV/sqrt(Hz)');
xlabel('Frequency (Hz)'); ylabel('ADC input ASD (nV/sqrt(Hz))');
title('AD9245 theoretical-scale ASD'); legend('Location', 'best');
nexttile; hold on;
for i = 1:numel(curves)
    loglog(curves(i).frequencyHz, curves(i).psdV2Hz, ...
        'LineWidth', 0.9, 'DisplayName', curves(i).channel);
end
grid on; xline(1, '--'); yline((10e-6)^2, '--r');
xlabel('Frequency (Hz)'); ylabel('ADC input PSD (V^2/Hz)');
title('AD9245 theoretical-scale PSD'); legend('Location', 'best');
sgtitle(['AD9245 conditional input-equivalent spectra, ' ...
    'G=1000 unverified, DAC baseline not subtracted']);
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    'AD9245_all_channels_theoretical_scale_ASD_PSD'), cfg);
end


function plotSummaryAsd(channels, bands, values, cfg)
fig = newFigure(cfg);
b = bar(values.');
set(gca, 'YScale', 'log'); grid on;
xticks(1:numel(bands));
xticklabels(["0.8-1.2 Hz", "100 Hz-1 kHz", "1-10 kHz", "10-50 kHz"]);
applyLogYMargin(values);
ylabel('ASD median (nV/sqrt(Hz))');
title('AD9245 theoretical-scale ASD band medians');
legend(b, channels, 'Location', 'best');
subtitle(['Conditional on unverified G=1000; rescaled from audited ' ...
    '2026-07-10 summary; no DAC baseline subtraction']);
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    'AD9245_theoretical_scale_ASD_band_summary'), cfg);
end


function plotSummaryPsd(channels, bands, values, cfg)
fig = newFigure(cfg);
b = bar(values.');
set(gca, 'YScale', 'log'); grid on;
xticks(1:numel(bands));
xticklabels(["0.8-1.2 Hz", "100 Hz-1 kHz", "1-10 kHz", "10-50 kHz"]);
applyLogYMargin(values);
ylabel('PSD median (V^2/Hz)');
title('AD9245 theoretical-scale PSD band medians');
legend(b, channels, 'Location', 'best');
subtitle(['PSD uses scale ratio squared; conditional on unverified G=1000']);
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    'AD9245_theoretical_scale_PSD_band_summary'), cfg);
end


function plotLegacyComparison(channels, legacyMedian, newMedian, ...
    legacyNearest, newNearest, cfg)
fig = newFigure(cfg);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
bar([legacyMedian, newMedian]); set(gca, 'YScale', 'log'); grid on;
applyLogYMargin([legacyMedian; newMedian]);
xticks(1:numel(channels)); xticklabels(channels);
ylabel('ASD (nV/sqrt(Hz))');
title('0.8-1.2 Hz median (G=1000 unverified)');
legend('Legacy X2G fitted scale', 'AD9245 theoretical scale', ...
    'Location', 'best');
nexttile;
bar([legacyNearest, newNearest]); set(gca, 'YScale', 'log'); grid on;
applyLogYMargin([legacyNearest; newNearest]);
xticks(1:numel(channels)); xticklabels(channels);
ylabel('ASD (nV/sqrt(Hz))');
title('Nearest available 1 Hz bin (G=1000 unverified)');
legend('Legacy X2G fitted scale', 'AD9245 theoretical scale', ...
    'Location', 'best');
sgtitle(sprintf('Scale correction: ASD x %.9f, PSD x %.9f', ...
    cfg.scaleRatioNewToLegacy, cfg.scaleRatioNewToLegacy^2));
saveFigurePair(fig, fullfile(cfg.outputDir, ...
    'AD9245_legacy_vs_theoretical_scale_comparison'), cfg);
end


function fig = newFigure(cfg)
if cfg.showFigures
    visible = 'on';
else
    visible = 'off';
end
fig = figure('Visible', visible, 'Color', 'w', ...
    'Position', [100, 100, 1250, 560]);
end


function applyLogYMargin(values)
positiveValues = values(isfinite(values) & values > 0);
if isempty(positiveValues)
    return;
end
low = min(positiveValues(:));
high = max(positiveValues(:));
if low == high
    low = low / 1.5;
    high = high * 1.5;
else
    low = 10^(log10(low) - 0.12);
    high = 10^(log10(high) + 0.12);
end
ylim([low, high]);
end


function saveFigurePair(fig, stem, ~)
exportgraphics(fig, [stem '.png'], 'Resolution', 220, ...
    'BackgroundColor', 'white');
savefig(fig, [stem '.fig']);
close(fig);
end

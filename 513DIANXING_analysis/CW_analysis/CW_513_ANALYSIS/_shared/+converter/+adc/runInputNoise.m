function results = runInputNoise(config, dataFolder, selectedFiles, outputFolder, calibration)
%RUNINPUTNOISE Analyze direct ADC code noise and export an audited bundle.

required = {'deviceId', 'analysisId', 'version', 'adcBits', 'adcDataColumn', ...
    'adcCodeFormat', 'sampleRate', 'noiseBandHz', 'noiseLimitNvPerSqrtHz', ...
    'welchSegmentCount', 'welchOverlapRatio', 'welchNfft'};
converter.runtime.validateConfig(config, required);

files = normalizeFiles(selectedFiles);
if isempty(files)
    error('converter:adc:NoInputFiles', '未选择 ILA CSV 文件。');
end
for k = 1:numel(files)
    if ~isfile(files{k})
        error('converter:adc:MissingInput', '找不到 ILA CSV：%s', files{k});
    end
end

channels = converter.io.resolveAdcChannels(config, dataFolder, files, false);
for k = 1:numel(files)
    resolveCalibration(calibration, char(channels(k)));
end
if numel(unique(channels)) ~= numel(channels)
    error('converter:adc:DuplicateChannels', 'ILA噪声每接口一次一份，避免通道命名结果覆盖。');
end
config.inputChannels = cellstr(channels);
runContext = converter.runtime.createRun(config, dataFolder, files, outputFolder);
try
    writeAnalysisParameters(runContext.folder, config);
    writeCalibrationProvenance(runContext.folder, calibration, config.referencePlane);
    writeExcludedInputNote(runContext.folder);

    summary = table();
    channelResults = cell(numel(files),1);
    for k = 1:numel(files)
        channel = char(channels(k));
        cal = resolveCalibration(calibration, channel);
        one = analyzeOne(files{k}, channel, cal, config, runContext.folder);
        channelResults{k} = one;
        summary = [summary; one.summary]; %#ok<AGROW>
    end

    deviceStem = safeStem(config.deviceId);
    converter.report.writeTable(summary, fullfile(runContext.folder, ...
        [deviceStem '_input_noise_summary.csv']));
    writeFullRecordAsdSummary(runContext.folder, summary, deviceStem);
    writeReadme(runContext.folder, config, files);
    save(fullfile(runContext.folder, [deviceStem '_input_noise_result.mat']), ...
        'summary','channelResults','config','calibration','-v7.3');
    converter.runtime.finishRun(runContext, true, ...
        sprintf('%s direct ILA input-equivalent noise completed', config.deviceId));
    results = struct('runFolder', runContext.folder, 'summary', summary, ...
        'status', 'success');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end

function files = normalizeFiles(selectedFiles)
if ischar(selectedFiles) || isstring(selectedFiles)
    files = cellstr(selectedFiles);
else
    files = selectedFiles;
end
files = files(:);
end

function cal = resolveCalibration(calibration, channel)
match = find(strcmp({calibration.channel}, channel), 1);
if isempty(match)
    error('converter:adc:MissingCalibration', '缺少 %s 的刻度行。', channel);
end
cal = calibration(match);
end

function result = analyzeOne(filePath, channel, cal, config, runFolder)
readConfig = config;
[signedCode, decoding] = converter.io.readAdcCsv(filePath, readConfig);
converter.runtime.recordInputDecoding(runFolder, decoding);
signedCode = signedCode(:);
if numel(signedCode) < 16
    error('converter:adc:TooFewSamples', '有效码流点数不足：%s', filePath);
end

codeNoise = signedCode - mean(signedCode);
inputNoiseV = codeNoise * cal.slopeVPerCode;
n = numel(inputNoiseV);
validStats = readValidStatistics(filePath, config, n);
if config.welchSegmentCount == 1 && n ~= config.welchNfft
    error('converter:adc:FixedNoiseRecordLength', ...
        ['固定整段噪声设置要求 %d 个有效点，实际 %d 点。' ...
        '请核对采集长度；本入口不自动补零、折叠或更改 NFFT。'], config.welchNfft, n);
end
windowLength = max(8, floor(n / config.welchSegmentCount));
overlapSamples = min(floor(windowLength * config.welchOverlapRatio), windowLength - 1);
welchWindow = hanning(windowLength);
[psdV2PerHz, frequencyHz] = pwelch(inputNoiseV, welchWindow, ...
    overlapSamples, config.welchNfft, config.sampleRate);
asdNvPerSqrtHz = sqrt(psdV2PerHz) * 1e9;

fullWindow = hanning(n);
[fullPsd, fullFrequency] = periodogram(inputNoiseV, fullWindow, n, config.sampleRate, 'psd');
fullAsd = sqrt(fullPsd) * 1e9;
fullRecordResolutionHz = fullFrequency(2) - fullFrequency(1);
band = config.noiseBandHz;
bandMask = frequencyHz >= band(1) & frequencyHz <= band(2);
spurMask = fullFrequency >= band(1) & fullFrequency <= band(2);
if ~any(bandMask) || ~any(spurMask)
    error('converter:adc:BandUnavailable', ...
        '%s 没有覆盖配置频带 %.12g～%.12g Hz。', filePath, band(1), band(2));
end

bandAsd = asdNvPerSqrtHz(bandMask);
bandFreq = frequencyHz(bandMask);
[welchMax, maxIndex] = max(bandAsd);
[spurMax, spurIndex] = max(fullAsd(spurMask));
spurFreqs = fullFrequency(spurMask);
bandMedian = median(bandAsd);
bandMean = mean(bandAsd);
bandP95 = prctile(bandAsd, 95);
limitDefined = isfinite(config.noiseLimitNvPerSqrtHz) && ...
    config.noiseLimitNvPerSqrtHz > 0;
if limitDefined
    belowPct = mean(bandAsd <= config.noiseLimitNvPerSqrtHz) * 100;
else
    belowPct = NaN;
end

% Use a conservative band rule: the floor's 95th percentile and the
% independent full-record spur screen must both meet the limit.
if ~localFormalEnabled(config) || ~limitDefined
    formalStatus = '暂不能判定';
elseif bandP95 <= config.noiseLimitNvPerSqrtHz && spurMax <= config.noiseLimitNvPerSqrtHz
    formalStatus = '满足';
elseif bandP95 > config.noiseLimitNvPerSqrtHz || spurMax > config.noiseLimitNvPerSqrtHz
    formalStatus = '不满足';
else
    formalStatus = '暂不能判定';
end

safeName = safeStem(channel);
sourceSha256 = converter.runtime.sha256File(filePath);
% Only the ASD curve is archived; the PSD column and the PSD figure were
% dropped to keep result folders lightweight.
fullSpectrum = table(fullFrequency, fullAsd, ...
    'VariableNames', {'FrequencyHz', 'AsdNvPerSqrtHz'});
converter.report.writeTable(fullSpectrum, fullfile(runFolder, ...
    [safeName '_full_ASD.csv']));

plotConfig = localPlotConfig(channel, config, true);
converter.report.plotSpectrum(frequencyHz, asdNvPerSqrtHz, ...
    fullfile(runFolder, [safeName '_input_equiv_ASD']), plotConfig);
fullRecordPlotConfig = localPlotConfig(channel, config, true);
fullRecordPlotConfig.titleText = sprintf('%s | ADC input-equivalent ASD (full-record periodogram)', ...
    channel);
fullRecordPlotConfig.annotationText = sprintf('Full-record periodogram, delta f = %.6g Hz', ...
    fullRecordResolutionHz);
fullRecordPlotConfig.checkFrequencyHz = spurFreqs(spurIndex);
fullRecordPlotConfig.checkValue = spurMax;
fullRecordPlotConfig.checkValueLabel = sprintf( ...
    'Configured-band maximum: %.2f nV/sqrtHz @ %.6g Hz', ...
    spurMax, spurFreqs(spurIndex));
converter.report.plotSpectrum(fullFrequency, fullAsd, ...
    fullfile(runFolder, [safeName '_input_equiv_ASD_full_record']), fullRecordPlotConfig);
plotCodePreview(signedCode, inputNoiseV, channel, config, ...
    fullfile(runFolder, [safeName '_code_preview']));

durationS = n / config.sampleRate;
summary = table({channel}, {filePath}, {sourceSha256}, n, config.sampleRate, durationS, ...
    validStats.validPulseCount, validStats.effectiveUpdateRateHz, ...
    validStats.includesHeldSamples, ...
    config.sampleRate / 2, windowLength, overlapSamples, config.welchNfft, ...
    config.sampleRate / config.welchNfft, fullRecordResolutionHz, ...
    cal.slopeVPerCode, cal.interceptV, cal.fitR2, band(1), band(2), ...
    sum(bandMask), bandMedian, bandMean, bandP95, welchMax, bandFreq(maxIndex), ...
    belowPct, spurMax, spurFreqs(spurIndex), config.noiseLimitNvPerSqrtHz, ...
    {formalStatus}, {statusNote(config)}, ...
    'VariableNames', {'Channel', 'InputFile', 'SourceSHA256', 'SampleCount', 'SampleRateHz', ...
    'DurationS', 'ValidPulseCount', 'EffectiveUpdateRateHz', ...
    'IncludesHeldSamples', 'NyquistHz', 'WelchWindowLength', 'WelchOverlapSamples', ...
    'WelchNfft', 'WelchResolutionHz', 'FullRecordResolutionHz', ...
    'CalibrationSlopeVPerCode', 'CalibrationInterceptV', 'CalibrationFitR2', ...
    'BandStartHz', 'BandEndHz', 'BandBinCount', 'BandAsdMedianNvPerSqrtHz', ...
    'BandAsdMeanNvPerSqrtHz', 'BandAsdP95NvPerSqrtHz', ...
    'BandAsdMaxNvPerSqrtHz', 'BandAsdMaxFrequencyHz', ...
    'BandBinsAtOrBelowLimitPercent', 'FullRecordSpurMaxNvPerSqrtHz', ...
    'FullRecordSpurMaxFrequencyHz', 'AsdLimitNvPerSqrtHz', ...
    'FormalStatus', 'StatusNote'});
result.summary = summary;
result.spectrum = table(frequencyHz, psdV2PerHz, asdNvPerSqrtHz, ...
    'VariableNames',{'FrequencyHz','PsdV2PerHz','AsdNvPerSqrtHz'});
result.fullRecordSpectrum = table(fullFrequency, fullPsd, fullAsd, ...
    'VariableNames',{'FrequencyHz','PsdV2PerHz','AsdNvPerSqrtHz'});
converter.report.writeTable(result.spectrum,fullfile(runFolder,[safeName '_PSD_ASD.csv']));
end

function writeFullRecordAsdSummary(runFolder, summary, deviceStem)
% Write the narrow-spur screening results separately so they cannot be
% confused with the lower-resolution Welch noise-floor statistics.
columns = {'Channel', 'FullRecordResolutionHz', 'BandStartHz', 'BandEndHz', ...
    'FullRecordSpurMaxNvPerSqrtHz', 'FullRecordSpurMaxFrequencyHz', ...
    'AsdLimitNvPerSqrtHz', 'FormalStatus'};
converter.report.writeTable(summary(:, columns), fullfile(runFolder, ...
    [deviceStem '_full_record_ASD_summary.csv']));
end

function textValue = statusNote(config)
textValue = sprintf(['%.12g~%.12g Hz: 95th percentile and full-record spur screen; ' ...
    'reference plane=%s; termination=%s'], config.noiseBandHz(1), ...
    config.noiseBandHz(2), config.referencePlane, config.inputTermination);
end

function enabled = localFormalEnabled(config)
enabled = ~isfield(config, 'formalEnabled') || logical(config.formalEnabled);
end

function stats = readValidStatistics(filePath, config, sampleCount)
stats = struct('validPulseCount', NaN, 'effectiveUpdateRateHz', NaN, ...
    'includesHeldSamples', isfield(config, 'samplesIncludeHold') && ...
        logical(config.samplesIncludeHold));
if ~isfield(config, 'validDataColumn') || isempty(config.validDataColumn)
    return;
end
numericData = readmatrix(filePath);
column = config.validDataColumn;
if column < 1 || column > size(numericData, 2)
    error('converter:adc:ValidColumnOutOfRange', ...
        'adc_data_vld 列 %d 超出CSV范围：%s', column, filePath);
end
valid = numericData(:, column);
valid = valid(isfinite(valid));
if isempty(valid)
    error('converter:adc:NoValidColumnData', ...
        'adc_data_vld 列没有有限数值：%s', filePath);
end
stats.validPulseCount = nnz(valid ~= 0);
stats.effectiveUpdateRateHz = stats.validPulseCount / ...
    (sampleCount / config.sampleRate);
end

function plotConfig = localPlotConfig(channel, config, isAsd)
plotConfig = struct();
% Match the DA9726 report figure appearance while keeping the AD2208
% frequency-band annotation and band-limited requirement line.
plotConfig.styleProfile = 'da9726_legacy_visual_adapter';
plotConfig.showLegend = false;
plotConfig.titleText = sprintf('%s | %s', channel, ...
    ternary(isAsd, 'ADC input-equivalent ASD', ...
    'ADC input-equivalent PSD'));
plotConfig.yLabel = ternary(isAsd, ...
    'ADC input-equivalent ASD (nV/sqrtHz)', ...
    'ADC input-equivalent PSD (V^2/Hz)');
plotConfig.lineLabel = ternary(isAsd, 'ASD', 'PSD');
plotConfig.limitValue = ternary(isAsd, config.noiseLimitNvPerSqrtHz, ...
    (config.noiseLimitNvPerSqrtHz * 1e-9)^2);
% Draw any configured indicator across the full plotted frequency axis;
% the analysis band itself is shown by the focus guides.
plotConfig.limitX = [];
plotConfig.focusBandHz = config.noiseBandHz;
% Do not print the threshold value in the figure. The requirement remains
% in the audited summary CSV and report text; the plot carries only the
% full-width red line and the two black frequency labels.
plotConfig.limitLabel = '';
plotConfig.showLimitLabel = false;
plotConfig.focusText = '';
plotConfig.annotationText = sprintf('Welch Δf = %.6g Hz', ...
    config.sampleRate / config.welchNfft);
plotConfig.lineWidth = 1.1;
plotConfig.resolutionDpi = 180;
end

function value = ternary(condition, trueValue, falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function plotCodePreview(signedCode, inputNoiseV, channel, config, outputStem)
previewN = min(numel(signedCode), 5000);
idx = (1:previewN).';
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [80 80 1280 780]);
subplot(2, 1, 1);
plot(idx, signedCode(idx), 'Color', [0.00 0.32 0.75], 'LineWidth', 0.8);
grid on; xlabel('Sample index'); ylabel('Signed code');
title([channel ' signed code preview'], 'Interpreter', 'none');
subplot(2, 1, 2);
plot(idx, inputNoiseV(idx) * 1e6, 'Color', [0.00 0.32 0.75], 'LineWidth', 0.8);
grid on; xlabel('Sample index'); ylabel('Input noise (uV)');
title(sprintf('%s input-equivalent noise preview, fs=%.0f MSPS', ...
    channel, config.sampleRate / 1e6), 'Interpreter', 'none');
converter.report.saveFigure(figureHandle, outputStem, 150);
close(figureHandle);
end

function stem = safeStem(value)
stem = regexprep(char(value), '[<>:"/\\|?*\s]+', '_');
stem = regexprep(stem, '_+', '_');
end

function writeAnalysisParameters(runFolder, config)
fileId = fopen(fullfile(runFolder, 'analysis_parameters.csv'), 'w');
if fileId < 0, error('converter:runtime:CannotWriteParameters', '无法写入分析参数。'); end
cleanupObject = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'parameter,value\n');
fprintf(fileId, 'analysis_id,%s\n', config.analysisId);
fprintf(fileId, 'version,%s\n', config.version);
fprintf(fileId, 'sample_rate_hz,%.12g\n', config.sampleRate);
fprintf(fileId, 'adc_bits,%d\n', config.adcBits);
fprintf(fileId, 'adc_data_column,%d\n', config.adcDataColumn);
fprintf(fileId, 'adc_code_format,%s\n', config.adcCodeFormat);
fprintf(fileId, 'fixed_sample_count,%d\n', config.welchNfft);
fprintf(fileId, 'fixed_duration_s,%.12g\n', config.welchNfft / config.sampleRate);
fprintf(fileId, 'nyquist_hz,%.12g\n', config.sampleRate / 2);
fprintf(fileId, 'welch_window,Hann/hanning\n');
fprintf(fileId, 'welch_segment_count,%d\n', config.welchSegmentCount);
fprintf(fileId, 'welch_overlap_ratio,%.12g\n', config.welchOverlapRatio);
fprintf(fileId, 'welch_nfft,%d\n', config.welchNfft);
fprintf(fileId, 'welch_resolution_hz,%.12g\n', config.sampleRate / config.welchNfft);
fprintf(fileId, 'full_record_resolution_hz,%.12g\n', config.sampleRate / config.welchNfft);
fprintf(fileId, 'analysis_band_hz,[%.12g %.12g]\n', ...
    config.noiseBandHz(1), config.noiseBandHz(2));
fprintf(fileId, 'asd_limit_nv_per_sqrt_hz,%.12g\n', config.noiseLimitNvPerSqrtHz);
fprintf(fileId, 'input_termination,%s\n', config.inputTermination);
fprintf(fileId, 'reference_plane,%s\n', config.referencePlane);
fprintf(fileId, 'formal_condition_source,%s\n', config.formalConditionSource);
if isfield(config, 'calibrationSource')
    fprintf(fileId, 'calibration_source,%s\n', config.calibrationSource);
elseif isfield(config, 'noiseCalibrationSource')
    fprintf(fileId, 'calibration_source,%s\n', config.noiseCalibrationSource);
end
if isfield(config, 'samplesIncludeHold')
    fprintf(fileId, 'includes_held_samples,%d\n', logical(config.samplesIncludeHold));
end
fprintf(fileId, 'plot_style,da9726_legacy_visual_adapter\n');
fprintf(fileId, 'plot_style_reference,shared MATLAB renderer; visual adapter only\n');
end

function writeCalibrationProvenance(runFolder, calibration, referencePlane)
channels = {calibration.channel}.';
slope = [calibration.slopeVPerCode].';
intercept = [calibration.interceptV].';
fitR2 = [calibration.fitR2].';
freq = [calibration.calibrationFrequencyHz].';
reference = repmat({referencePlane}, numel(calibration), 1);
t = table(channels, freq, slope, intercept, fitR2, reference, ...
    'VariableNames', {'Channel', 'CalibrationFrequencyHz', ...
    'SlopeVPerCode', 'InterceptV', 'FitR2', 'ReferencePlane'});
converter.report.writeTable(t, fullfile(runFolder, 'calibration_provenance.csv'));
if isfield(calibration,'sourceDocument')
    converter.report.writeTable(struct2table(calibration), ...
        fullfile(runFolder,'report_calibration_rows.csv'));
end
end

function writeExcludedInputNote(runFolder)
fileId = fopen(fullfile(runFolder, 'excluded_inputs.csv'), 'w');
if fileId < 0, error('converter:runtime:CannotWriteExclusions', '无法写入排除记录。'); end
cleanupObject = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'InputFile,Reason\n');
% No unselected file is declared excluded or processed by this run.
end

function writeReadme(runFolder, config, files)
fileId = fopen(fullfile(runFolder, 'README.md'), 'w');
if fileId < 0, error('converter:runtime:CannotWriteReadme', '无法写入结果说明。'); end
cleanupObject = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, '# %s direct ILA input-equivalent noise\n\n', config.deviceId);
fprintf(fileId, 'Processed files:\n');
for k = 1:numel(files), fprintf(fileId, '- `%s`\n', files{k}); end
fprintf(fileId, '\nReference plane: %s\n', config.referencePlane);
fprintf(fileId, 'Selection: only the explicitly selected files above were processed.\n');
fprintf(fileId, 'Configured segments=%d, overlap=%.12g, NFFT=%d, fs=%.12g Hz.\n', ...
    config.welchSegmentCount, config.welchOverlapRatio, config.welchNfft, config.sampleRate);
if config.welchSegmentCount == 1
    fprintf(fileId, ['Single full-record Hann estimate; no segment averaging. ' ...
        'Effective record length must equal fixed NFFT. Bin spacing=%.12g Hz.\n'], ...
        config.sampleRate/config.welchNfft);
end
fprintf(fileId, 'Termination: %s\n', config.inputTermination);
fprintf(fileId, 'Analysis band: %.12g-%.12g Hz.\n', ...
    config.noiseBandHz(1), config.noiseBandHz(2));
if isfinite(config.noiseLimitNvPerSqrtHz)
    fprintf(fileId, 'ASD limit: <=%.12g nV/sqrtHz.\n', config.noiseLimitNvPerSqrtHz);
else
    fprintf(fileId, 'No approved ASD limit is configured; status remains uncertain.\n');
end
if isfield(config, 'samplesIncludeHold') && config.samplesIncludeHold
    fprintf(fileId, ['All ILA rows are analyzed at the capture clock, including held codes; ' ...
        'adc_data_vld is reported only as update-rate evidence.\n']);
end
fprintf(fileId, ['Each channel exports a Welch ASD figure (*_input_equiv_ASD.png; ' ...
    'noise-floor view) and a full-record periodogram ASD figure ' ...
    '(*_input_equiv_ASD_full_record.png; narrow-spur view).\n']);
fprintf(fileId, ['%s_full_record_ASD_summary.csv records the configured-band ' ...
    'maximum and its frequency; do not substitute it for the Welch floor.\n'], ...
    safeStem(config.deviceId));
fprintf(fileId, 'Plot style: da9726_legacy_visual_adapter in the current shared MATLAB renderer; this is visual compatibility only, not the legacy numerical algorithm.\n');
end

function result = runNoise(config)
%RUNNOISE Analyze DAC output ASD and optional integrated noise.
converter.runtime.validateConfig(config, ...
    {'deviceId', 'analysisId', 'version', 'dataFolder', 'outputFolder'});
files = localFiles(config);
if isempty(files), error('converter:dac:NoInputFiles', '没有找到噪声MAT文件。'); end
fileNames = arrayfun(@(f) fullfile(f.folder, f.name), files, 'UniformOutput', false);
% Read the first selected MAT before creating a result directory.  This
% makes an incomplete PicoScope export fail as an input error instead of
% leaving a run folder that contains no analysis evidence.
firstPath = fullfile(files(1).folder, files(1).name);
fprintf('正在读取噪声MAT：%s\n', firstPath);
firstCapture = converter.io.loadPicoMat(firstPath, localVariable(config, 1), ...
    config.hardwareGain, config.removeMean);
runContext = converter.runtime.createRun(config, config.dataFolder, ...
    fileNames, config.outputFolder);
try
rows = repmat(localEmptyRow(), numel(files), 1);
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    if k == 1
        capture = firstCapture;
    else
        capture = converter.io.loadPicoMat(path, localVariable(config, k), ...
            config.hardwareGain, config.removeMean);
    end
    fprintf('[%d/%d] Welch计算：%d点，实际采样率%.9g Hz，电压增益%g\n', ...
        k, numel(files), capture.sampleCount, capture.sampleRateHz, config.hardwareGain);
    [frequencyHz, psd, asd, setup] = localSpectrum(capture.voltage, ...
        capture.sampleRateHz, config);
    [~, checkIndex] = min(abs(frequencyHz - config.asdCheckHz));
    actualCheckHz = frequencyHz(checkIndex);
    relativeError = abs(actualCheckHz - config.asdCheckHz) / config.asdCheckHz;
    coverage = setup.segmentCount >= config.minimumAsdSegmentCount && ...
        setup.resolutionHz <= config.targetResolutionHz * (1 + 1e-6) && ...
        relativeError <= config.maximumAsdBinRelativeError;
    asdValue = asd(checkIndex) * 1e6;
    asdJudgment = localUpperLimit(asdValue, config.asdLimit_uVPerSqrtHz, ...
        coverage && config.formalEnabled);
    band = config.integratedBandHz;
    validateattributes(band, {'numeric'}, {'real','finite','numel',2,'nonnegative'});
    if band(2) <= band(1)
        error('converter:dac:NoiseBandInvalid', '积分上限必须大于下限。');
    end
    mask = frequencyHz >= band(1) & frequencyHz <= band(2);
    fullBand = band(1) >= frequencyHz(1) && band(2) <= frequencyHz(end) && nnz(mask) >= 2;
    integratedVrms = NaN; integratedJudgment = "未测试";
    if ~config.asdOnly
        if nnz(mask) >= 2
            integrationHz = frequencyHz(mask);
            if fullBand
                integrationHz = unique([band(1); integrationHz; band(2)]);
            end
            integrationPsd = interp1(frequencyHz, psd, integrationHz, 'linear');
            integratedVrms = sqrt(trapz(integrationHz, integrationPsd));
            integratedJudgment = localUpperLimit(integratedVrms * 1e6, ...
                config.integratedLimit_uVrms, fullBand && config.formalEnabled);
        else
            integratedJudgment = "暂不能判定";
        end
    end
    fprintf('正在导出%d个频点的完整频谱CSV及图片，请等待。\n', numel(frequencyHz));
    [spectrumFile, plotFile] = localEvidence(config, runContext.folder, ...
        files(k).name, frequencyHz, psd, asd, actualCheckHz, asdValue);
    rows(k) = localRow(path, files(k).name, capture, setup, actualCheckHz, ...
        relativeError, coverage, asdValue, asdJudgment, integratedVrms, ...
        integratedJudgment, fullBand, spectrumFile, plotFile);
end
summary = struct2table(rows);
converter.report.writeTable(summary, fullfile(runContext.folder, ...
    'dac_noise_summary.csv'));
converter.report.writeTable(localParameters(config), fullfile(runContext.folder, ...
    'analysis_parameters.csv'));
result = struct('config', config, 'summary', summary, ...
    'outputFolder', runContext.folder);
save(fullfile(runContext.folder, 'dac_noise_result.mat'), 'result');
fprintf('正在整理结果汇总.xlsx及evidence目录。\n');
converter.runtime.finishRun(runContext, true, 'DA噪声分析完成');
result = converter.runtime.refreshResultPaths(result, runContext.folder);
catch exception
    converter.runtime.finishRun(runContext, false, exception.message);
    rethrow(exception);
end
end

function [frequencyHz, psd, asd, setup] = localSpectrum(voltage, sampleRate, config)
validateattributes(config.targetResolutionHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(config.overlapRatio, {'numeric'}, {'real','scalar','finite','>=',0,'<',1});
sampleCount = numel(voltage);
if sampleCount < 16, error('converter:dac:TooFewNoiseSamples', '噪声记录至少需要16点。'); end
windowLength = round(sampleRate / config.targetResolutionHz);
windowLength = max(16, min(windowLength, sampleCount));
nfft = windowLength;
overlap = floor(windowLength * config.overlapRatio);
switch lower(char(config.windowType))
    case 'hann', window = hann(windowLength, 'periodic');
    case 'hamming', window = hamming(windowLength, 'periodic');
    otherwise, error('converter:dac:WindowUnsupported', '不支持的窗函数。');
end
[psd, frequencyHz] = pwelch(voltage, window, overlap, nfft, sampleRate);
asd = sqrt(psd);
step = windowLength - overlap;
segmentCount = 1 + floor((sampleCount - windowLength) / step);
setup = struct('windowLength', windowLength, 'overlapLength', overlap, ...
    'nfft', nfft, 'resolutionHz', sampleRate / nfft, ...
    'segmentCount', segmentCount);
end

function [spectrumFile, plotFile] = localEvidence(config, folder, fileName, ...
        frequencyHz, psd, asd, actualCheckHz, asdValue)
[~, stem] = fileparts(fileName);
safeStem = regexprep(stem, '[^A-Za-z0-9_-]', '_');
spectrumFile = fullfile(folder, [config.deviceId '_' safeStem '_ASD_spectrum.csv']);
if config.asdOnly
    spectrum = table(frequencyHz, asd, asd * 1e6, ...
        'VariableNames', {'frequency_hz','asd_V_per_sqrtHz','asd_uV_per_sqrtHz'});
else
    spectrum = table(frequencyHz, psd, asd, asd * 1e6, ...
        'VariableNames', {'frequency_hz','psd_V2_per_Hz', ...
        'asd_V_per_sqrtHz','asd_uV_per_sqrtHz'});
end
converter.report.writeTable(spectrum, spectrumFile);
plotFile = fullfile(folder, [config.deviceId '_' safeStem '_ASD']);
plotConfig = struct();
plotConfig.styleProfile = 'da9726_legacy_visual_adapter';
plotConfig.showLegend = false;
plotConfig.titleText = sprintf('%s | %s | DAC output ASD', config.deviceId, stem);
plotConfig.yLabel = 'ASD (uV/sqrtHz)';
plotConfig.lineLabel = 'ASD';
plotConfig.limitValue = config.asdLimit_uVPerSqrtHz;
plotConfig.limitLabel = sprintf('%.4g uV/sqrtHz limit', ...
    config.asdLimit_uVPerSqrtHz);
plotConfig.checkFrequencyHz = actualCheckHz;
plotConfig.checkValue = asdValue;
plotConfig.checkLabel = sprintf('实际频点 %.6g Hz', actualCheckHz);
plotConfig.annotationText = sprintf('ASD @ %.4g Hz = %.4f uV/sqrtHz', ...
    actualCheckHz, asdValue);
converter.report.plotSpectrum(frequencyHz(2:end), asd(2:end) * 1e6, ...
    plotFile, plotConfig);
end

function row = localRow(path, name, capture, setup, checkHz, relativeError, ...
        coverage, asdValue, asdJudgment, integratedVrms, integratedJudgment, ...
        fullBand, spectrumFile, plotFile)
row = localEmptyRow();
row.input_file = string(name); row.input_path = string(path);
    row.source_sha256 = string(converter.runtime.sha256File(path));
row.variable = string(capture.variableName); row.sample_rate_hz = capture.sampleRateHz;
row.duration_s = capture.sampleCount / capture.sampleRateHz;
row.sample_count = capture.sampleCount; row.dropped_nonfinite = capture.droppedNonfinite;
row.welch_window_samples = setup.windowLength; row.welch_overlap_samples = setup.overlapLength;
row.welch_nfft = setup.nfft; row.welch_resolution_hz = setup.resolutionHz;
row.welch_segment_count = setup.segmentCount; row.asd_check_actual_hz = checkHz;
row.asd_bin_relative_error = relativeError; row.asd_coverage_adequate = coverage;
row.asd_at_1hz_uV_per_sqrtHz = asdValue; row.asd_1hz_judgment = asdJudgment;
row.integrated_noise_uVrms = integratedVrms * 1e6;
row.integrated_judgment = integratedJudgment; row.requested_band_fully_covered = fullBand;
    row.spectrum_file = string(spectrumFile); row.asd_plot_file = string([plotFile '.png']);
row.formal_conclusion = asdJudgment;
if integratedJudgment == "不满足" || asdJudgment == "不满足"
    row.formal_conclusion = "不满足";
elseif integratedJudgment == "暂不能判定"
    row.formal_conclusion = "暂不能判定";
end
end

function row = localEmptyRow()
row = struct('input_file', "", 'input_path', "", 'source_sha256', "", ...
    'variable', "", 'sample_rate_hz', NaN, 'duration_s', NaN, ...
    'sample_count', NaN, 'dropped_nonfinite', NaN, ...
    'welch_window_samples', NaN, 'welch_overlap_samples', NaN, ...
    'welch_nfft', NaN, 'welch_resolution_hz', NaN, ...
    'welch_segment_count', NaN, 'asd_check_actual_hz', NaN, ...
    'asd_bin_relative_error', NaN, 'asd_coverage_adequate', false, ...
    'asd_at_1hz_uV_per_sqrtHz', NaN, 'asd_1hz_judgment', "", ...
    'integrated_noise_uVrms', NaN, 'integrated_judgment', "", ...
    'requested_band_fully_covered', false, 'spectrum_file', "", ...
    'asd_plot_file', "", 'formal_conclusion', "");
end

function judgment = localUpperLimit(value, limit, enabled)
if ~enabled || ~isfinite(value)
    judgment = "暂不能判定";
elseif value < limit
    judgment = "满足";
else
    judgment = "不满足";
end
end

function files = localFiles(config)
if isfield(config, 'inputFiles') && ~isempty(config.inputFiles)
    names = cellstr(config.inputFiles); files = struct([]);
    for k = 1:numel(names)
        item = dir(converter.io.resolveInputPath(config.dataFolder, names{k}));
        if isempty(item)
            error('converter:dac:InputMissing', '输入文件不存在：%s', names{k});
        end
        files = [files; item]; %#ok<AGROW>
    end
else
    files = dir(fullfile(config.dataFolder, config.filePattern));
end
end

function variable = localVariable(config, index)
if isfield(config, 'dataVariables') && ~isempty(config.dataVariables)
    values = cellstr(config.dataVariables); variable = values{min(index, numel(values))};
else
    variable = '';
end
end

function tableValue = localParameters(config)
names = fieldnames(config); values = cell(numel(names), 1);
for k = 1:numel(names), values{k} = converter.runtime.valueToText(config.(names{k})); end
tableValue = table(string(names), string(values), ...
    'VariableNames', {'Parameter', 'Value'});
end

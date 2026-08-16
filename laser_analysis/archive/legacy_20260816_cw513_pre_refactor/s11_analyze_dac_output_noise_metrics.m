%s11_analyze_dac_output_noise_metrics - 批量分析 DAC 输出噪声指标
%   s11_analyze_dac_output_noise_metrics 扫描 dataDir 下的 Pico MAT，
%   对每个文件计算指定频点 ASD 和指定频段积分 RMS 噪声。
%
%   MAT 必须包含 Tinterval 或 fs，以及一个 PicoScope 电压通道
%   A/B/C/D；也可通过 dacNoiseCfgOverride.dataVariables 显式指定。
%   电压/hardwareGain 被解释为 DAC 输出端电压。若 MAT 已在 DAC 输出
%   参考面，hardwareGain 应设为 1，避免重复折算。
%
%   ASD@1 Hz 需要足够长的记录。targetResolutionHz 决定 Welch 窗长；
%   若实际频率轴没有精确的 1 Hz 点，脚本使用最邻近频点，并把实际
%   频率写入结果表。解释结果时应同时检查 duration_s 和分辨率。
%
%   积分噪声按 sqrt(trapz(PSD)) 计算，单位 uVrms。若 Nyquist 不能
%   完整覆盖 integratedBandHz，则正式结论为“暂不能判定”；不能把
%   部分频段通过理解为完整指标通过。
%
%   首次使用时修改 analysisName、dataDir、hardwareGain、两个限值、
%   integratedBandHz 和 targetResolutionHz。输出目录包含每个文件
%   的完整 PSD/ASD CSV、独立 ASD/PSD 图，以及汇总 CSV 和 MAT。
%
%   Example:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       s11_analyze_dac_output_noise_metrics
%
%   See also s03_calc_dac_integrated_noise_1k_100k, pwelch, trapz
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% User configuration
paths = laser_test_paths();
cfg = struct();
cfg.scriptVersion = "1.2.0";
cfg.analysisName = "X7";
cfg.dataDir = string(fullfile(paths.dataRoot, 'YCQD_DA766', 'noise', 'X7'));
cfg.outputDir = fullfile(cfg.dataDir, "dac_noise_psd_result");
cfg.inputFiles = strings(0, 1);
cfg.dataVariables = strings(0, 1);
cfg.hardwareGain = 1;
cfg.removeMean = true;
cfg.asdCheckHz = 1;
cfg.asdLimit_uVPerSqrtHz = 75;
cfg.integratedBandHz = [1e3, 100e3];
cfg.integratedLimit_uVrms = 120;
cfg.asdOnly = false;
cfg.targetResolutionHz = 1;
cfg.overlapRatio = 0.5;
cfg.windowType = "hann";
cfg.minimumAsdSegmentCount = 4;
cfg.maximumAsdBinRelativeError = 0.25;
cfg.referencePlane = "DAC output; configure acquisition loading explicitly";
cfg.calibrationSource = "MAT voltage divided by configured hardwareGain";
cfg.requirementAsdId = "";
cfg.requirementIntegratedId = "";
cfg.requirementSourceDocument = "not configured";
cfg.requirementSourceSha256 = "";
cfg.formalEnabled = false;
cfg.formalLimitation = "Acquisition condition has not been verified";
cfg.showFigure = false;

if exist('dacNoiseCfgOverride', 'var')
    cfg = localApplyOverrides(cfg, dacNoiseCfgOverride);
end

%% Run analysis
if ~exist(cfg.outputDir, "dir")
    mkdir(cfg.outputDir);
end

if isempty(cfg.inputFiles)
    matFiles = dir(fullfile(cfg.dataDir, "*.mat"));
    matPaths = string(fullfile({matFiles.folder}, {matFiles.name})).';
else
    matPaths = string(cfg.inputFiles(:));
end
if isempty(matPaths)
    error("No MAT files configured for %s", cfg.dataDir);
end
if ~isempty(cfg.dataVariables) && numel(cfg.dataVariables) ~= numel(matPaths)
    error("dataVariables must be empty or match inputFiles in length.");
end

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
resultRows = repmat(localEmptyResult(), numel(matPaths), 1);

for k = 1:numel(matPaths)
    matPath = matPaths(k);
    if ~isfile(matPath)
        error("Configured MAT file does not exist: %s", matPath);
    end
    if isempty(cfg.dataVariables)
        dataVariable = "";
    else
        dataVariable = cfg.dataVariables(k);
    end
    fprintf("[%d/%d] Processing %s\n", k, numel(matPaths), matPath);

    resultRows(k) = localAnalyzeOneFile(cfg, matPath, dataVariable, timestamp);
end

resultTable = struct2table(resultRows);
if cfg.asdOnly
    variableNames = string(resultTable.Properties.VariableNames);
    integratedVariables = startsWith(variableNames, "integrated_") | ...
        startsWith(variableNames, "effective_band_") | ...
        startsWith(variableNames, "requested_band_") | ...
        variableNames == "psd_plot_file";
    resultTable(:, integratedVariables) = [];
end

csvFile = fullfile(cfg.outputDir, sprintf("%s_dac_noise_summary_%s.csv", cfg.analysisName, timestamp));
matFile = fullfile(cfg.outputDir, sprintf("%s_dac_noise_result_%s.mat", cfg.analysisName, timestamp));

writetable(resultTable, csvFile, 'Encoding', 'UTF-8');
save(matFile, "resultTable", "cfg");
localWriteAnalysisParameters(cfg);
localWriteStatus(cfg.outputDir, timestamp);

fprintf("\n=== DAC output noise metrics ===\n");
displayColumns = [ ...
    "analysis_interface", "input_file", "sample_rate_hz", "duration_s", ...
    "welch_resolution_hz", "welch_segment_count", ...
    "asd_at_1hz_uV_per_sqrtHz", "asd_1hz_judgment"];
if ~cfg.asdOnly
    displayColumns = [displayColumns, "integrated_noise_uVrms", ...
        "integrated_judgment", "requested_band_fully_covered"];
end
disp(resultTable(:, displayColumns));
fprintf("CSV: %s\n", csvFile);
fprintf("MAT: %s\n", matFile);

%% Local functions
function result = localAnalyzeOneFile(cfg, matPath, dataVariable, timestamp)
%localAnalyzeOneFile - 计算单个 MAT 的频点 ASD、积分噪声和判定

data = load(matPath);
sampleRateHz = localGetSampleRate(data);
[voltage, dataVariable] = localGetVoltage(data, dataVariable, matPath);
voltage = voltage ./ cfg.hardwareGain;
voltage = voltage(isfinite(voltage));

if cfg.removeMean
    voltage = voltage - mean(voltage);
end

sampleCount = numel(voltage);
if sampleCount < 16
    error("Too few valid samples in %s", matPath);
end

[windowVector, windowLength, overlapLength, nfft, resolutionHz] = ...
    localMakeWelchSetup(sampleCount, sampleRateHz, cfg.targetResolutionHz, ...
    cfg.overlapRatio, cfg.windowType);
segmentStep = windowLength - overlapLength;
segmentCount = 1 + floor((sampleCount - windowLength) / segmentStep);

[psdV2PerHz, frequencyHz] = pwelch(voltage, windowVector, overlapLength, nfft, sampleRateHz);
asdVPerSqrtHz = sqrt(psdV2PerHz);
asd_uVPerSqrtHz = asdVPerSqrtHz * 1e6;

[~, idx1Hz] = min(abs(frequencyHz - cfg.asdCheckHz));
actualAsdCheckHz = frequencyHz(idx1Hz);
asdAt1Hz = asd_uVPerSqrtHz(idx1Hz);
relativeBinError = abs(actualAsdCheckHz - cfg.asdCheckHz) / cfg.asdCheckHz;
asdCoverageAdequate = segmentCount >= cfg.minimumAsdSegmentCount && ...
    relativeBinError <= cfg.maximumAsdBinRelativeError;
asdJudgment = localJudgeUpperLimit(asdAt1Hz, ...
    cfg.asdLimit_uVPerSqrtHz, asdCoverageAdequate && cfg.formalEnabled);

nyquistHz = sampleRateHz / 2;
if cfg.asdOnly
    requestedBandFullyCovered = false;
    effectiveBandHz = [NaN, NaN];
    integratedNoiseVrms = NaN;
    integratedJudgment = "未处理";
else
    requestedBandFullyCovered = cfg.integratedBandHz(2) <= nyquistHz;
    effectiveBandHz = [cfg.integratedBandHz(1), ...
        min(cfg.integratedBandHz(2), nyquistHz)];
    if effectiveBandHz(2) <= effectiveBandHz(1)
        integratedNoiseVrms = NaN;
        integratedJudgment = "暂不能判定";
    else
        bandMask = frequencyHz >= effectiveBandHz(1) & frequencyHz <= effectiveBandHz(2);
        integratedNoiseVrms = sqrt(trapz(frequencyHz(bandMask), psdV2PerHz(bandMask)));
        integratedJudgment = localJudgeUpperLimit( ...
            integratedNoiseVrms * 1e6, cfg.integratedLimit_uVrms, ...
            requestedBandFullyCovered && cfg.formalEnabled);
    end
end

[asdPlotFile, psdPlotFile, spectrumCsv] = localSaveEvidence( ...
    cfg, matPath, frequencyHz, psdV2PerHz, asdVPerSqrtHz, ...
    actualAsdCheckHz, asdAt1Hz, effectiveBandHz, ...
    integratedNoiseVrms * 1e6, requestedBandFullyCovered, timestamp);

result = localEmptyResult();
result.analysis_interface = cfg.analysisName;
[~, inputName, inputExt] = fileparts(matPath);
result.input_file = string(inputName) + string(inputExt);
result.input_path = string(matPath);
fileInfo = dir(matPath);
result.input_size_bytes = fileInfo.bytes;
result.input_modified_at = string(datetime(fileInfo.datenum, ...
    'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
result.input_sha256 = laser_analysis.sha256_file(string(matPath));
result.data_variable = dataVariable;
result.reference_plane = cfg.referencePlane;
result.calibration_source = cfg.calibrationSource;
result.hardware_gain = cfg.hardwareGain;
result.sample_rate_hz = sampleRateHz;
result.nyquist_hz = nyquistHz;
result.sample_count = sampleCount;
result.duration_s = sampleCount / sampleRateHz;
result.remove_mean = cfg.removeMean;
result.window_type = cfg.windowType;
result.welch_window_samples = windowLength;
result.welch_overlap_samples = overlapLength;
result.welch_nfft = nfft;
result.welch_resolution_hz = resolutionHz;
result.welch_segment_count = segmentCount;
result.asd_check_requested_hz = cfg.asdCheckHz;
result.asd_check_actual_hz = actualAsdCheckHz;
result.asd_bin_relative_error = relativeBinError;
result.asd_coverage_adequate = asdCoverageAdequate;
result.asd_at_1hz_V_per_sqrtHz = asdAt1Hz * 1e-6;
result.asd_at_1hz_uV_per_sqrtHz = asdAt1Hz;
result.asd_1hz_limit_uV_per_sqrtHz = cfg.asdLimit_uVPerSqrtHz;
result.asd_requirement_id = cfg.requirementAsdId;
result.asd_1hz_judgment = asdJudgment;
result.integrated_band_start_hz = cfg.integratedBandHz(1);
result.integrated_band_end_hz = cfg.integratedBandHz(2);
result.effective_band_start_hz = effectiveBandHz(1);
result.effective_band_end_hz = effectiveBandHz(2);
result.requested_band_fully_covered = requestedBandFullyCovered;
result.integrated_noise_Vrms = integratedNoiseVrms;
result.integrated_noise_uVrms = integratedNoiseVrms * 1e6;
result.integrated_limit_uVrms = cfg.integratedLimit_uVrms;
result.integrated_requirement_id = cfg.requirementIntegratedId;
result.integrated_judgment = integratedJudgment;
if cfg.asdOnly
    result.formal_conclusion = asdJudgment;
else
    result.formal_conclusion = localCombineJudgments( ...
        asdJudgment, integratedJudgment);
end
result.formal_enabled = cfg.formalEnabled;
result.formal_limitation = cfg.formalLimitation;
result.requirement_source_document = cfg.requirementSourceDocument;
result.requirement_source_sha256 = cfg.requirementSourceSha256;
result.spectrum_csv = string(spectrumCsv);
result.asd_plot_file = string(asdPlotFile);
result.psd_plot_file = string(psdPlotFile);
end

function sampleRateHz = localGetSampleRate(data)
%localGetSampleRate - 从 Tinterval 或 fs 读取并验证采样率
if isfield(data, "Tinterval") && ~isempty(data.Tinterval)
    sampleRateHz = 1 / double(data.Tinterval(1));
elseif isfield(data, "fs") && ~isempty(data.fs)
    sampleRateHz = double(data.fs(1));
else
    error("MAT file must contain Tinterval or fs.");
end

if ~isfinite(sampleRateHz) || sampleRateHz <= 0
    error("Invalid sample rate.");
end
end

function [windowVector, windowLength, overlapLength, nfft, resolutionHz] = ...
    localMakeWelchSetup(sampleCount, sampleRateHz, targetResolutionHz, overlapRatio, windowType)
%localMakeWelchSetup - 按目标分辨率和窗类型生成 Welch 参数

if targetResolutionHz <= 0
    error("targetResolutionHz must be positive.");
end
if overlapRatio < 0 || overlapRatio >= 1
    error("overlapRatio must satisfy 0 <= overlapRatio < 1.");
end

windowLength = round(sampleRateHz / targetResolutionHz);
windowLength = max(16, min(windowLength, sampleCount));
nfft = windowLength;
overlapLength = floor(windowLength * overlapRatio);
resolutionHz = sampleRateHz / nfft;

switch lower(string(windowType))
    case "hann"
        windowVector = hann(windowLength, "periodic");
    case "hamming"
        windowVector = hamming(windowLength, "periodic");
    otherwise
        error("Unsupported windowType: %s", windowType);
end
end

function [asdPlotFile, psdPlotFile, spectrumCsv] = localSaveEvidence( ...
    cfg, matPath, frequencyHz, psdV2PerHz, asdVPerSqrtHz, ...
    actualAsdCheckHz, asdAt1Hz, effectiveBandHz, ...
    integratedNoise_uVrms, requestedBandFullyCovered, timestamp)
%LOCALSAVEEVIDENCE Save numeric evidence and requested figures.

[~, fileStem] = fileparts(matPath);
filePrefix = sprintf('%s_%s', cfg.analysisName, fileStem);
spectrumCsv = fullfile(cfg.outputDir, ...
    sprintf('%s_ASD_spectrum_%s.csv', filePrefix, timestamp));
asdPlotFile = fullfile(cfg.outputDir, ...
    sprintf('%s_ASD_%s.png', filePrefix, timestamp));
psdPlotFile = "";

if cfg.asdOnly
    spectrumTable = table(frequencyHz, asdVPerSqrtHz, ...
        asdVPerSqrtHz * 1e6, 'VariableNames', ...
        {'frequency_hz', 'asd_V_per_sqrtHz', 'asd_uV_per_sqrtHz'});
else
    spectrumTable = table(frequencyHz, psdV2PerHz, asdVPerSqrtHz, ...
        asdVPerSqrtHz * 1e6, 'VariableNames', ...
        {'frequency_hz', 'psd_V2_per_Hz', 'asd_V_per_sqrtHz', ...
        'asd_uV_per_sqrtHz'});
end
writetable(spectrumTable, spectrumCsv, 'Encoding', 'UTF-8');

figureVisibility = localFigureVisible(cfg.showFigure);
asdFigure = figure('Name', sprintf('%s DAC output ASD', cfg.analysisName), ...
    'Visible', figureVisibility, 'Color', 'w');
loglog(frequencyHz, asdVPerSqrtHz * 1e6, 'LineWidth', 1.1);
grid on;
hold on;
yline(cfg.asdLimit_uVPerSqrtHz, 'r--', ...
    sprintf('%.4g uV/sqrtHz limit', cfg.asdLimit_uVPerSqrtHz), ...
    'LineWidth', 1);
plot(actualAsdCheckHz, asdAt1Hz, 'ko', 'MarkerFaceColor', 'k', ...
    'MarkerSize', 5);
xlabel('Frequency (Hz)');
ylabel('DAC output ASD (uV/sqrtHz)');
title(sprintf('%s | %s | DAC output ASD', cfg.analysisName, fileStem), ...
    'Interpreter', 'none');
if cfg.asdOnly
    text(0.02, 0.05, sprintf( ...
        'ASD @ %.4g Hz = %.3f uV/sqrtHz\nWelch target resolution = %.4g Hz', ...
        actualAsdCheckHz, asdAt1Hz, cfg.targetResolutionHz), ...
        'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
        'BackgroundColor', 'white', 'EdgeColor', [0.5 0.5 0.5]);
elseif requestedBandFullyCovered
    bandText = sprintf('Integrated %.4g-%.4g Hz = %.3f uVrms', ...
        cfg.integratedBandHz(1), cfg.integratedBandHz(2), ...
        integratedNoise_uVrms);
else
    bandText = sprintf('Integrated %.4g-%.4g Hz = %.3f uVrms (partial)', ...
        effectiveBandHz(1), effectiveBandHz(2), integratedNoise_uVrms);
end
if ~cfg.asdOnly
    text(0.02, 0.05, sprintf( ...
        'ASD @ %.4g Hz = %.3f uV/sqrtHz\n%s\nIntegrated limit = %.3f uVrms', ...
        actualAsdCheckHz, asdAt1Hz, bandText, cfg.integratedLimit_uVrms), ...
        'Units', 'normalized', 'VerticalAlignment', 'bottom', ...
        'BackgroundColor', 'white', 'EdgeColor', [0.5 0.5 0.5]);
end
exportgraphics(asdFigure, asdPlotFile, 'Resolution', 180);
if ~cfg.showFigure, close(asdFigure); end

if ~cfg.asdOnly
    psdPlotFile = fullfile(cfg.outputDir, ...
        sprintf('%s_PSD_%s.png', filePrefix, timestamp));
    psdFigure = figure('Name', sprintf('%s DAC output PSD', cfg.analysisName), ...
        'Visible', figureVisibility, 'Color', 'w');
    loglog(frequencyHz, psdV2PerHz, 'LineWidth', 1.1);
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('DAC output PSD (V^2/Hz)');
    title(sprintf('%s | %s | DAC output PSD', cfg.analysisName, fileStem), ...
        'Interpreter', 'none');
    exportgraphics(psdFigure, psdPlotFile, 'Resolution', 180);
    if ~cfg.showFigure, close(psdFigure); end
end
end

function [voltage, variableName] = localGetVoltage(data, requested, matPath)
%LOCALGETVOLTAGE Resolve PicoScope channel A/B/C/D explicitly or uniquely.
requested = strtrim(string(requested));
if strlength(requested) > 0
    if ~isfield(data, requested)
        error('Configured data variable %s is missing in %s.', ...
            requested, matPath);
    end
    variableName = requested;
else
    candidates = ["A", "B", "C", "D"];
    present = candidates(arrayfun(@(name) isfield(data, name), candidates));
    if numel(present) ~= 1
        error('Expected exactly one PicoScope channel A/B/C/D in %s.', matPath);
    end
    variableName = present(1);
end
voltage = double(data.(variableName)(:));
end

function judgment = localJudgeUpperLimit(value, limit, coverageAdequate)
%LOCALJUDGEUPPERLIMIT Apply a strict upper limit with coverage gating.
if ~coverageAdequate || ~isfinite(value) || ~isfinite(limit)
    judgment = "暂不能判定";
elseif value < limit
    judgment = "满足";
else
    judgment = "不满足";
end
end

function conclusion = localCombineJudgments(asdJudgment, integratedJudgment)
%LOCALCOMBINEJUDGMENTS Combine two formal states conservatively.
states = [string(asdJudgment), string(integratedJudgment)];
if any(states == "不满足")
    conclusion = "不满足";
elseif all(states == "满足")
    conclusion = "满足";
else
    conclusion = "暂不能判定";
end
end

function visibleValue = localFigureVisible(showFigure)
%localFigureVisible - 将逻辑开关转换为 figure Visible 值
if showFigure
    visibleValue = "on";
else
    visibleValue = "off";
end
end

function cfg = localApplyOverrides(cfg, overrides)
%LOCALAPPLYOVERRIDES Apply only known top-level configuration fields.
fieldNames = fieldnames(overrides);
for fieldIndex = 1:numel(fieldNames)
    fieldName = fieldNames{fieldIndex};
    if ~isfield(cfg, fieldName)
        error('Unknown DAC-noise configuration field: %s', fieldName);
    end
    cfg.(fieldName) = overrides.(fieldName);
end
end

function localWriteAnalysisParameters(cfg)
%LOCALWRITEANALYSISPARAMETERS Write the reproducible run configuration.
parameterNames = { ...
    'script_version'; 'analysis_name'; 'data_root'; 'hardware_gain'; ...
    'remove_mean'; 'asd_check_hz'; 'asd_limit_uV_per_sqrtHz'; ...
    'asd_only'; 'integrated_band_hz'; 'integrated_limit_uVrms'; ...
    'target_resolution_hz'; 'overlap_ratio'; 'window_type'; ...
    'minimum_asd_segment_count'; 'maximum_asd_bin_relative_error'; ...
    'reference_plane'; 'calibration_source'; 'requirement_asd_id'; ...
    'requirement_integrated_id'; 'requirement_source_document'; ...
    'requirement_source_sha256'; 'formal_enabled'; 'formal_limitation'};
parameterValues = { ...
    char(cfg.scriptVersion); char(cfg.analysisName); char(cfg.dataDir); ...
    num2str(cfg.hardwareGain, 17); mat2str(cfg.removeMean); ...
    num2str(cfg.asdCheckHz, 17); ...
    num2str(cfg.asdLimit_uVPerSqrtHz, 17); mat2str(cfg.asdOnly); ...
    mat2str(cfg.integratedBandHz, 17); ...
    num2str(cfg.integratedLimit_uVrms, 17); ...
    num2str(cfg.targetResolutionHz, 17); ...
    num2str(cfg.overlapRatio, 17); char(cfg.windowType); ...
    num2str(cfg.minimumAsdSegmentCount, 17); ...
    num2str(cfg.maximumAsdBinRelativeError, 17); ...
    char(cfg.referencePlane); char(cfg.calibrationSource); ...
    char(cfg.requirementAsdId); char(cfg.requirementIntegratedId); ...
    char(cfg.requirementSourceDocument); char(cfg.requirementSourceSha256); ...
    mat2str(cfg.formalEnabled); char(cfg.formalLimitation)};
parameterTable = table(parameterNames, parameterValues, ...
    'VariableNames', {'Parameter', 'Value'});
if cfg.asdOnly
    unusedParameters = ismember(string(parameterTable.Parameter), ...
        ["integrated_band_hz", "integrated_limit_uVrms", ...
        "requirement_integrated_id"]);
    parameterTable(unusedParameters, :) = [];
end
writetable(parameterTable, fullfile(cfg.outputDir, ...
    'analysis_parameters.csv'), 'Encoding', 'UTF-8');
end

function localWriteStatus(outputDir, timestamp)
%LOCALWRITESTATUS Mark a fully completed result bundle.
fileId = fopen(fullfile(outputDir, 'STATUS_SUCCESS.txt'), 'w');
if fileId < 0
    error('Unable to write STATUS_SUCCESS.txt in %s.', outputDir);
end
cleanupObject = onCleanup(@() fclose(fileId));
fprintf(fileId, 'CompletedAt: %s\n', timestamp);
fprintf(fileId, 'Message: DAC output noise analysis completed.\n');
end

function result = localEmptyResult()
%localEmptyResult - 返回汇总结果行的预分配结构
result = struct( ...
    "analysis_interface", "", ...
    "input_file", "", ...
    "input_path", "", ...
    "input_size_bytes", NaN, ...
    "input_modified_at", "", ...
    "input_sha256", "", ...
    "data_variable", "", ...
    "reference_plane", "", ...
    "calibration_source", "", ...
    "hardware_gain", NaN, ...
    "sample_rate_hz", NaN, ...
    "nyquist_hz", NaN, ...
    "sample_count", NaN, ...
    "duration_s", NaN, ...
    "remove_mean", false, ...
    "window_type", "", ...
    "welch_window_samples", NaN, ...
    "welch_overlap_samples", NaN, ...
    "welch_nfft", NaN, ...
    "welch_resolution_hz", NaN, ...
    "welch_segment_count", NaN, ...
    "asd_check_requested_hz", NaN, ...
    "asd_check_actual_hz", NaN, ...
    "asd_bin_relative_error", NaN, ...
    "asd_coverage_adequate", false, ...
    "asd_at_1hz_V_per_sqrtHz", NaN, ...
    "asd_at_1hz_uV_per_sqrtHz", NaN, ...
    "asd_1hz_limit_uV_per_sqrtHz", NaN, ...
    "asd_requirement_id", "", ...
    "asd_1hz_judgment", "", ...
    "integrated_band_start_hz", NaN, ...
    "integrated_band_end_hz", NaN, ...
    "effective_band_start_hz", NaN, ...
    "effective_band_end_hz", NaN, ...
    "requested_band_fully_covered", false, ...
    "integrated_noise_Vrms", NaN, ...
    "integrated_noise_uVrms", NaN, ...
    "integrated_limit_uVrms", NaN, ...
    "integrated_requirement_id", "", ...
    "integrated_judgment", "", ...
    "formal_conclusion", "", ...
    "formal_enabled", false, ...
    "formal_limitation", "", ...
    "requirement_source_document", "", ...
    "requirement_source_sha256", "", ...
    "spectrum_csv", "", ...
    "asd_plot_file", "", ...
    "psd_plot_file", "");
end

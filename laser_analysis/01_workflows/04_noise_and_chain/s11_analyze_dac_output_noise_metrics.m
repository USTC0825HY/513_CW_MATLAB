%s11_analyze_dac_output_noise_metrics - 批量分析 DAC 输出噪声指标
%   s11_analyze_dac_output_noise_metrics 扫描 dataDir 下的 Pico MAT，
%   对每个文件计算指定频点 ASD 和指定频段积分 RMS 噪声。
%
%   MAT 必须包含：
%       A         - 测得的电压时序，单位 V
%       Tinterval - 相邻样本时间间隔，单位 s
%   A/hardwareGain 被解释为 DAC 输出端电压。若 MAT 已在 DAC 输出
%   参考面，hardwareGain 应设为 1，避免重复折算。
%
%   ASD@1 Hz 需要足够长的记录。targetResolutionHz 决定 Welch 窗长；
%   若实际频率轴没有精确的 1 Hz 点，脚本使用最邻近频点，并把实际
%   频率写入结果表。解释结果时应同时检查 duration_s 和分辨率。
%
%   积分噪声按 sqrt(trapz(PSD)) 计算，单位 uVrms。若 Nyquist 不能
%   完整覆盖 integratedBandHz，判断可能为 OUT_OF_RANGE 或
%   FAIL_PARTIAL_BAND；不能把部分频段通过理解为完整指标通过。
%
%   首次使用时修改 analysisName、dataDir、hardwareGain、两个限值、
%   integratedBandHz 和 targetResolutionHz。输出目录包含每个文件
%   的频谱图，以及带时间戳的汇总 CSV 和 MAT。
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
analysisName = "X7";
dataDir = string(fullfile(paths.dataRoot, 'YCQD_DA766', 'noise', 'X7'));
outputDir = fullfile(dataDir, "dac_noise_psd_result");

hardwareGain = 1;             % A / hardwareGain = DAC output voltage in V.
removeMean = true;            % Remove DC before noise spectrum estimation.

asdCheckHz = 1;
asdLimit_uVPerSqrtHz = 75;

integratedBandHz = [1e3, 100e3];
integratedLimit_uVrms = 120;

targetResolutionHz = 1;       % 1 Hz Welch bin for the ASD@1Hz metric.
overlapRatio = 0.5;
windowType = "hann";

showFigure = false;

%% Run analysis
if ~exist(outputDir, "dir")
    mkdir(outputDir);
end

matFiles = dir(fullfile(dataDir, "*.mat"));
if isempty(matFiles)
    error("No MAT files found in %s", dataDir);
end

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
resultRows = repmat(localEmptyResult(), numel(matFiles), 1);

for k = 1:numel(matFiles)
    matPath = fullfile(matFiles(k).folder, matFiles(k).name);
    fprintf("[%d/%d] Processing %s\n", k, numel(matFiles), matPath);

    resultRows(k) = localAnalyzeOneFile( ...
        analysisName, matPath, hardwareGain, removeMean, ...
        asdCheckHz, asdLimit_uVPerSqrtHz, ...
        integratedBandHz, integratedLimit_uVrms, ...
        targetResolutionHz, overlapRatio, windowType, ...
        outputDir, timestamp, showFigure);
end

resultTable = struct2table(resultRows);

csvFile = fullfile(outputDir, sprintf("%s_dac_noise_metrics_%s.csv", analysisName, timestamp));
matFile = fullfile(outputDir, sprintf("%s_dac_noise_metrics_%s.mat", analysisName, timestamp));

writetable(resultTable, csvFile);
save(matFile, "resultTable", "analysisName", "dataDir", "hardwareGain", ...
    "removeMean", "asdCheckHz", "asdLimit_uVPerSqrtHz", ...
    "integratedBandHz", "integratedLimit_uVrms", "targetResolutionHz", ...
    "overlapRatio", "windowType");

fprintf("\n=== DAC output noise metrics ===\n");
displayColumns = [ ...
    "analysis_interface", "input_file", "sample_rate_hz", "duration_s", ...
    "welch_resolution_hz", "asd_at_1hz_uV_per_sqrtHz", "asd_1hz_judgment", ...
    "integrated_noise_uVrms", "integrated_judgment", ...
    "requested_band_fully_covered"];
disp(resultTable(:, displayColumns));
fprintf("CSV: %s\n", csvFile);
fprintf("MAT: %s\n", matFile);

%% Local functions
function result = localAnalyzeOneFile( ...
    analysisName, matPath, hardwareGain, removeMean, ...
    asdCheckHz, asdLimit_uVPerSqrtHz, ...
    integratedBandHz, integratedLimit_uVrms, ...
    targetResolutionHz, overlapRatio, windowType, ...
    outputDir, timestamp, showFigure)
%localAnalyzeOneFile - 计算单个 MAT 的频点 ASD、积分噪声和判定

data = load(matPath);
if ~isfield(data, "A")
    error("MAT file does not contain variable A: %s", matPath);
end

sampleRateHz = localGetSampleRate(data);
voltage = double(data.A(:)) ./ hardwareGain;
voltage = voltage(isfinite(voltage));

if removeMean
    voltage = voltage - mean(voltage);
end

sampleCount = numel(voltage);
if sampleCount < 16
    error("Too few valid samples in %s", matPath);
end

[windowVector, windowLength, overlapLength, nfft, resolutionHz] = ...
    localMakeWelchSetup(sampleCount, sampleRateHz, targetResolutionHz, overlapRatio, windowType);

[psdV2PerHz, frequencyHz] = pwelch(voltage, windowVector, overlapLength, nfft, sampleRateHz);
asdVPerSqrtHz = sqrt(psdV2PerHz);
asd_uVPerSqrtHz = asdVPerSqrtHz * 1e6;

[~, idx1Hz] = min(abs(frequencyHz - asdCheckHz));
actualAsdCheckHz = frequencyHz(idx1Hz);
asdAt1Hz = asd_uVPerSqrtHz(idx1Hz);
if asdAt1Hz < asdLimit_uVPerSqrtHz
    asdJudgment = "PASS";
else
    asdJudgment = "FAIL";
end

nyquistHz = sampleRateHz / 2;
requestedBandFullyCovered = integratedBandHz(2) <= nyquistHz;
effectiveBandHz = [integratedBandHz(1), min(integratedBandHz(2), nyquistHz)];

if effectiveBandHz(2) <= effectiveBandHz(1)
    integratedNoiseVrms = NaN;
    integratedJudgment = "NO_DATA";
else
    bandMask = frequencyHz >= effectiveBandHz(1) & frequencyHz <= effectiveBandHz(2);
    integratedNoiseVrms = sqrt(trapz(frequencyHz(bandMask), psdV2PerHz(bandMask)));
    if ~requestedBandFullyCovered && integratedNoiseVrms * 1e6 >= integratedLimit_uVrms
        integratedJudgment = "FAIL_PARTIAL_BAND";
    elseif ~requestedBandFullyCovered
        integratedJudgment = "OUT_OF_RANGE";
    elseif integratedNoiseVrms * 1e6 < integratedLimit_uVrms
        integratedJudgment = "PASS";
    else
        integratedJudgment = "FAIL";
    end
end

plotFile = localSavePlot( ...
    analysisName, matPath, frequencyHz, asd_uVPerSqrtHz, ...
    asdCheckHz, actualAsdCheckHz, asdAt1Hz, asdLimit_uVPerSqrtHz, ...
    integratedBandHz, effectiveBandHz, integratedNoiseVrms * 1e6, ...
    integratedLimit_uVrms, requestedBandFullyCovered, outputDir, timestamp, showFigure);

result = localEmptyResult();
result.analysis_interface = analysisName;
[~, inputName, inputExt] = fileparts(matPath);
result.input_file = string(inputName) + string(inputExt);
result.input_path = string(matPath);
result.hardware_gain = hardwareGain;
result.sample_rate_hz = sampleRateHz;
result.nyquist_hz = nyquistHz;
result.sample_count = sampleCount;
result.duration_s = sampleCount / sampleRateHz;
result.remove_mean = removeMean;
result.window_type = windowType;
result.welch_window_samples = windowLength;
result.welch_overlap_samples = overlapLength;
result.welch_nfft = nfft;
result.welch_resolution_hz = resolutionHz;
result.asd_check_requested_hz = asdCheckHz;
result.asd_check_actual_hz = actualAsdCheckHz;
result.asd_at_1hz_V_per_sqrtHz = asdAt1Hz * 1e-6;
result.asd_at_1hz_uV_per_sqrtHz = asdAt1Hz;
result.asd_1hz_limit_uV_per_sqrtHz = asdLimit_uVPerSqrtHz;
result.asd_1hz_judgment = asdJudgment;
result.integrated_band_start_hz = integratedBandHz(1);
result.integrated_band_end_hz = integratedBandHz(2);
result.effective_band_start_hz = effectiveBandHz(1);
result.effective_band_end_hz = effectiveBandHz(2);
result.requested_band_fully_covered = requestedBandFullyCovered;
result.integrated_noise_Vrms = integratedNoiseVrms;
result.integrated_noise_uVrms = integratedNoiseVrms * 1e6;
result.integrated_limit_uVrms = integratedLimit_uVrms;
result.integrated_judgment = integratedJudgment;
result.plot_file = string(plotFile);
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

function plotFile = localSavePlot( ...
    analysisName, matPath, frequencyHz, asd_uVPerSqrtHz, ...
    asdCheckHz, actualAsdCheckHz, asdAt1Hz, asdLimit_uVPerSqrtHz, ...
    requestedBandHz, effectiveBandHz, integratedNoise_uVrms, ...
    integratedLimit_uVrms, requestedBandFullyCovered, outputDir, timestamp, showFigure)
%localSavePlot - 保存单文件 ASD、频点限值和积分频段图

[~, fileStem] = fileparts(matPath);
plotFile = fullfile(outputDir, sprintf("%s_%s_asd_%s.png", analysisName, fileStem, timestamp));

fig = figure("Name", sprintf("%s DAC output ASD", analysisName), "Visible", localFigureVisible(showFigure));
tiledlayout(fig, 1, 1);
nexttile;
loglog(frequencyHz, asd_uVPerSqrtHz, "LineWidth", 1.1);
grid on;
hold on;
xline(actualAsdCheckHz, "k--", sprintf("ASD @ %.4g Hz", actualAsdCheckHz), "LineWidth", 1);
yline(asdLimit_uVPerSqrtHz, "r--", sprintf("%.4g uV/sqrtHz limit", asdLimit_uVPerSqrtHz), "LineWidth", 1);
xline(requestedBandHz(1), "m--", "1 kHz", "LineWidth", 1);
xline(effectiveBandHz(2), "m--", sprintf("%.4g Hz effective end", effectiveBandHz(2)), "LineWidth", 1);

xlabel("Frequency (Hz)");
ylabel("DAC output ASD (uV/sqrtHz)");
title(sprintf("%s DAC output noise ASD", analysisName));

if requestedBandFullyCovered
    bandText = sprintf("Integrated %.4g-%.4g Hz = %.3f uVrms", ...
        requestedBandHz(1), requestedBandHz(2), integratedNoise_uVrms);
else
    bandText = sprintf("Requested %.4g-%.4g Hz exceeds Nyquist; integrated %.4g-%.4g Hz = %.3f uVrms", ...
        requestedBandHz(1), requestedBandHz(2), effectiveBandHz(1), effectiveBandHz(2), integratedNoise_uVrms);
end

noteFormat = [ ...
    'ASD @ %.4g Hz bin = %.3f uV/sqrtHz\n', ...
    'Limit = %.3f uV/sqrtHz\n', ...
    '%s\n', ...
    'Integrated limit = %.3f uVrms'];
text(0.02, 0.05, sprintf(noteFormat, ...
    asdCheckHz, asdAt1Hz, asdLimit_uVPerSqrtHz, bandText, integratedLimit_uVrms), ...
    "Units", "normalized", "VerticalAlignment", "bottom", ...
    "BackgroundColor", "white", "EdgeColor", [0.5 0.5 0.5], ...
    "FontName", "Consolas");

exportgraphics(fig, plotFile, "Resolution", 180);
if ~showFigure
    close(fig);
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

function result = localEmptyResult()
%localEmptyResult - 返回汇总结果行的预分配结构
result = struct( ...
    "analysis_interface", "", ...
    "input_file", "", ...
    "input_path", "", ...
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
    "asd_check_requested_hz", NaN, ...
    "asd_check_actual_hz", NaN, ...
    "asd_at_1hz_V_per_sqrtHz", NaN, ...
    "asd_at_1hz_uV_per_sqrtHz", NaN, ...
    "asd_1hz_limit_uV_per_sqrtHz", NaN, ...
    "asd_1hz_judgment", "", ...
    "integrated_band_start_hz", NaN, ...
    "integrated_band_end_hz", NaN, ...
    "effective_band_start_hz", NaN, ...
    "effective_band_end_hz", NaN, ...
    "requested_band_fully_covered", false, ...
    "integrated_noise_Vrms", NaN, ...
    "integrated_noise_uVrms", NaN, ...
    "integrated_limit_uVrms", NaN, ...
    "integrated_judgment", "", ...
    "plot_file", "");
end

%s08_calibrate_dac_multi_sine - 执行 DAC 多点 Vpp-Codepp 正式标定
%   s08_calibrate_dac_multi_sine 从多组 PicoScope MAT 中拟合 DAC 输出
%   正弦 Vpp，并建立以下主标定关系：
%       output_vpp = slope_vpp_per_code*dac_code_vpp + intercept_vpp
%
%   文件名必须包含 code_<整数>，例如 1kHz_code_-30000.mat。文件名
%   中的 code 被解释为正弦峰值设置；16 位无符号 VIO 字会先转换成
%   有符号码，主横轴默认 dac_code_vpp=2*abs(signed_code)。
%
%   每个 MAT 必须包含电压 A 和采样间隔 Tinterval。hardwareGain 表示
%   测量链路增益，脚本使用 A/hardwareGain 得到 DAC 输出电压。
%   toneFreqHz 必须与采集正弦一致，否则拟合 R^2 和 Vpp 会失真。
%
%   outputVppMethod='sineFit' 使用整段正弦拟合，通常比 minMax 更稳健；
%   minMax 仅适合记录干净且无离群点的情况。主拟合按码值范围、
%   minSineFitR2 和 Codepp 范围筛选文件，被排除点仍保留用于追溯。
%
%   无环境变量时脚本弹窗选择 MAT。批处理可设置：
%       S08_DAC_DATA_DIR            - 输入 MAT 目录
%       S08_ANALYSIS_INTERFACE_NAME - DAC 接口名称
%       S08_EXCLUDED_SIGNED_CODES   - 逗号或空格分隔的排除码值
%
%   输出 measurements、主 fit summary、旧 signed-peak 诊断结果、
%   拟合图和 MAT。正式换算只应使用主 Vpp-Codepp summary 的斜率。
%
%   Example:
%       setenv('S08_DAC_DATA_DIR','F:\path\replace_with_dac_mat')
%       setenv('S08_ANALYSIS_INTERFACE_NAME','JG3')
%       s08_calibrate_dac_multi_sine
%
%   See also s07_calibrate_ila_multi_sine,
%   s09_analyze_ad_input_equiv_noise_new_flow

clear;
clc;

%% ======================== User parameters ========================

paths = laser_test_paths();

% Interface/channel name used in plot titles and exported file names.
analysisInterfaceName = "JG3";

% The script opens a file picker and processes the selected MAT files. The
% selected folder is also used as the output base directory.
initialDir = string(fullfile(paths.dac9726DataRoot, '20260707_dac_scale'));

% Use signed decimal file names when possible, for example:
%   1kHz_code_-30000.mat, 1kHz_code_0.mat, 1kHz_code_30000.mat
excludedSignedCodes = [];

outFolderName = "dac_sine_scale_result";
filePattern = "1kHz_code_*.mat";

toneFreqHz = 1e3;
hardwareGain = 1;
dacCodeBits = 16;

mainCalibrationMode = "vpp_code_vpp";
dacCodeVppDefinition = "twice_abs_signed_code";
outputVppMethod = "sineFit";      % "sineFit" or "minMax"

fitCodeMode = "linearRegion";
linearCodeMin = -32768;
linearCodeMax = 32767;
minSineFitR2 = 0.98;
minCodeVppForFit = 512;
maxCodeVppForFit = 0.90 * 2^dacCodeBits;

showCalibrationPlot = false;
autoExportCalibrationPlot = true;
plotImageDpi = 300;

%% ======================== Main workflow ========================

analysisInterfaceName = getStringEnv("S08_ANALYSIS_INTERFACE_NAME", ...
    analysisInterfaceName);
excludedSignedCodes = getNumberListEnv("S08_EXCLUDED_SIGNED_CODES", ...
    excludedSignedCodes);
envDataDir = getStringEnv("S08_DAC_DATA_DIR", "");

if strlength(envDataDir) > 0
    dataDir = char(envDataDir);
    selectedFileNames = listDacMatFiles(dataDir, filePattern);
else
    [selectedFileNames, dataDir] = selectDacMatFiles(initialDir, filePattern);
end

job = struct( ...
    "analysisInterfaceName", analysisInterfaceName, ...
    "dataDir", string(dataDir), ...
    "selectedFileNames", {selectedFileNames}, ...
    "excludedSignedCodes", excludedSignedCodes);

runDacCalibrationJob(job, outFolderName, filePattern, toneFreqHz, ...
    hardwareGain, dacCodeBits, mainCalibrationMode, dacCodeVppDefinition, ...
    outputVppMethod, fitCodeMode, linearCodeMin, linearCodeMax, ...
    minSineFitR2, minCodeVppForFit, maxCodeVppForFit, showCalibrationPlot, ...
    autoExportCalibrationPlot, plotImageDpi);

%% ======================== Local functions ========================

function runDacCalibrationJob(job, outFolderName, filePattern, toneFreqHz, ...
    hardwareGain, dacCodeBits, mainCalibrationMode, dacCodeVppDefinition, ...
    outputVppMethod, fitCodeMode, linearCodeMin, linearCodeMax, ...
    minSineFitR2, minCodeVppForFit, maxCodeVppForFit, showCalibrationPlot, ...
    autoExportCalibrationPlot, plotImageDpi)
%runDacCalibrationJob - 执行一组 DAC 文件的分析、筛选、拟合和导出

analysisInterfaceName = job.analysisInterfaceName;
dataDir = job.dataDir;
excludedSignedCodes = job.excludedSignedCodes;

validateTopLevelOptions(mainCalibrationMode, dacCodeVppDefinition, ...
    outputVppMethod);

if isfield(job, 'selectedFileNames') && ~isempty(job.selectedFileNames)
    files = makeFileStructsFromSelection(dataDir, job.selectedFileNames);
else
    files = dir(fullfile(dataDir, filePattern));
end
if isempty(files)
    error("No MAT files found: %s", fullfile(dataDir, filePattern));
end

rows = repmat(emptyMeasurementRow(), numel(files), 1);
for k = 1:numel(files)
    matPath = fullfile(files(k).folder, files(k).name);
    codeInfo = parseCodeFromFileName(files(k).name, dacCodeBits);
    fprintf("[%d/%d] Processing signed_code=%d, raw_unsigned=%d: %s\n", ...
        k, numel(files), codeInfo.signedCode, codeInfo.rawUnsignedCode, matPath);

    rows(k) = analyzeDacSineFile(matPath, codeInfo, toneFreqHz, ...
        hardwareGain, dacCodeVppDefinition, outputVppMethod);
end

measurementTable = sortrows(struct2table(rows), "signed_code");
[fitMask, exclusionReason] = selectVppFitPoints(measurementTable, fitCodeMode, ...
    linearCodeMin, linearCodeMax, excludedSignedCodes, minSineFitR2, ...
    minCodeVppForFit, maxCodeVppForFit);

if nnz(fitMask) < 2
    error("Fewer than two usable Vpp fit points. Check fitCodeMode and data quality.");
end

vppCalibration = fitLinearCalibration(measurementTable.dac_code_vpp(fitMask), ...
    measurementTable.selected_output_vpp(fitMask));

measurementTable.analysis_interface = repmat(analysisInterfaceName, ...
    height(measurementTable), 1);
measurementTable.fit_used = fitMask;
measurementTable.fit_exclusion_reason = exclusionReason;
measurementTable.fitted_output_vpp = NaN(height(measurementTable), 1);
measurementTable.residual_vpp = NaN(height(measurementTable), 1);
measurementTable.fitted_output_vpp(fitMask) = vppCalibration.yFit;
measurementTable.residual_vpp(fitMask) = vppCalibration.residual;
measurementTable = movevars(measurementTable, "analysis_interface", ...
    "Before", "input_file");

vppFitSummary = makeVppFitSummaryTable(analysisInterfaceName, dataDir, ...
    toneFreqHz, hardwareGain, dacCodeBits, mainCalibrationMode, ...
    dacCodeVppDefinition, outputVppMethod, fitCodeMode, linearCodeMin, ...
    linearCodeMax, minCodeVppForFit, maxCodeVppForFit, excludedSignedCodes, ...
    measurementTable, fitMask, vppCalibration);

[signedPeakDiagnosticTable, signedPeakDiagnosticSummary, ...
    signedPeakDiagnosticCalibration] = makeSignedPeakDiagnosticResults( ...
    measurementTable, analysisInterfaceName, dataDir, toneFreqHz, hardwareGain, ...
    dacCodeBits, fitCodeMode, linearCodeMin, linearCodeMax, ...
    excludedSignedCodes, minSineFitR2);

outDir = fullfile(dataDir, outFolderName);
if ~exist(outDir, "dir")
    mkdir(outDir);
end

timestamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
outputPrefix = safeFileStem(sprintf("%s_dac_vpp_code_vpp_scale", ...
    analysisInterfaceName));
measurementPath = fullfile(outDir, outputPrefix + "_vpp_measurements_" + timestamp + ".csv");
summaryPath = fullfile(outDir, outputPrefix + "_vpp_fit_summary_" + timestamp + ".csv");
plotPath = fullfile(outDir, outputPrefix + "_vpp_fit_" + timestamp + ".png");
matResultPath = fullfile(outDir, outputPrefix + "_result_" + timestamp + ".mat");

measurementPath = writeTableSafe(measurementTable, measurementPath);
summaryPath = writeTableSafe(vppFitSummary, summaryPath);
saveVppCalibrationPlot(measurementTable, fitMask, vppCalibration, ...
    analysisInterfaceName, outputVppMethod, plotPath, showCalibrationPlot, ...
    autoExportCalibrationPlot, plotImageDpi);
save(matResultPath, "measurementTable", "vppFitSummary", "vppCalibration", ...
    "signedPeakDiagnosticTable", "signedPeakDiagnosticSummary", ...
    "signedPeakDiagnosticCalibration");

fprintf("\n=== DAC Vpp-code_vpp scale: %s ===\n", analysisInterfaceName);
fprintf("Fit files               : %d / %d\n", nnz(fitMask), height(measurementTable));
fprintf("Excluded files          : %d\n", height(measurementTable) - nnz(fitMask));
fprintf("output_vpp = %.12g * dac_code_vpp %+.12g\n", ...
    vppCalibration.slope, vppCalibration.intercept);
fprintf("dac_code_vpp = (output_vpp - (%+.12g)) / %.12g\n", ...
    vppCalibration.intercept, vppCalibration.slope);
fprintf("Scale                   : %.9g uV/code\n", ...
    vppCalibration.slope * 1e6);
fprintf("R2                      : %.9g\n", vppCalibration.r2);
fprintf("Residual RMS            : %.9g Vpp\n", vppCalibration.residualRms);
fprintf("Measurement CSV         : %s\n", measurementPath);
fprintf("Summary CSV             : %s\n", summaryPath);
fprintf("Result MAT              : %s\n", matResultPath);
fprintf("Plot PNG                : %s\n", ...
    makePlotPathMessage(autoExportCalibrationPlot, plotPath));
end

function [fileNames, dataDir] = selectDacMatFiles(initialDir, filePattern)
%selectDacMatFiles - 通过 GUI 选择一个或多个 DAC 标定 MAT
[fileNames, dataDir] = uigetfile( ...
    {char(filePattern), 'DAC PicoScope MAT files'; '*.mat', 'MAT files'}, ...
    'Select DAC sine MAT files', char(initialDir), 'MultiSelect', 'on');

if isequal(fileNames, 0)
    error("No DAC MAT files selected.");
end

fileNames = normalizeFileNames(fileNames);
end

function fileNames = listDacMatFiles(dataDir, filePattern)
%listDacMatFiles - 在批处理目录中按模式列出输入 MAT
files = dir(fullfile(dataDir, filePattern));
if isempty(files)
    error("No MAT files found: %s", fullfile(dataDir, filePattern));
end

fileNames = {files.name}.';
end

function fileNames = normalizeFileNames(fileNames)
%normalizeFileNames - 将单文件或多文件输入统一为 cell 数组
if ischar(fileNames) || isstring(fileNames)
    fileNames = cellstr(fileNames);
end

fileNames = fileNames(:);
end

function value = getStringEnv(envName, defaultValue)
%getStringEnv - 读取字符串环境变量，空值时返回默认值
rawValue = getenv(char(envName));
if isempty(rawValue)
    value = string(defaultValue);
else
    value = string(rawValue);
end
end

function values = getNumberListEnv(envName, defaultValues)
%getNumberListEnv - 解析环境变量中的逗号或空格分隔数值
rawValue = strtrim(getenv(char(envName)));
if isempty(rawValue)
    values = defaultValues;
    return;
end

tokens = regexp(rawValue, '[-+]?\d+(?:\.\d+)?', 'match');
if isempty(tokens)
    values = [];
else
    values = str2double(tokens);
end
end

function files = makeFileStructsFromSelection(dataDir, fileNames)
%makeFileStructsFromSelection - 将选中文件转换为类似 dir 的结构
fileNames = normalizeFileNames(fileNames);
files = repmat(struct('folder', char(dataDir), 'name', ''), numel(fileNames), 1);
for k = 1:numel(fileNames)
    filePath = fullfile(dataDir, fileNames{k});
    if ~exist(filePath, "file")
        error("Selected MAT file does not exist: %s", filePath);
    end

    files(k).folder = char(dataDir);
    files(k).name = fileNames{k};
end
end

function row = emptyMeasurementRow()
%emptyMeasurementRow - 返回单个 DAC 文件结果的预分配结构
row = struct( ...
    "input_file", string(missing), ...
    "input_path", string(missing), ...
    "parsed_code_from_file", NaN, ...
    "raw_unsigned_code", NaN, ...
    "signed_code", NaN, ...
    "abs_signed_code", NaN, ...
    "dac_code_vpp", NaN, ...
    "dac_code_vpp_definition", string(missing), ...
    "sample_count", NaN, ...
    "sample_rate_hz", NaN, ...
    "tinterval_s", NaN, ...
    "tone_freq_hz", NaN, ...
    "fit_vpp_v", NaN, ...
    "selected_output_vpp", NaN, ...
    "output_vpp_method", string(missing), ...
    "fit_amplitude_v", NaN, ...
    "signed_output_amplitude_v", NaN, ...
    "fit_positive_peak_v", NaN, ...
    "fit_negative_peak_v", NaN, ...
    "signed_output_peak_v", NaN, ...
    "positive_level_v", NaN, ...
    "negative_level_v", NaN, ...
    "fit_offset_v", NaN, ...
    "fit_phase_rad", NaN, ...
    "sine_r2", NaN, ...
    "sine_residual_rms_v", NaN, ...
    "min_v", NaN, ...
    "max_v", NaN, ...
    "mean_v", NaN, ...
    "std_v", NaN, ...
    "minmax_vpp_v", NaN);
end

function row = analyzeDacSineFile(matPath, codeInfo, toneFreqHz, hardwareGain, ...
    dacCodeVppDefinition, outputVppMethod)
%analyzeDacSineFile - 读取单个 MAT 并计算输出正弦 Vpp 及质量指标
data = load(matPath, "A", "Tinterval");
if ~isfield(data, "A") || ~isfield(data, "Tinterval")
    error("MAT file must contain A and Tinterval: %s", matPath);
end

y = double(data.A(:)) ./ hardwareGain;
y = y(isfinite(y));
if numel(y) < 16
    error("Too few finite samples in %s: %d", matPath, numel(y));
end

tinterval = double(data.Tinterval);
sampleRate = 1 / tinterval;
t = (0:numel(y)-1).' * tinterval;
fit = fitSineAtFixedFrequency(t, y, toneFreqHz);
signedOutputAmplitude = signForCode(codeInfo.signedCode) * fit.amplitude;
signedOutputPeak = chooseSignedPeak(codeInfo.signedCode, fit);

[~, fileName, fileExt] = fileparts(matPath);
row = emptyMeasurementRow();
row.input_file = string(fileName) + string(fileExt);
row.input_path = string(matPath);
row.parsed_code_from_file = codeInfo.parsedCode;
row.raw_unsigned_code = codeInfo.rawUnsignedCode;
row.signed_code = codeInfo.signedCode;
row.abs_signed_code = abs(codeInfo.signedCode);
row.dac_code_vpp = makeDacCodeVpp(codeInfo.signedCode, dacCodeVppDefinition);
row.dac_code_vpp_definition = string(dacCodeVppDefinition);
row.sample_count = numel(y);
row.sample_rate_hz = sampleRate;
row.tinterval_s = tinterval;
row.tone_freq_hz = toneFreqHz;
row.fit_vpp_v = fit.vpp;
row.output_vpp_method = string(outputVppMethod);
row.fit_amplitude_v = fit.amplitude;
row.signed_output_amplitude_v = signedOutputAmplitude;
row.fit_positive_peak_v = fit.positivePeak;
row.fit_negative_peak_v = fit.negativePeak;
row.signed_output_peak_v = signedOutputPeak;
row.positive_level_v = fit.amplitude;
row.negative_level_v = -fit.amplitude;
row.fit_offset_v = fit.offset;
row.fit_phase_rad = fit.phaseRad;
row.sine_r2 = fit.r2;
row.sine_residual_rms_v = fit.residualRms;
row.min_v = min(y);
row.max_v = max(y);
row.mean_v = mean(y);
row.std_v = std(y);
row.minmax_vpp_v = max(y) - min(y);
row.selected_output_vpp = selectOutputVpp(row, outputVppMethod);
end

function validateTopLevelOptions(mainCalibrationMode, dacCodeVppDefinition, ...
    outputVppMethod)
%validateTopLevelOptions - 验证主标定口径、Codepp 定义和 Vpp 方法
if ~strcmpi(mainCalibrationMode, "vpp_code_vpp")
    error("mainCalibrationMode must be 'vpp_code_vpp'.");
end

if ~strcmpi(dacCodeVppDefinition, "twice_abs_signed_code")
    error("dacCodeVppDefinition must be 'twice_abs_signed_code'.");
end

validMethods = ["sinefit", "minmax"];
if ~ismember(lower(string(outputVppMethod)), validMethods)
    error("outputVppMethod must be 'sineFit' or 'minMax'.");
end
end

function dacCodeVpp = makeDacCodeVpp(signedCode, dacCodeVppDefinition)
%makeDacCodeVpp - 按约定把峰值设置转换为 DAC Codepp
switch lower(string(dacCodeVppDefinition))
    case "twice_abs_signed_code"
        dacCodeVpp = 2 * abs(signedCode);
    otherwise
        error("Unsupported dacCodeVppDefinition: %s.", dacCodeVppDefinition);
end
end

function selectedOutputVpp = selectOutputVpp(row, outputVppMethod)
%selectOutputVpp - 选择正弦拟合或 min/max 作为输出 Vpp
switch lower(string(outputVppMethod))
    case "sinefit"
        selectedOutputVpp = row.fit_vpp_v;
    case "minmax"
        selectedOutputVpp = row.minmax_vpp_v;
    otherwise
        error("outputVppMethod must be 'sineFit' or 'minMax'.");
end
end

function signedPeak = chooseSignedPeak(signedCode, fit)
%chooseSignedPeak - 按文件名码值极性选择对应拟合峰值
if signedCode > 0
    signedPeak = fit.positivePeak;
elseif signedCode < 0
    signedPeak = fit.negativePeak;
else
    signedPeak = fit.offset;
end
end

function amplitudeSign = signForCode(signedCode)
%signForCode - 返回码值极性，零值单独标记
if signedCode < 0
    amplitudeSign = -1;
elseif signedCode > 0
    amplitudeSign = 1;
else
    amplitudeSign = 0;
end
end

function codeInfo = parseCodeFromFileName(fileName, dacCodeBits)
%parseCodeFromFileName - 从文件名解析原始码并转换为有符号码
tokens = regexp(fileName, "code_(-?\d+)", "tokens", "once");
if isempty(tokens)
    error("Cannot parse DAC code from file name: %s", fileName);
end

parsedCode = str2double(tokens{1});
maxSignedCode = 2^(dacCodeBits - 1) - 1;
fullScaleCode = 2^dacCodeBits;
if parsedCode > maxSignedCode
    signedCode = parsedCode - fullScaleCode;
else
    signedCode = parsedCode;
end

rawUnsignedCode = mod(signedCode, fullScaleCode);
codeInfo = struct( ...
    "parsedCode", parsedCode, ...
    "rawUnsignedCode", rawUnsignedCode, ...
    "signedCode", signedCode);
end

function fit = fitSineAtFixedFrequency(t, y, toneFreqHz)
%fitSineAtFixedFrequency - 在线性 sin/cos 基上拟合输出正弦
y = y(:);
w = 2 * pi * toneFreqHz;
X = [sin(w * t(:)), cos(w * t(:)), ones(numel(t), 1)];
coef = X \ y;

fit.sinCoef = coef(1);
fit.cosCoef = coef(2);
fit.offset = coef(3);
fit.amplitude = hypot(coef(1), coef(2));
fit.vpp = 2 * fit.amplitude;
fit.positivePeak = fit.offset + fit.amplitude;
fit.negativePeak = fit.offset - fit.amplitude;
fit.phaseRad = atan2(coef(2), coef(1));
fit.yFit = X * coef;

residual = y - fit.yFit;
fit.residualRms = sqrt(mean(residual.^2));
sse = sum(residual.^2);
sst = sum((y - mean(y)).^2);
if sst > 0
    fit.r2 = 1 - sse / sst;
else
    fit.r2 = NaN;
end
end

function [fitMask, exclusionReason] = selectVppFitPoints(measurementTable, ...
    fitCodeMode, linearCodeMin, linearCodeMax, excludedSignedCodes, ...
    minSineFitR2, minCodeVppForFit, maxCodeVppForFit)
%selectVppFitPoints - 按 R^2、码值和 Codepp 范围筛选主拟合文件

signedCode = measurementTable.signed_code;
goodSineMask = measurementTable.sine_r2 >= minSineFitR2;
finiteMask = isfinite(measurementTable.dac_code_vpp) ...
    & isfinite(measurementTable.selected_output_vpp);
minCodeMask = measurementTable.dac_code_vpp >= minCodeVppForFit;
maxCodeMask = measurementTable.dac_code_vpp < maxCodeVppForFit;
excludedMask = ismember(signedCode, excludedSignedCodes);

fitMask = finiteMask & goodSineMask & minCodeMask & maxCodeMask ...
    & ~excludedMask;

exclusionReason = strings(height(measurementTable), 1);
exclusionReason(:) = "used";
exclusionReason(~finiteMask) = "invalid_vpp";
exclusionReason(~goodSineMask) = "low_sine_r2";
exclusionReason(~minCodeMask) = "below_min_code_vpp";
exclusionReason(~maxCodeMask) = "above_max_code_vpp_or_saturated";
exclusionReason(excludedMask) = "excluded_known_anomaly";

switch lower(char(fitCodeMode))
    case "linearregion"
        belowMask = signedCode < linearCodeMin;
        aboveMask = signedCode > linearCodeMax;
        fitMask = fitMask & ~belowMask & ~aboveMask;
        exclusionReason(belowMask) = "below_linear_region";
        exclusionReason(aboveMask) = "above_linear_region";

    case "all"
        % Keep only data-quality and Vpp-range filtering above.

    otherwise
        error("fitCodeMode must be linearRegion or all.");
end

exclusionReason(fitMask) = "used";
end

function [fitMask, exclusionReason] = selectFitPoints(measurementTable, ...
    fitCodeMode, linearCodeMin, linearCodeMax, ...
    excludedSignedCodes, minSineFitR2)
%selectFitPoints - 为旧 signed-peak 诊断拟合选择可用文件

signedCode = measurementTable.signed_code;
zeroCodeMask = signedCode == 0;
goodSineMask = measurementTable.sine_r2 >= minSineFitR2;
fitMask = isfinite(measurementTable.signed_output_peak_v) ...
    & isfinite(measurementTable.fit_amplitude_v) ...
    & (goodSineMask | zeroCodeMask);
exclusionReason = strings(height(measurementTable), 1);
exclusionReason(:) = "used";
exclusionReason(~isfinite(measurementTable.signed_output_peak_v) ...
    | ~isfinite(measurementTable.fit_amplitude_v)) = "invalid_amplitude";
exclusionReason(~goodSineMask & ~zeroCodeMask) = "low_sine_r2";

switch lower(char(fitCodeMode))
    case "linearregion"
        belowMask = signedCode < linearCodeMin;
        aboveMask = signedCode > linearCodeMax;
        excludedMask = ismember(signedCode, excludedSignedCodes);
        fitMask = fitMask & ~belowMask & ~aboveMask & ~excludedMask;
        exclusionReason(belowMask) = "below_linear_region";
        exclusionReason(aboveMask) = "above_linear_region_or_saturated";
        exclusionReason(excludedMask) = "excluded_known_anomaly";

    case "all"
        % Keep only data-quality filtering above.

    otherwise
        error("fitCodeMode must be linearRegion or all.");
end

exclusionReason(fitMask) = "used";
end

function [diagnosticTable, diagnosticSummary, diagnosticCalibration] = ...
    makeSignedPeakDiagnosticResults(measurementTable, analysisInterfaceName, ...
    dataDir, toneFreqHz, hardwareGain, dacCodeBits, fitCodeMode, ...
    linearCodeMin, linearCodeMax, excludedSignedCodes, minSineFitR2)
%makeSignedPeakDiagnosticResults - 生成旧 signed-peak 诊断结果

diagnosticTable = measurementTable;
[fitMask, exclusionReason] = selectFitPoints(diagnosticTable, fitCodeMode, ...
    linearCodeMin, linearCodeMax, excludedSignedCodes, minSineFitR2);

diagnosticTable.signed_peak_fit_used = fitMask;
diagnosticTable.signed_peak_exclusion_reason = exclusionReason;
diagnosticTable.fitted_signed_output_peak_v = NaN(height(diagnosticTable), 1);
diagnosticTable.residual_signed_output_peak_v = NaN(height(diagnosticTable), 1);

if nnz(fitMask) < 2
    diagnosticCalibration = emptyCalibration();
else
    diagnosticCalibration = fitLinearCalibration( ...
        diagnosticTable.signed_code(fitMask), ...
        diagnosticTable.signed_output_peak_v(fitMask));
    diagnosticTable.fitted_signed_output_peak_v(fitMask) = ...
        diagnosticCalibration.yFit;
    diagnosticTable.residual_signed_output_peak_v(fitMask) = ...
        diagnosticCalibration.residual;
end

diagnosticSummary = makeSummaryTable(analysisInterfaceName, dataDir, ...
    toneFreqHz, hardwareGain, dacCodeBits, fitCodeMode, linearCodeMin, ...
    linearCodeMax, excludedSignedCodes, diagnosticTable, fitMask, ...
    diagnosticCalibration);
end

function calibration = emptyCalibration()
%emptyCalibration - 返回无有效拟合时使用的 NaN 标定结构
calibration = struct( ...
    "slope", NaN, ...
    "intercept", NaN, ...
    "codePerV", NaN, ...
    "codeAtZeroAmplitude", NaN, ...
    "yFit", [], ...
    "residual", [], ...
    "residualRms", NaN, ...
    "maxAbsResidual", NaN, ...
    "r2", NaN);
end

function calibration = fitLinearCalibration(code, signedOutputPeak)
%fitLinearCalibration - 拟合输出峰值与 DAC 有符号码的线性关系
x = code(:);
y = signedOutputPeak(:);
p = polyfit(x, y, 1);
yFit = polyval(p, x);
residual = y - yFit;
sse = sum(residual.^2);
sst = sum((y - mean(y)).^2);

calibration.slope = p(1);
calibration.intercept = p(2);
calibration.codePerV = 1 / p(1);
calibration.codeAtZeroAmplitude = -p(2) / p(1);
calibration.yFit = yFit;
calibration.residual = residual;
calibration.residualRms = sqrt(mean(residual.^2));
calibration.maxAbsResidual = max(abs(residual));
if sst > 0
    calibration.r2 = 1 - sse / sst;
else
    calibration.r2 = NaN;
end
end

function summaryTable = makeSummaryTable(analysisInterfaceName, dataDir, ...
    toneFreqHz, hardwareGain, dacCodeBits, fitCodeMode, ...
    linearCodeMin, linearCodeMax, excludedSignedCodes, ...
    measurementTable, fitMask, calibration)
%makeSummaryTable - 汇总旧 signed-peak 诊断拟合设置和质量

summaryTable = table( ...
    string(analysisInterfaceName), string(dataDir), toneFreqHz, hardwareGain, ...
    dacCodeBits, string(fitCodeMode), linearCodeMin, linearCodeMax, ...
    formatNumberList(excludedSignedCodes), height(measurementTable), nnz(fitMask), ...
    calibration.slope, calibration.intercept, calibration.codePerV, ...
    calibration.codeAtZeroAmplitude, calibration.r2, calibration.residualRms, ...
    calibration.maxAbsResidual, ...
    sprintf("signed_output_peak = %.12g * signed_code %+.12g", ...
    calibration.slope, calibration.intercept), ...
    sprintf("signed_code = (signed_output_peak - (%+.12g)) / %.12g", ...
    calibration.intercept, calibration.slope), ...
    'VariableNames', {'analysis_interface', 'data_dir', 'tone_freq_hz', ...
    'hardware_gain', 'dac_code_bits', 'fit_code_mode', ...
    'linear_code_min', 'linear_code_max', ...
    'excluded_signed_codes', 'total_file_count', 'fit_point_count', ...
    'signed_output_peak_slope_v_per_signed_code', ...
    'signed_output_peak_intercept_v', ...
    'signed_code_per_v_signed_output_peak', ...
    'signed_code_at_zero_signed_output_peak', ...
    'r2', 'signed_output_peak_residual_rms_v', 'max_abs_residual_v', ...
    'forward_formula', 'inverse_formula'});
end

function vppFitSummary = makeVppFitSummaryTable(analysisInterfaceName, dataDir, ...
    toneFreqHz, hardwareGain, dacCodeBits, mainCalibrationMode, ...
    dacCodeVppDefinition, outputVppMethod, fitCodeMode, linearCodeMin, ...
    linearCodeMax, minCodeVppForFit, maxCodeVppForFit, ...
    excludedSignedCodes, measurementTable, fitMask, calibration)
%makeVppFitSummaryTable - 汇总主 DAC Vpp-Codepp 标定结果

vppFitSummary = table( ...
    string(analysisInterfaceName), string(dataDir), toneFreqHz, hardwareGain, ...
    dacCodeBits, string(mainCalibrationMode), string(dacCodeVppDefinition), ...
    string(outputVppMethod), string(fitCodeMode), linearCodeMin, ...
    linearCodeMax, minCodeVppForFit, maxCodeVppForFit, ...
    formatNumberList(excludedSignedCodes), nnz(fitMask), ...
    height(measurementTable), calibration.slope, calibration.slope * 1e6, ...
    calibration.intercept, calibration.codePerV, calibration.r2, ...
    calibration.residualRms, calibration.maxAbsResidual, ...
    sprintf("output_vpp = %.12g * dac_code_vpp %+.12g", ...
    calibration.slope, calibration.intercept), ...
    sprintf("dac_code_vpp = (output_vpp - (%+.12g)) / %.12g", ...
    calibration.intercept, calibration.slope), ...
    'VariableNames', {'analysis_interface', 'data_dir', 'tone_freq_hz', ...
    'hardware_gain', 'dac_code_bits', 'main_calibration_mode', ...
    'dac_code_vpp_definition', 'output_vpp_method', 'fit_code_mode', ...
    'linear_code_min', 'linear_code_max', 'min_code_vpp_for_fit', ...
    'max_code_vpp_for_fit', 'excluded_signed_codes', 'fit_file_count', ...
    'total_file_count', 'slope_vpp_per_code', 'slope_uV_per_code', ...
    'intercept_vpp', 'code_per_v', 'r2', 'residual_rms_vpp', ...
    'max_abs_residual_vpp', 'forward_formula', 'inverse_formula'});
end

function textValue = formatNumberList(values)
%formatNumberList - 将数值列表格式化为可写入汇总表的文本
if isempty(values)
    textValue = "";
else
    textValue = strjoin(string(values(:).'), ",");
end
end

function saveVppCalibrationPlot(measurementTable, fitMask, calibration, ...
    analysisInterfaceName, outputVppMethod, plotPath, showFigure, autoExportPlot, ...
    imageDpi)
%saveVppCalibrationPlot - 绘制主标定线、排除文件和残差

if showFigure
    visibleState = "on";
else
    visibleState = "off";
end

figureHandle = figure("Name", "DAC Vpp-code_vpp scale - " + analysisInterfaceName, ...
    "Visible", visibleState, "Color", "w");
tiledlayout(2, 1, "TileSpacing", "compact");

nexttile;
hold on;
legendHandles = gobjects(0);
legendLabels = {};

usedHandle = scatter(measurementTable.dac_code_vpp(fitMask), ...
    measurementTable.selected_output_vpp(fitMask), 60, "filled");
legendHandles(end+1) = usedHandle;
legendLabels{end+1} = "fit point";

if any(~fitMask)
    excludedHandle = scatter(measurementTable.dac_code_vpp(~fitMask), ...
        measurementTable.selected_output_vpp(~fitMask), ...
        65, "x", "LineWidth", 1.4);
    legendHandles(end+1) = excludedHandle;
    legendLabels{end+1} = "excluded point";
end

xFit = linspace(min(measurementTable.dac_code_vpp(fitMask)), ...
    max(measurementTable.dac_code_vpp(fitMask)), 300).';
yFit = calibration.slope * xFit + calibration.intercept;
fitHandle = plot(xFit, yFit, "r-", "LineWidth", 1.4);
legendHandles(end+1) = fitHandle;
legendLabels{end+1} = "linear fit";

grid on;
xlabel("DAC code Vpp (code)");
ylabel("DAC output Vpp (V)");
title(sprintf("%s DAC 1 kHz Vpp-code_vpp scale", analysisInterfaceName), ...
    "Interpreter", "none");
legend(legendHandles, legendLabels, "Location", "best");
addVppFitEquationText(calibration, nnz(fitMask), outputVppMethod);

nexttile;
stem(measurementTable.dac_code_vpp(fitMask), ...
    measurementTable.residual_vpp(fitMask), "filled");
grid on;
xlabel("DAC code Vpp (code)");
ylabel("Residual (Vpp)");
title(sprintf("Residual RMS = %.6g Vpp", calibration.residualRms));

if autoExportPlot
    axesHandles = findall(figureHandle, "Type", "axes");
    for i = 1:numel(axesHandles)
        try
            axesHandles(i).Toolbar.Visible = "off";
        catch
        end
    end

    try
        exportgraphics(figureHandle, plotPath, "Resolution", imageDpi);
    catch
        saveas(figureHandle, plotPath);
    end
end

if ~showFigure
    close(figureHandle);
end
end

function addVppFitEquationText(calibration, fitFileCount, outputVppMethod)
%addVppFitEquationText - 在当前坐标轴标注方程和拟合质量
equationText = sprintf(['output Vpp = %.6g * dac code Vpp %+.6g\n', ...
    'dac code Vpp = (output Vpp - (%+.6g)) / %.6g\n', ...
    'Scale = %.6g uV/code\nR^2 = %.6f\nResidual RMS = %.6g Vpp\n', ...
    'N = %d, method = %s'], ...
    calibration.slope, calibration.intercept, calibration.intercept, ...
    calibration.slope, calibration.slope * 1e6, calibration.r2, ...
    calibration.residualRms, fitFileCount, outputVppMethod);

text(0.03, 0.97, equationText, "Units", "normalized", ...
    "VerticalAlignment", "top", "HorizontalAlignment", "left", ...
    "BackgroundColor", "w", "EdgeColor", [0.35 0.35 0.35], ...
    "Margin", 7, "FontName", "Consolas", "Interpreter", "none");
end

function writtenPath = writeTableSafe(tbl, targetPath)
%writeTableSafe - 目标被占用时改写到带时间戳的新 CSV
targetPath = char(string(targetPath));
try
    writetable(tbl, targetPath, 'Encoding', 'UTF-8');
    writtenPath = targetPath;
catch ME
    [folder, stem, ext] = fileparts(targetPath);
    timestamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    fallbackPath = fullfile(folder, [stem '_' timestamp ext]);
    warning("Cannot write %s. Writing fallback %s instead. Original error: %s", ...
        targetPath, fallbackPath, ME.message);
    writetable(tbl, fallbackPath, 'Encoding', 'UTF-8');
    writtenPath = fallbackPath;
end
end

function message = makePlotPathMessage(autoExportPlot, plotPath)
%makePlotPathMessage - 生成图像已导出或未导出的控制台说明
if autoExportPlot
    message = plotPath;
else
    message = "<disabled>";
end
end

function safeName = safeFileStem(name)
%safeFileStem - 将通道或分析名称转换为安全文件名
safeName = regexprep(char(string(name)), "[^\w\-.]", "_");
safeName = regexprep(safeName, "_+", "_");
safeName = strtrim(safeName);
if isempty(safeName)
    safeName = "dac_sine";
end
end

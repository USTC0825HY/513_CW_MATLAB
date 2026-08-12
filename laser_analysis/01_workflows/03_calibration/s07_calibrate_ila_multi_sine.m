%s07_calibrate_ila_multi_sine - 执行 ADC 多点 Vpp-Codepp 正式标定
%   s07_calibrate_ila_multi_sine 从多组信号源幅度和 ILA 正弦 CSV 中，
%   为 ADC 通道拟合 input_vpp 与 code_vpp 的线性关系：
%       input_vpp = slope_vpp_per_code*code_vpp + intercept_vpp
%
%   每个 CSV 贡献一个主标定点。推荐 codeVppMethod='sineFit'，因为
%   正弦拟合比单个最大/最小样本更不易受噪声影响。正负峰值结果仅
%   作为诊断证据，不应与主 Vpp-Codepp 斜率混用。
%
%   输入文件名可包含 dBm、Vpp 或 mVpp，例如 -10dBm.csv、
%   0.1Vpp.csv、100mVpp.csv。负 dBm 表示功率电平，不表示负极性。
%   使用 dBm 时必须核对 inputImpedanceOhm 和信号源实际参考面。
%
%   calibrationReferencePlane 决定输出斜率属于 adc_input 还是
%   source_input。frontEndGainToAdc 表示 ADC 输入 Vpp/source Vpp；
%   改变参考面时必须同步核对增益，避免后续噪声换算再次除增益。
%
%   主拟合会排除接近码轨、Codepp 太小/太大或 R^2 低于 minR2 的
%   文件。被排除点仍保留在 measurements 和诊断表中，便于追溯。
%   修改筛选规则时应先检查 fit_exclusion_reason 和残差图。
%
%   无环境变量时脚本弹窗多选 CSV。批处理可设置：
%       S07_DATA_DIR       - 输入 CSV 目录
%       S07_INTERFACE      - 通道名称
%       S07_REFERENCE_PLANE - adc_input 或 source_input
%       S07_EXCLUDE_FILES  - 分号分隔的排除文件
%       S07_MIN_R2         - 正弦拟合最低 R^2
%       S07_OUTPUT_SUBDIR  - 输出子目录名
%
%   输出的 parameters、measurements、fit summary、诊断表、图和 MAT
%   带同一时间戳，应成组保存和引用。正式分析通常只使用主拟合斜率。
%
%   Example:
%       setenv('S07_DATA_DIR','F:\path\replace_with_calibration_csv')
%       setenv('S07_INTERFACE','JG15')
%       s07_calibrate_ila_multi_sine
%
%   See also s06_calibrate_ila_single_sine,
%   s09_analyze_ad_input_equiv_noise_new_flow

clear;
clc;

%% ======================== User parameters ========================

paths = laser_test_paths();
initialDir = paths.codeRoot;
outFolderName = 'multi_sine_ad_calibrate';
batchOutputSubdir = strtrim(getenv('S07_OUTPUT_SUBDIR'));
if ~isempty(batchOutputSubdir)
    outFolderName = batchOutputSubdir;
end

% Interface/channel name used in plot titles and exported file names.
analysisInterfaceName = 'JG15';
batchInterfaceName = strtrim(getenv('S07_INTERFACE'));
if ~isempty(batchInterfaceName)
    analysisInterfaceName = batchInterfaceName;
end

% Main Vpp-code_vpp calibration. This is the result used by later noise
% conversion because noise scaling depends on the slope, not on peak polarity.
mainCalibrationMode = 'vpp_code_vpp';
calibrationReferencePlane = 'adc_input';  % 'adc_input' or 'source_input'
frontEndGainToAdc = 1.8;                  % Vpp at ADC input / source Vpp
batchDataDir = strtrim(getenv('S07_DATA_DIR'));
batchReferencePlane = strtrim(getenv('S07_REFERENCE_PLANE'));
if ~isempty(batchReferencePlane)
    calibrationReferencePlane = batchReferencePlane;
end
manualExcludeFileNames = strings(0, 1);
batchExcludeFiles = strtrim(getenv('S07_EXCLUDE_FILES'));
if ~isempty(batchExcludeFiles)
    manualExcludeFileNames = strip(split(string(batchExcludeFiles), ';'));
    manualExcludeFileNames(manualExcludeFileNames == "") = [];
end

% Old signed positive/negative peak mode is kept as a diagnostic table only.
adPointMode = 'positiveNegativePeaks';

% ILA CSV layout. dataCol=4 matches the usual ILA export where code is in
% the fourth column. validCol=[] means every row after the header is used.
dataCol = 4;
validCol = [];
validValue = 1;
firstDataRow = 'auto';
dataRadix = 'decimal';       % 'decimal' or 'hex'

% ADC/FPGA code format.
fs = 100e6;                  % Hz
adcBits = 16;
outputCoding = 'twos_complement';
% outputCoding:
%   'twos_complement' : signed decimal values or raw two's-complement words
%   'offset_binary'   : raw ADC bus where mid-scale is zero
%   'unipolar'        : straight binary, useful for unipolar converters

% Input sine frequency. Use [] to estimate it by FFT for each CSV.
toneFreqHz = 1e6;
retryAutoFreqIfR2Low = true;
minR2 = 0.98;
batchMinR2 = strtrim(getenv('S07_MIN_R2'));
if ~isempty(batchMinR2)
    parsedMinR2 = str2double(batchMinR2);
    if ~isfinite(parsedMinR2) || parsedMinR2 <= 0 || parsedMinR2 > 1
        error('S07_MIN_R2 must be a finite number in the interval (0, 1].');
    end
    minR2 = parsedMinR2;
end

% Main code_vpp estimator. sineFit is recommended because it is less
% sensitive to single-sample noise than min/max.
codeVppMethod = 'sineFit';       % 'sineFit', 'peakMean', or 'minMax'
peakDiagnosticMethod = 'peakMean';
peakMeanFraction = 0.02;         % fraction used by the peakMean estimator

% Known signal-generator level for each selected CSV.
%   'auto_from_filename' : parse either Vpp/mVpp or dBm from every filename
%   'vpp_from_filename'  : require Vpp/mVpp in every filename
%   'dbm_from_filename'  : require dBm in every filename
%   'vpp'                : use inputVppList or prompt for Vpp values
%   'dbm_50ohm'          : use inputLevelDbmList or prompt for dBm values
inputMode = 'auto_from_filename';
inputImpedanceOhm = 50;
inputVppList = [];
inputLevelDbmList = [];
sortInputFilesByLevel = true;

% Main fit file screening. Files close to ADC full scale are marked excluded
% so clipped sine waves do not bias the Vpp-code_vpp slope.
clipMarginCode = 512;
maxCodeVppForFit = 0.90 * 2^adcBits;
minCodeVppForFit = 512;

% Keep false for normal calibration. Set true only when the relationship
% must pass exactly through the origin.
forceZeroIntercept = false;

% Plot/export controls.
showCalibrationPlot = true;
autoExportCalibrationPlot = true;
plotImageDpi = 300;
if ~isempty(batchDataDir)
    showCalibrationPlot = false;
end

%% ======================== Main workflow ========================

validateTopLevelOptions(mainCalibrationMode, adPointMode, ...
    calibrationReferencePlane, codeVppMethod, peakDiagnosticMethod);

if isempty(batchDataDir)
    [fileNames, dataDir] = selectCsvFiles(initialDir);
else
    dataDir = batchDataDir;
    fileInfo = dir(fullfile(dataDir, '*.csv'));
    fileInfo = fileInfo(~strcmpi({fileInfo.name}, 'asset_manifest.csv'));
    if isempty(fileInfo)
        error('No calibration CSV files found in batch data directory: %s', dataDir);
    end
    fileNames = {fileInfo.name};
end
fileNames = normalizeFileNames(fileNames);
fileCount = numel(fileNames);

[knownInputVpp, inputLevelDbm, inputLevelSource] = resolveKnownInputVpp( ...
    inputMode, inputVppList, inputLevelDbmList, fileCount, fileNames, ...
    inputImpedanceOhm);

if sortInputFilesByLevel
    [~, order] = sort(knownInputVpp);
    fileNames = fileNames(order);
    knownInputVpp = knownInputVpp(order);
    inputLevelDbm = inputLevelDbm(order);
    inputLevelSource = inputLevelSource(order);
end

outDir = fullfile(dataDir, outFolderName);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
outputNamePrefix = safeFileStem(sprintf('%s_ad_vpp_code_vpp_scale', ...
    analysisInterfaceName));

fileRows = repmat(emptyFileRow(), fileCount, 1);
pointRows = repmat(emptyCalibrationPointRow(), fileCount * 2, 1);
pointIndex = 0;

for k = 1:fileCount
    inPath = fullfile(dataDir, fileNames{k});
    fprintf('\n[%d/%d] Processing %s\n', k, fileCount, inPath);

    fileRows(k) = analyzeIlaSineFile(inPath, dataCol, validCol, validValue, ...
        firstDataRow, dataRadix, fs, adcBits, outputCoding, toneFreqHz, ...
        retryAutoFreqIfR2Low, minR2, peakDiagnosticMethod, ...
        peakMeanFraction);

    sourceInfo = dir(inPath);
    fileRows(k).source_file = string(fileNames{k});
    fileRows(k).source_path = string(inPath);
    fileRows(k).source_size_bytes = sourceInfo.bytes;
    fileRows(k).source_modified_time = string(datetime(sourceInfo.datenum, ...
        'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    fileRows(k).source_sha256 = localSha256(inPath);
    fileRows(k).source_input_vpp = knownInputVpp(k);
    fileRows(k).known_input_vpp = knownInputVpp(k);
    fileRows(k).known_input_peak_v = knownInputVpp(k) / 2;
    fileRows(k).front_end_gain_to_adc = frontEndGainToAdc;
    fileRows(k).target_reference_plane = string(calibrationReferencePlane);
    fileRows(k).target_input_vpp = resolveTargetInputVpp(knownInputVpp(k), ...
        calibrationReferencePlane, frontEndGainToAdc);
    fileRows(k).input_level_dbm = inputLevelDbm(k);
    fileRows(k).input_level_source = inputLevelSource(k);
    fileRows(k).code_vpp_method = string(codeVppMethod);
    fileRows(k).selected_code_vpp = selectCodeVppForMainFit(fileRows(k), ...
        codeVppMethod);
    fileRows(k).clip_flag = isCodeClipped(fileRows(k).max_code, ...
        fileRows(k).min_code, adcBits, clipMarginCode);

    pointIndex = pointIndex + 1;
    pointRows(pointIndex) = makeCalibrationPointRow(fileRows(k), 1, ...
        peakDiagnosticMethod);

    pointIndex = pointIndex + 1;
    pointRows(pointIndex) = makeCalibrationPointRow(fileRows(k), -1, ...
        peakDiagnosticMethod);
end

fileMeasurementTable = struct2table(fileRows);
fileMeasurementTable.analysis_interface = repmat(string(analysisInterfaceName), ...
    height(fileMeasurementTable), 1);
fileMeasurementTable = movevars(fileMeasurementTable, 'analysis_interface', ...
    'Before', 'source_file');

peakDiagnosticTable = struct2table(pointRows);
peakDiagnosticTable.analysis_interface = repmat(string(analysisInterfaceName), ...
    height(peakDiagnosticTable), 1);
peakDiagnosticTable = movevars(peakDiagnosticTable, 'analysis_interface', ...
    'Before', 'source_file');

manualExcludeMask = ismember(lower(fileMeasurementTable.source_file), ...
    lower(manualExcludeFileNames));
autoFitMask = isfinite(fileMeasurementTable.selected_code_vpp) ...
    & isfinite(fileMeasurementTable.target_input_vpp) ...
    & fileMeasurementTable.r2 >= minR2 ...
    & fileMeasurementTable.selected_code_vpp >= minCodeVppForFit ...
    & fileMeasurementTable.selected_code_vpp < maxCodeVppForFit ...
    & ~fileMeasurementTable.clip_flag;
fitMask = autoFitMask & ~manualExcludeMask;

fileMeasurementTable.manual_exclude = manualExcludeMask;
fileMeasurementTable.fit_exclusion_reason = strings(height(fileMeasurementTable), 1);
for rowIndex = 1:height(fileMeasurementTable)
    reasonParts = strings(0, 1);
    if fileMeasurementTable.r2(rowIndex) < minR2
        reasonParts(end + 1) = sprintf('sine fit R2 < %.3g', minR2);
    end
    if fileMeasurementTable.selected_code_vpp(rowIndex) < minCodeVppForFit
        reasonParts(end + 1) = 'code Vpp below fit minimum';
    end
    if fileMeasurementTable.selected_code_vpp(rowIndex) >= maxCodeVppForFit
        reasonParts(end + 1) = 'code Vpp above fit maximum';
    end
    if fileMeasurementTable.clip_flag(rowIndex)
        reasonParts(end + 1) = 'near ADC code rail';
    end
    if manualExcludeMask(rowIndex)
        reasonParts(end + 1) = 'manual quality screening';
    end
    fileMeasurementTable.fit_exclusion_reason(rowIndex) = ...
        strjoin(reasonParts, '; ');
end

if nnz(fitMask) < 2
    error(['Fewer than two usable AD Vpp fit files. Check minR2, clipping, ', ...
        'code_vpp limits, frequency, code format, and input level filenames.']);
end

vppCalibration = fitLinearCalibration( ...
    fileMeasurementTable.selected_code_vpp(fitMask), ...
    fileMeasurementTable.target_input_vpp(fitMask), forceZeroIntercept);

fileMeasurementTable.fit_used = fitMask;
fileMeasurementTable.fitted_input_vpp = NaN(height(fileMeasurementTable), 1);
fileMeasurementTable.residual_vpp = NaN(height(fileMeasurementTable), 1);
fileMeasurementTable.fitted_input_vpp(fitMask) = vppCalibration.yFit;
fileMeasurementTable.residual_vpp(fitMask) = vppCalibration.residual;

vppFitSummary = makeVppFitSummaryTable(analysisInterfaceName, ...
    mainCalibrationMode, calibrationReferencePlane, frontEndGainToAdc, ...
    inputMode, inputImpedanceOhm, codeVppMethod, fileCount, fitMask, ...
    vppCalibration, forceZeroIntercept, minR2, minCodeVppForFit, ...
    maxCodeVppForFit, clipMarginCode);
vppFitSummary.manual_excluded_files = repmat( ...
    strjoin(manualExcludeFileNames, ';'), height(vppFitSummary), 1);
hashManifest = strjoin(fileMeasurementTable.source_file + "=" + ...
    fileMeasurementTable.source_sha256, ';');
vppFitSummary.input_sha256_manifest = repmat(hashManifest, ...
    height(vppFitSummary), 1);

[peakDiagnosticTable, peakDiagnosticSummary, peakDiagnosticCalibration] = ...
    makePeakDiagnosticResults(peakDiagnosticTable, analysisInterfaceName, ...
    inputMode, inputImpedanceOhm, peakDiagnosticMethod, fileCount, ...
    minR2, forceZeroIntercept, peakMeanFraction);

timestamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
measurementPath = fullfile(outDir, ...
    [outputNamePrefix '_vpp_measurements_' timestamp '.csv']);
summaryPath = fullfile(outDir, ...
    [outputNamePrefix '_vpp_fit_summary_' timestamp '.csv']);
plotPath = fullfile(outDir, [outputNamePrefix '_vpp_fit_' timestamp '.png']);
matResultPath = fullfile(outDir, ...
    [outputNamePrefix '_result_' timestamp '.mat']);
parameterPath = fullfile(outDir, ...
    [outputNamePrefix '_analysis_parameters_' timestamp '.csv']);

measurementPath = writeTableSafe(fileMeasurementTable, measurementPath);
summaryPath = writeTableSafe(vppFitSummary, summaryPath);
localWriteCalibrationParameters(parameterPath, analysisInterfaceName, ...
    dataDir, outDir, fs, adcBits, outputCoding, codeVppMethod, ...
    calibrationReferencePlane, frontEndGainToAdc, inputImpedanceOhm, ...
    vppCalibration, hashManifest);
saveVppCalibrationPlot(fileMeasurementTable, fitMask, vppCalibration, ...
    analysisInterfaceName, calibrationReferencePlane, frontEndGainToAdc, ...
    codeVppMethod, plotPath, showCalibrationPlot, autoExportCalibrationPlot, ...
    plotImageDpi);
save(matResultPath, "fileMeasurementTable", "vppFitSummary", ...
    "vppCalibration", "peakDiagnosticTable", "peakDiagnosticSummary", ...
    "peakDiagnosticCalibration");

fprintf('\n=== AD Vpp-code_vpp calibration: %s ===\n', analysisInterfaceName);
fprintf('Reference plane         : %s\n', calibrationReferencePlane);
fprintf('Front-end gain to ADC   : %.12g\n', frontEndGainToAdc);
fprintf('code_vpp method         : %s\n', codeVppMethod);
fprintf('Fit files               : %d / %d\n', nnz(fitMask), fileCount);
fprintf('Excluded files          : %d\n', fileCount - nnz(fitMask));
fprintf('input_vpp = %.12g * code_vpp %+.12g\n', ...
    vppCalibration.slope, vppCalibration.intercept);
fprintf('code_vpp = (input_vpp - (%+.12g)) / %.12g\n', ...
    vppCalibration.intercept, vppCalibration.slope);
fprintf('Scale                   : %.9g uV/code\n', ...
    vppCalibration.slope * 1e6);
fprintf('R2                      : %.9g\n', vppCalibration.r2);
fprintf('Residual RMS            : %.9g Vpp\n', vppCalibration.residualRms);
if abs(frontEndGainToAdc - 1.8) < 1e-12
    expectedSourceScaleUv = 2.25 / frontEndGainToAdc / 2^adcBits * 1e6;
    expectedAdcScaleUv = 2.25 / 2^adcBits * 1e6;
    fprintf('Expected source scale   : %.9g uV/code\n', expectedSourceScaleUv);
    fprintf('Expected ADC scale      : %.9g uV/code\n', expectedAdcScaleUv);
end
fprintf('Measurement CSV         : %s\n', measurementPath);
fprintf('Summary CSV             : %s\n', summaryPath);
fprintf('Parameters CSV          : %s\n', parameterPath);
fprintf('Result MAT              : %s\n', matResultPath);
fprintf('Plot PNG                : %s\n', ...
    makePlotPathMessage(autoExportCalibrationPlot, plotPath));

%% ======================== Local functions ========================

function validateTopLevelOptions(mainCalibrationMode, adPointMode, ...
    calibrationReferencePlane, codeVppMethod, peakDiagnosticMethod)
%validateTopLevelOptions - 验证主标定口径、参考面和诊断方法组合
if ~strcmpi(mainCalibrationMode, 'vpp_code_vpp')
    error("mainCalibrationMode must be 'vpp_code_vpp' for this script.");
end

if ~strcmpi(adPointMode, 'positiveNegativePeaks')
    error("adPointMode must be 'positiveNegativePeaks' for diagnostics.");
end

validReferencePlanes = ["adc_input", "source_input"];
if ~ismember(lower(string(calibrationReferencePlane)), validReferencePlanes)
    error("calibrationReferencePlane must be 'adc_input' or 'source_input'.");
end

validateCodeVppMethod(codeVppMethod, 'codeVppMethod');
validateCodeVppMethod(peakDiagnosticMethod, 'peakDiagnosticMethod');
end

function validateCodeVppMethod(method, nameForError)
%validateCodeVppMethod - 检查 Codepp 估计方法是否在支持列表内
validMethods = ["sinefit", "peakmean", "minmax"];
if ~ismember(lower(string(method)), validMethods)
    error("%s must be 'sineFit', 'peakMean', or 'minMax'.", nameForError);
end
end

function row = emptyFileRow()
%emptyFileRow - 返回单个输入文件测量结果的预分配结构
row = struct( ...
    'source_file', string(missing), ...
    'source_path', string(missing), ...
    'source_size_bytes', NaN, ...
    'source_modified_time', string(missing), ...
    'source_sha256', string(missing), ...
    'source_input_vpp', NaN, ...
    'known_input_vpp', NaN, ...
    'known_input_peak_v', NaN, ...
    'front_end_gain_to_adc', NaN, ...
    'target_reference_plane', string(missing), ...
    'target_input_vpp', NaN, ...
    'input_level_dbm', NaN, ...
    'input_level_source', string(missing), ...
    'code_vpp_method', string(missing), ...
    'sample_count', NaN, ...
    'fs_hz', NaN, ...
    'fit_freq_hz', NaN, ...
    'fit_freq_source', string(missing), ...
    'samples_per_period', NaN, ...
    'selected_positive_code_peak', NaN, ...
    'selected_negative_code_peak', NaN, ...
    'selected_code_vpp', NaN, ...
    'fit_code_amplitude_code', NaN, ...
    'fit_code_positive_peak_code', NaN, ...
    'fit_code_negative_peak_code', NaN, ...
    'fit_code_vpp', NaN, ...
    'peak_mean_code_vpp', NaN, ...
    'positive_peak_mean_code', NaN, ...
    'negative_peak_mean_code', NaN, ...
    'peak_mean_count', NaN, ...
    'minmax_code_vpp', NaN, ...
    'max_code', NaN, ...
    'min_code', NaN, ...
    'code_offset_code', NaN, ...
    'residual_rms_code', NaN, ...
    'r2', NaN, ...
    'clip_flag', false, ...
    'fit_used', false, ...
    'fitted_input_vpp', NaN, ...
    'residual_vpp', NaN);
end

function localWriteCalibrationParameters(outPath, analysisInterfaceName, ...
        dataDir, outDir, fs, adcBits, outputCoding, codeVppMethod, ...
        calibrationReferencePlane, frontEndGainToAdc, inputImpedanceOhm, ...
        calibration, hashManifest)
%localWriteCalibrationParameters - 导出标定配置、斜率和源文件哈希
parameter = ["analysis_name"; "script"; "source_directory"; ...
    "output_directory"; "sampling_rate"; "adc_bits"; "output_coding"; ...
    "calibration_method"; "reference_plane"; "front_end_gain_to_adc"; ...
    "source_impedance"; "slope"; "intercept"; "r2"; ...
    "input_SHA256_manifest"];
value = [string(analysisInterfaceName) + " AD Vpp-Codepp calibration"; ...
    string(mfilename('fullpath')); string(dataDir); string(outDir); ...
    string(fs); string(adcBits); string(outputCoding); string(codeVppMethod); ...
    string(calibrationReferencePlane); string(frontEndGainToAdc); ...
    string(inputImpedanceOhm); string(calibration.slope); ...
    string(calibration.intercept); string(calibration.r2); hashManifest];
unit = [""; ""; ""; ""; "Hz"; "bit"; ""; ""; ""; "ratio"; ...
    "ohm"; "V/code"; "Vpp"; ""; ""];
parameterTable = table(parameter, value, unit);
writetable(parameterTable, outPath, 'Encoding', 'UTF-8');
end

function hash = localSha256(filePath)
%localSha256 - 调用系统工具计算输入文件 SHA-256
escapedPath = strrep(char(filePath), '"', '""');
[status, output] = system(sprintf('certutil -hashfile "%s" SHA256', escapedPath));
if status ~= 0
    warning('Unable to calculate SHA-256 for %s.', filePath);
    hash = "";
    return;
end
token = regexp(output, '[0-9A-Fa-f]{64}', 'match', 'once');
if isempty(token)
    warning('Unable to parse SHA-256 output for %s.', filePath);
    hash = "";
else
    hash = lower(string(token));
end
end

function row = emptyCalibrationPointRow()
%emptyCalibrationPointRow - 返回正负峰值诊断点的预分配结构
row = struct( ...
    'source_file', string(missing), ...
    'point_polarity', NaN, ...
    'known_input_vpp', NaN, ...
    'target_input_peak_v', NaN, ...
    'signed_adc_code_peak', NaN, ...
    'fit_used', false, ...
    'file_r2', NaN, ...
    'measurement_method', string(missing), ...
    'residual_v', NaN, ...
    'fitted_input_peak_v', NaN, ...
    'input_level_dbm', NaN, ...
    'input_level_source', string(missing), ...
    'target_reference_plane', string(missing), ...
    'target_input_vpp', NaN, ...
    'fit_freq_hz', NaN, ...
    'sample_count', NaN, ...
    'selected_code_vpp', NaN, ...
    'positive_code_peak', NaN, ...
    'negative_code_peak', NaN, ...
    'code_offset_code', NaN, ...
    'file_residual_rms_code', NaN);
end

function pointRow = makeCalibrationPointRow(fileRow, polarity, measurementMethod)
%makeCalibrationPointRow - 从文件结果构造一个极性的诊断标定点
pointRow = emptyCalibrationPointRow();
pointRow.source_file = fileRow.source_file;
pointRow.point_polarity = polarity;
pointRow.known_input_vpp = fileRow.known_input_vpp;
pointRow.target_input_peak_v = polarity * fileRow.target_input_vpp / 2;
pointRow.fit_used = false;
pointRow.file_r2 = fileRow.r2;
pointRow.measurement_method = string(measurementMethod);
pointRow.input_level_dbm = fileRow.input_level_dbm;
pointRow.input_level_source = fileRow.input_level_source;
pointRow.target_reference_plane = fileRow.target_reference_plane;
pointRow.target_input_vpp = fileRow.target_input_vpp;
pointRow.fit_freq_hz = fileRow.fit_freq_hz;
pointRow.sample_count = fileRow.sample_count;
pointRow.selected_code_vpp = fileRow.selected_positive_code_peak ...
    - fileRow.selected_negative_code_peak;
pointRow.positive_code_peak = fileRow.selected_positive_code_peak;
pointRow.negative_code_peak = fileRow.selected_negative_code_peak;
pointRow.code_offset_code = fileRow.code_offset_code;
pointRow.file_residual_rms_code = fileRow.residual_rms_code;

if polarity > 0
    pointRow.signed_adc_code_peak = fileRow.selected_positive_code_peak;
else
    pointRow.signed_adc_code_peak = fileRow.selected_negative_code_peak;
end
end

function targetInputVpp = resolveTargetInputVpp(sourceInputVpp, ...
    calibrationReferencePlane, frontEndGainToAdc)
%resolveTargetInputVpp - 把信号源 Vpp 换算到选定标定参考面
switch lower(strtrim(char(calibrationReferencePlane)))
    case 'source_input'
        targetInputVpp = sourceInputVpp;
    case 'adc_input'
        targetInputVpp = sourceInputVpp * frontEndGainToAdc;
    otherwise
        error("calibrationReferencePlane must be 'adc_input' or 'source_input'.");
end
end

function selectedCodeVpp = selectCodeVppForMainFit(fileRow, codeVppMethod)
%selectCodeVppForMainFit - 按配置选择主拟合使用的 Codepp 估计量
switch lower(strtrim(char(codeVppMethod)))
    case 'sinefit'
        selectedCodeVpp = fileRow.fit_code_vpp;
    case 'peakmean'
        selectedCodeVpp = fileRow.peak_mean_code_vpp;
    case 'minmax'
        selectedCodeVpp = fileRow.minmax_code_vpp;
    otherwise
        error("codeVppMethod must be 'sineFit', 'peakMean', or 'minMax'.");
end
end

function clipFlag = isCodeClipped(maxCode, minCode, adcBits, clipMarginCode)
%isCodeClipped - 根据 ADC 码轨和安全余量识别可能削顶的记录
positiveLimit = 2^(adcBits - 1) - 1 - clipMarginCode;
negativeLimit = -2^(adcBits - 1) + clipMarginCode;
clipFlag = ~(maxCode < positiveLimit && minCode > negativeLimit);
end

function result = analyzeIlaSineFile(inPath, dataCol, validCol, validValue, ...
    firstDataRow, dataRadix, fs, adcBits, outputCoding, toneFreqHz, ...
    retryAutoFreqIfR2Low, minR2, measurementMethod, peakMeanFraction)
%analyzeIlaSineFile - 解析单个 ILA CSV 并计算正弦及峰值指标

rawCell = readcell(inPath, 'Delimiter', ',');
dataColIndex = resolveColumn(rawCell, dataCol, 'dataCol');
validColIndex = resolveOptionalColumn(rawCell, validCol, 'validCol');
dataStartRow = resolveFirstDataRow(rawCell, firstDataRow);

rawWords = rawCell(dataStartRow:end, dataColIndex);
rawCode = parseCodeColumn(rawWords, dataRadix, adcBits);

if isempty(validColIndex)
    validMask = true(size(rawCode));
else
    validValues = rawCell(dataStartRow:end, validColIndex);
    validMask = parseNumericColumn(validValues) == validValue;
end

validMask = validMask & isfinite(rawCode);
rawCode = rawCode(validMask);

if numel(rawCode) < 16
    error("Too few valid ILA samples in %s: %d.", inPath, numel(rawCode));
end

signedCode = convertToSignedCode(rawCode, adcBits, outputCoding);
signedCode = signedCode(:);
t = (0:numel(signedCode)-1).' / fs;

if isempty(toneFreqHz)
    fitFreqHz = estimateSineFrequency(signedCode, fs);
    fitFreqSource = "FFT auto estimate";
else
    fitFreqHz = toneFreqHz;
    fitFreqSource = "manual parameter";
end

codeFit = fitSineAtFixedFrequency(t, signedCode, fitFreqHz);

if codeFit.r2 < minR2 && retryAutoFreqIfR2Low && ~isempty(toneFreqHz)
    retryFreqHz = estimateSineFrequency(signedCode, fs);
    retryFit = fitSineAtFixedFrequency(t, signedCode, retryFreqHz);
    if retryFit.r2 > codeFit.r2
        fitFreqHz = retryFreqHz;
        fitFreqSource = "FFT retry after low R2";
        codeFit = retryFit;
    end
end

peak = estimatePeakMeanVpp(signedCode, peakMeanFraction);
[selectedPositivePeak, selectedNegativePeak] = selectCodePeaks( ...
    measurementMethod, codeFit, peak, signedCode);
selectedCodeVpp = selectedPositivePeak - selectedNegativePeak;

result = emptyFileRow();
result.sample_count = numel(signedCode);
result.fs_hz = fs;
result.fit_freq_hz = fitFreqHz;
result.fit_freq_source = fitFreqSource;
result.samples_per_period = fs / fitFreqHz;
result.selected_positive_code_peak = selectedPositivePeak;
result.selected_negative_code_peak = selectedNegativePeak;
result.selected_code_vpp = selectedCodeVpp;
result.fit_code_amplitude_code = codeFit.amplitude;
result.fit_code_positive_peak_code = codeFit.positivePeak;
result.fit_code_negative_peak_code = codeFit.negativePeak;
result.fit_code_vpp = codeFit.vpp;
result.peak_mean_code_vpp = peak.vpp;
result.positive_peak_mean_code = peak.positivePeakMean;
result.negative_peak_mean_code = peak.negativePeakMean;
result.peak_mean_count = peak.count;
result.minmax_code_vpp = max(signedCode) - min(signedCode);
result.max_code = max(signedCode);
result.min_code = min(signedCode);
result.code_offset_code = codeFit.offset;
result.residual_rms_code = codeFit.residualRms;
result.r2 = codeFit.r2;
end

function [positivePeak, negativePeak] = selectCodePeaks(method, ...
    codeFit, peak, signedCode)
%selectCodePeaks - 为诊断表选择 sineFit、peakMean 或 minMax 峰值
switch lower(strtrim(char(method)))
    case 'sinefit'
        positivePeak = codeFit.positivePeak;
        negativePeak = codeFit.negativePeak;
    case 'peakmean'
        positivePeak = peak.positivePeakMean;
        negativePeak = peak.negativePeakMean;
    case 'minmax'
        positivePeak = max(signedCode);
        negativePeak = min(signedCode);
    otherwise
        error("measurementMethod must be 'peakMean', 'sineFit', or 'minMax'.");
end
end

function [fileNames, dataDir] = selectCsvFiles(initialDir)
%selectCsvFiles - 通过 GUI 选择一个或多个标定 CSV
[fileNames, dataDir] = uigetfile({'*.csv', 'Vivado ILA CSV files (*.csv)'}, ...
    'Select ILA CSV files', initialDir, 'MultiSelect', 'on');
if isequal(fileNames, 0)
    error("No CSV files selected.");
end
end

function fileNames = normalizeFileNames(fileNames)
%normalizeFileNames - 将单文件或多文件选择统一为行 cell 数组
if ischar(fileNames) || isstring(fileNames)
    fileNames = cellstr(fileNames);
end
fileNames = fileNames(:);
end

function [knownInputVpp, inputLevelDbm, inputLevelSource] = ...
    resolveKnownInputVpp(inputMode, inputVppList, inputLevelDbmList, ...
    fileCount, fileNames, impedanceOhm)
%resolveKnownInputVpp - 从文件名、列表或交互输入解析每个源电平

mode = lower(strtrim(char(inputMode)));
knownInputVpp = NaN(fileCount, 1);
inputLevelDbm = NaN(fileCount, 1);
inputLevelSource = strings(fileCount, 1);

switch mode
    case {'auto_from_filename', 'vpp_from_filename', ...
            'dbm_from_filename', 'dbm_50ohm_from_filename'}
        for i = 1:fileCount
            [knownInputVpp(i), inputLevelDbm(i), inputLevelSource(i)] = ...
                parseKnownInputLevelFromFileName(fileNames{i}, mode, ...
                impedanceOhm);
        end

    case 'vpp'
        values = inputVppList;
        if isempty(values)
            values = promptNumericList(fileCount, fileNames, 'Vpp');
        end
        knownInputVpp = normalizeLevelList(values, fileCount, 'inputVppList');
        inputLevelSource(:) = "Vpp list";

    case 'dbm_50ohm'
        values = inputLevelDbmList;
        if isempty(values)
            values = promptNumericList(fileCount, fileNames, 'dBm');
        end
        inputLevelDbm = normalizeLevelList(values, fileCount, ...
            'inputLevelDbmList');
        knownInputVpp = dbmToVpp(inputLevelDbm, impedanceOhm);
        inputLevelSource(:) = sprintf("dBm list %.6g ohm", impedanceOhm);

    otherwise
        error(['inputMode must be ''auto_from_filename'', ', ...
            '''vpp_from_filename'', ''dbm_from_filename'', ''vpp'', ', ...
            'or ''dbm_50ohm''.']);
end

knownInputVpp = knownInputVpp(:);
inputLevelDbm = inputLevelDbm(:);
inputLevelSource = inputLevelSource(:);

if any(~isfinite(knownInputVpp) | knownInputVpp <= 0)
    error("All signal-generator Vpp values must be finite positive numbers.");
end
end

function [knownInputVpp, inputLevelDbm, inputLevelSource] = ...
    parseKnownInputLevelFromFileName(fileName, mode, impedanceOhm)
%parseKnownInputLevelFromFileName - 从文件名读取 Vpp/mVpp 或 dBm

vppValue = parseVppFromFileName(fileName);
dbmValue = parseDbmFromFileName(fileName);

switch mode
    case 'auto_from_filename'
        if isfinite(vppValue) && isfinite(dbmValue)
            error("Filename has both Vpp and dBm levels; keep only one: %s", ...
                fileName);
        elseif isfinite(vppValue)
            knownInputVpp = vppValue;
            inputLevelDbm = NaN;
            inputLevelSource = "Vpp filename";
        elseif isfinite(dbmValue)
            knownInputVpp = dbmToVpp(dbmValue, impedanceOhm);
            inputLevelDbm = dbmValue;
            inputLevelSource = sprintf("dBm filename %.6g ohm", impedanceOhm);
        else
            error("Cannot parse Vpp or dBm level from filename: %s.", fileName);
        end

    case 'vpp_from_filename'
        if ~isfinite(vppValue)
            error("Cannot parse Vpp level from filename: %s.", fileName);
        end
        knownInputVpp = vppValue;
        inputLevelDbm = NaN;
        inputLevelSource = "Vpp filename";

    case {'dbm_from_filename', 'dbm_50ohm_from_filename'}
        if ~isfinite(dbmValue)
            error("Cannot parse dBm level from filename: %s.", fileName);
        end
        knownInputVpp = dbmToVpp(dbmValue, impedanceOhm);
        inputLevelDbm = dbmValue;
        inputLevelSource = sprintf("dBm filename %.6g ohm", impedanceOhm);

    otherwise
        error("Unsupported filename input mode: %s.", mode);
end
end

function inputVpp = parseVppFromFileName(fileName)
%parseVppFromFileName - 从文件名提取 Vpp 或 mVpp 数值
token = regexp(fileName, ...
    '([-+]?\d+(?:\.\d+)?)\s*(m?v)\s*p\s*p', ...
    'tokens', 'once', 'ignorecase');

if isempty(token)
    inputVpp = NaN;
    return;
end

value = str2double(token{1});
unitText = lower(token{2});
if startsWith(unitText, 'mv')
    inputVpp = value / 1000;
else
    inputVpp = value;
end
end

function levelDbm = parseDbmFromFileName(fileName)
%parseDbmFromFileName - 从文件名提取带符号的 dBm 电平
token = regexp(fileName, '([-+]?\d+(?:\.\d+)?)\s*d\s*b\s*m', ...
    'tokens', 'once', 'ignorecase');
if isempty(token)
    levelDbm = NaN;
else
    levelDbm = str2double(token{1});
end
end

function inputVpp = dbmToVpp(levelDbm, impedanceOhm)
%dbmToVpp - 按指定阻抗把正弦功率电平换算为 Vpp
powerW = 10.^((levelDbm(:) - 30) / 10);
vrms = sqrt(powerW * impedanceOhm);
inputVpp = 2 * sqrt(2) * vrms;
end

function values = promptNumericList(fileCount, fileNames, unitText)
%promptNumericList - 请求用户按文件顺序输入一组标定电平
exampleText = repmat("0.1", 1, fileCount);
for i = 1:fileCount
    exampleText(i) = sprintf('%.3g', i * 0.1);
end

message = sprintf(['Enter %d signal-generator levels in %s. The order must ', ...
    'match the selected CSV files:\n\n%s\n\nExample: %s'], ...
    fileCount, unitText, strjoin(string(fileNames), newline), ...
    strjoin(exampleText, ', '));

answer = inputdlg(message, ['Input levels in ' unitText], [1 90]);
if isempty(answer)
    error("No signal-generator level list was entered.");
end

values = sscanf(strrep(answer{1}, ',', ' '), '%f').';
end

function values = normalizeLevelList(values, fileCount, listName)
%normalizeLevelList - 验证手动电平列表的长度和有限性
values = values(:);
if isscalar(values) && fileCount > 1
    values = repmat(values, fileCount, 1);
end

if numel(values) ~= fileCount
    error("%s has %d value(s), but there are %d CSV file(s).", ...
        listName, numel(values), fileCount);
end
end

function rowIndex = resolveFirstDataRow(rawCell, firstDataRow)
%resolveFirstDataRow - 按手动值或 Radix 行确定首个数据行
if isnumeric(firstDataRow)
    rowIndex = firstDataRow;
    return;
end

rowIndex = 2;
if size(rawCell, 1) >= 2
    row2col1 = cellText(rawCell{2, 1});
    if strncmpi(row2col1, 'Radix', 5)
        rowIndex = 3;
    end
end
end

function colIndex = resolveOptionalColumn(rawCell, colSpec, nameForError)
%resolveOptionalColumn - 解析可以留空的 valid 列配置
if isempty(colSpec) || (ischar(colSpec) && isempty(strtrim(colSpec)))
    colIndex = [];
else
    colIndex = resolveColumn(rawCell, colSpec, nameForError);
end
end

function colIndex = resolveColumn(rawCell, colSpec, nameForError)
%resolveColumn - 将列号或表头名称解析为 CSV 列索引
if isnumeric(colSpec)
    colIndex = colSpec;
    if colIndex < 1 || colIndex > size(rawCell, 2)
        error("%s column index is out of range: %d.", nameForError, colIndex);
    end
    return;
end

target = strtrim(char(colSpec));
header = rawCell(1, :);
headerText = cellfun(@cellText, header, 'UniformOutput', false);
match = find(strcmp(headerText, target), 1);

if isempty(match)
    error("Cannot find header '%s' for %s. Use a numeric column index.", ...
        target, nameForError);
end
colIndex = match;
end

function code = parseCodeColumn(values, radix, adcBits)
%parseCodeColumn - 按数据进制将 CSV 单元格解析为 ADC 码
code = NaN(numel(values), 1);
radix = lower(strtrim(char(radix)));

for i = 1:numel(values)
    textValue = cellText(values{i});
    if isempty(textValue)
        continue;
    end

    switch radix
        case 'hex'
            textValue = regexprep(textValue, '\s+', '');
            if startsWith(lower(textValue), '0x')
                textValue = textValue(3:end);
            end
            if all(isstrprop(textValue, 'xdigit'))
                code(i) = mod(hex2dec(textValue), 2^adcBits);
            end

        case 'decimal'
            value = str2double(textValue);
            if isfinite(value)
                code(i) = round(value);
            end

        otherwise
            error("dataRadix must be 'hex' or 'decimal'.");
    end
end
end

function values = parseNumericColumn(rawValues)
%parseNumericColumn - 将 valid 等辅助列解析为 double 向量
values = NaN(numel(rawValues), 1);
for i = 1:numel(rawValues)
    values(i) = str2double(cellText(rawValues{i}));
end
end

function signedCode = convertToSignedCode(rawCode, adcBits, outputCoding)
%convertToSignedCode - 按码型把原始码转换为有符号 ADC 码
rawCode = double(rawCode(:));

switch lower(strtrim(char(outputCoding)))
    case 'offset_binary'
        rawUnsigned = mod(rawCode, 2^adcBits);
        signedCode = rawUnsigned - 2^(adcBits - 1);

    case 'twos_complement'
        if any(rawCode < 0)
            signedCode = rawCode;
        else
            rawUnsigned = mod(rawCode, 2^adcBits);
            signedCode = rawUnsigned;
            wrapMask = signedCode >= 2^(adcBits - 1);
            signedCode(wrapMask) = signedCode(wrapMask) - 2^adcBits;
        end

    case 'unipolar'
        signedCode = mod(rawCode, 2^adcBits);

    otherwise
        error("outputCoding must be 'offset_binary', 'twos_complement', or 'unipolar'.");
end
end

function freqHz = estimateSineFrequency(y, fs)
%estimateSineFrequency - 用加窗 FFT 估计记录中的主正弦频率
y = y(:) - mean(y(:), 'omitnan');
n = numel(y);
if n < 4
    error("Too few samples to estimate sine frequency.");
end

window = 0.5 - 0.5 * cos(2 * pi * (0:n-1).' / max(n - 1, 1));
spectrum = abs(fft(y .* window));
halfN = floor(n / 2);
spectrum(1) = 0;
[~, idx] = max(spectrum(1:halfN));
freqHz = (idx - 1) * fs / n;

if ~isfinite(freqHz) || freqHz <= 0
    error("Cannot estimate sine frequency. Set toneFreqHz manually.");
end
end

function fit = fitSineAtFixedFrequency(t, y, freqHz)
%fitSineAtFixedFrequency - 在线性 sin/cos 基上拟合正弦和直流偏置
y = y(:);
w = 2 * pi * freqHz;
X = [sin(w * t(:)), cos(w * t(:)), ones(numel(t), 1)];
coef = X \ y;

fit.freqHz = freqHz;
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

function peak = estimatePeakMeanVpp(y, peakMeanFraction)
%estimatePeakMeanVpp - 用两端样本均值估计抗单点噪声的峰值
y = sort(y(:));
n = numel(y);
count = max(1, round(n * peakMeanFraction));
count = min(count, floor(n / 2));

lowPeak = y(1:count);
highPeak = y(end-count+1:end);

peak.negativePeakMean = mean(lowPeak);
peak.positivePeakMean = mean(highPeak);
peak.vpp = peak.positivePeakMean - peak.negativePeakMean;
peak.count = count;
end

function calibration = fitLinearCalibration(signedAdcCodePeak, ...
    targetInputPeakV, forceZeroIntercept)
%fitLinearCalibration - 拟合电压-码值直线并计算残差质量指标
x = signedAdcCodePeak(:);
y = targetInputPeakV(:);

if forceZeroIntercept
    slope = x \ y;
    intercept = 0;
    yFit = slope * x;
else
    p = polyfit(x, y, 1);
    slope = p(1);
    intercept = p(2);
    yFit = polyval(p, x);
end

residual = y - yFit;
sse = sum(residual.^2);
sst = sum((y - mean(y)).^2);

calibration.slope = slope;
calibration.intercept = intercept;
calibration.codePerV = 1 / slope;
calibration.adcCodeAtZeroInput = -intercept / slope;
calibration.inputPeakAtZeroCode = intercept;
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

function vppFitSummary = makeVppFitSummaryTable(analysisInterfaceName, ...
    mainCalibrationMode, calibrationReferencePlane, frontEndGainToAdc, ...
    inputMode, inputImpedanceOhm, codeVppMethod, fileCount, fitMask, ...
    calibration, forceZeroIntercept, minR2, minCodeVppForFit, ...
    maxCodeVppForFit, clipMarginCode)
%makeVppFitSummaryTable - 汇总主 Vpp-Codepp 拟合口径和质量

vppFitSummary = table(string(analysisInterfaceName), ...
    string(mainCalibrationMode), string(calibrationReferencePlane), ...
    frontEndGainToAdc, string(inputMode), inputImpedanceOhm, ...
    string(codeVppMethod), nnz(fitMask), fileCount, calibration.slope, ...
    calibration.slope * 1e6, calibration.intercept, calibration.codePerV, ...
    calibration.r2, calibration.residualRms, calibration.maxAbsResidual, ...
    forceZeroIntercept, minR2, minCodeVppForFit, maxCodeVppForFit, ...
    clipMarginCode, ...
    sprintf("input_vpp = %.12g * code_vpp %+.12g", ...
    calibration.slope, calibration.intercept), ...
    sprintf("code_vpp = (input_vpp - (%+.12g)) / %.12g", ...
    calibration.intercept, calibration.slope), ...
    'VariableNames', {'analysis_interface', 'main_calibration_mode', ...
    'target_reference_plane', 'front_end_gain_to_adc', 'input_mode', ...
    'input_impedance_ohm', 'code_vpp_method', 'fit_file_count', ...
    'total_file_count', 'slope_vpp_per_code', 'slope_uV_per_code', ...
    'intercept_vpp', 'code_per_v', 'r2', 'residual_rms_vpp', ...
    'max_abs_residual_vpp', 'force_zero_intercept', 'min_r2', ...
    'min_code_vpp_for_fit', 'max_code_vpp_for_fit', 'clip_margin_code', ...
    'forward_formula', 'inverse_formula'});
end

function [peakDiagnosticTable, peakDiagnosticSummary, calibration] = ...
    makePeakDiagnosticResults(peakDiagnosticTable, analysisInterfaceName, ...
    inputMode, inputImpedanceOhm, measurementMethod, fileCount, minR2, ...
    forceZeroIntercept, peakMeanFraction)
%makePeakDiagnosticResults - 生成正负峰值诊断拟合，不替代主结果

fitMask = isfinite(peakDiagnosticTable.signed_adc_code_peak) ...
    & isfinite(peakDiagnosticTable.target_input_peak_v) ...
    & peakDiagnosticTable.file_r2 >= minR2;

peakDiagnosticTable.fit_used = fitMask;
peakDiagnosticTable.fitted_input_peak_v = NaN(height(peakDiagnosticTable), 1);
peakDiagnosticTable.residual_v = NaN(height(peakDiagnosticTable), 1);

if nnz(fitMask) < 2
    calibration = struct('slope', NaN, 'intercept', NaN, 'codePerV', NaN, ...
        'adcCodeAtZeroInput', NaN, 'inputPeakAtZeroCode', NaN, ...
        'yFit', [], 'residual', [], 'residualRms', NaN, ...
        'maxAbsResidual', NaN, 'r2', NaN);
    peakDiagnosticSummary = makePeakDiagnosticSummaryTable( ...
        analysisInterfaceName, inputMode, inputImpedanceOhm, measurementMethod, ...
        height(peakDiagnosticTable), fileCount, fitMask, calibration, ...
        forceZeroIntercept, minR2, peakMeanFraction);
    return;
end

calibration = fitLinearCalibration( ...
    peakDiagnosticTable.signed_adc_code_peak(fitMask), ...
    peakDiagnosticTable.target_input_peak_v(fitMask), forceZeroIntercept);

peakDiagnosticTable.fitted_input_peak_v(fitMask) = calibration.yFit;
peakDiagnosticTable.residual_v(fitMask) = calibration.residual;

peakDiagnosticSummary = makePeakDiagnosticSummaryTable( ...
    analysisInterfaceName, inputMode, inputImpedanceOhm, measurementMethod, ...
    height(peakDiagnosticTable), fileCount, fitMask, calibration, ...
    forceZeroIntercept, minR2, peakMeanFraction);
end

function diagnosticSummary = makePeakDiagnosticSummaryTable( ...
    analysisInterfaceName, inputMode, inputImpedanceOhm, measurementMethod, ...
    totalPointCount, fileCount, fitMask, calibration, forceZeroIntercept, ...
    minR2, peakMeanFraction)
%makePeakDiagnosticSummaryTable - 汇总峰值诊断拟合的设置和质量

diagnosticSummary = table(string(analysisInterfaceName), ...
    "positiveNegativePeaks", string(inputMode), inputImpedanceOhm, ...
    string(measurementMethod), nnz(fitMask), totalPointCount, fileCount, ...
    calibration.slope, calibration.intercept, calibration.codePerV, ...
    calibration.adcCodeAtZeroInput, calibration.inputPeakAtZeroCode, ...
    calibration.r2, calibration.residualRms, calibration.maxAbsResidual, ...
    forceZeroIntercept, minR2, peakMeanFraction, ...
    sprintf("input_peak_v = %.12g * adc_code_peak %+.12g", ...
    calibration.slope, calibration.intercept), ...
    sprintf("adc_code_peak = (input_peak_v - (%+.12g)) / %.12g", ...
    calibration.intercept, calibration.slope), ...
    'VariableNames', {'analysis_interface', 'diagnostic_mode', ...
    'input_mode', 'input_impedance_ohm', 'measurement_method', ...
    'fit_point_count', 'total_point_count', 'total_file_count', ...
    'slope_v_per_code', 'intercept_v', 'code_per_v', ...
    'signed_adc_code_at_zero_input', 'input_peak_at_zero_code_v', ...
    'r2', 'residual_rms_v', 'max_abs_residual_v', ...
    'force_zero_intercept', 'min_r2', 'peak_mean_fraction', ...
    'forward_formula', 'inverse_formula'});
end

function saveVppCalibrationPlot(fileMeasurementTable, fitMask, calibration, ...
    analysisInterfaceName, calibrationReferencePlane, frontEndGainToAdc, ...
    codeVppMethod, plotPath, showFigure, autoExportPlot, imageDpi)
%saveVppCalibrationPlot - 绘制主标定线、排除点和残差证据

if showFigure
    visibleState = 'on';
else
    visibleState = 'off';
end

figureHandle = figure('Name', ...
    ['AD Vpp-code_vpp calibration - ' char(analysisInterfaceName)], ...
    'Visible', visibleState, 'Color', 'w', ...
    'Position', [100, 100, 1500, 900]);
layoutHandle = tiledlayout(2, 3, 'TileSpacing', 'compact', ...
    'Padding', 'compact');

dataAxes = nexttile(layoutHandle, [1, 2]);
hold(dataAxes, 'on');
legendHandles = gobjects(0);
legendLabels = {};

usedHandle = scatter(dataAxes, fileMeasurementTable.selected_code_vpp(fitMask), ...
    fileMeasurementTable.target_input_vpp(fitMask), 60, 'filled');
legendHandles(end+1) = usedHandle;
legendLabels{end+1} = 'used point';

if any(~fitMask)
    excludedHandle = scatter(dataAxes, ...
        fileMeasurementTable.selected_code_vpp(~fitMask), ...
        fileMeasurementTable.target_input_vpp(~fitMask), ...
        60, 'x', 'LineWidth', 1.4);
    legendHandles(end+1) = excludedHandle;
    legendLabels{end+1} = 'excluded point';
end

xFit = linspace(min(fileMeasurementTable.selected_code_vpp(fitMask)), ...
    max(fileMeasurementTable.selected_code_vpp(fitMask)), 300).';
yFit = calibration.slope * xFit + calibration.intercept;
fitHandle = plot(dataAxes, xFit, yFit, 'r-', 'LineWidth', 1.4);
legendHandles(end+1) = fitHandle;
legendLabels{end+1} = 'linear fit';

pointLabels = erase(fileMeasurementTable.source_file, '.csv');
text(dataAxes, fileMeasurementTable.selected_code_vpp, ...
    fileMeasurementTable.target_input_vpp, "  " + pointLabels, ...
    'FontSize', 8, 'Color', [0.25 0.25 0.25], ...
    'Interpreter', 'none', 'Clipping', 'on');

grid(dataAxes, 'on');
xlabel(dataAxes, 'ADC code Vpp (code)');
ylabel(dataAxes, 'Input Vpp (V)');
title(dataAxes, sprintf('%s AD Vpp-code_vpp calibration', ...
    analysisInterfaceName), ...
    'Interpreter', 'none');
legend(dataAxes, legendHandles, legendLabels, 'Location', 'best');

infoAxes = nexttile(layoutHandle);
axis(infoAxes, 'off');
addVppFitEquationText(infoAxes, calibration, nnz(fitMask), ...
    calibrationReferencePlane, ...
    frontEndGainToAdc, codeVppMethod);

residualAxes = nexttile(layoutHandle, [1, 3]);
stem(residualAxes, fileMeasurementTable.selected_code_vpp(fitMask), ...
    fileMeasurementTable.residual_vpp(fitMask), 'filled');
grid(residualAxes, 'on');
xlabel(residualAxes, 'ADC code Vpp (code)');
ylabel(residualAxes, 'Residual (Vpp)');
title(residualAxes, sprintf('Residual RMS = %.6g Vpp', ...
    calibration.residualRms));

if autoExportPlot
    try
        exportgraphics(figureHandle, plotPath, 'Resolution', imageDpi);
    catch
        saveas(figureHandle, plotPath);
    end
end

if ~showFigure
    close(figureHandle);
end
end

function addVppFitEquationText(targetAxes, calibration, fitFileCount, ...
    calibrationReferencePlane, frontEndGainToAdc, codeVppMethod)
%addVppFitEquationText - 在图中标注方程、R^2、参考面和拟合点数

equationText = sprintf(['Vpp = %.6g * code_vpp %+.6g\n', ...
    'code_vpp = (Vpp - (%+.6g)) / %.6g\n', ...
    'Scale = %.6g uV/code\nR^2 = %.6f\nResidual RMS = %.6g Vpp\n', ...
    'N = %d\nreference plane = %s\nfront-end gain = %.6g\nmethod = %s'], ...
    calibration.slope, calibration.intercept, calibration.intercept, ...
    calibration.slope, calibration.slope * 1e6, calibration.r2, ...
    calibration.residualRms, fitFileCount, calibrationReferencePlane, ...
    frontEndGainToAdc, codeVppMethod);

text(targetAxes, 0.02, 0.98, equationText, 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
    'FontSize', 10, 'FontName', 'Consolas', 'Interpreter', 'none');
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
    message = '<disabled>';
end
end

function safeName = safeFileStem(name)
%safeFileStem - 将通道或分析名称转换为安全文件名
safeName = regexprep(char(string(name)), '[^\w\-.]', '_');
safeName = regexprep(safeName, '_+', '_');
safeName = strtrim(safeName);
if isempty(safeName)
    safeName = 'ad_interface';
end
end

function textValue = cellText(value)
%cellText - 将 CSV 单元格统一转换为去空白文本
if isCellMissing(value)
    textValue = '';
elseif isnumeric(value) || islogical(value)
    textValue = sprintf('%.15g', double(value));
else
    textValue = strtrim(char(value));
end
end

function tf = isCellMissing(value)
%isCellMissing - 统一判断空值、missing 和 NaN 单元格
try
    tf = ismissing(value);
    tf = all(tf(:));
catch
    tf = false;
end
end

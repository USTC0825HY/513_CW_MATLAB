%s06_calibrate_ila_single_sine - 用单个 ILA 正弦记录诊断 ADC 刻度
%   s06_calibrate_ila_single_sine 选择一个 ILA CSV，解析 ADC 码，
%   对已知频率或自动估计频率的正弦波做最小二乘拟合，并比较已知
%   输入 Vpp 与拟合 Codepp，得到单工作点的电压/码值比例。
%
%   本脚本适合快速检查 dataCol、dataRadix、outputCoding、采样率、
%   输入幅度和通道是否正确。单点结果不能证明全量程线性，也不能
%   可靠识别截距；正式标定应使用 s07_calibrate_ila_multi_sine。
%
%   CSV 可以用列号或表头指定数据列及 valid 列。dataRadix 必须和
%   导出内容一致；outputCoding 决定 offset binary、two's complement
%   或 unipolar 的码值解释。错误的码型通常会造成波形跳变或 R^2 很低。
%
%   toneFreqHz 为空时由 FFT 估计主频；填写手动频率时，若 R^2 低且
%   retryAutoFreqIfR2Low 为 true，脚本会自动估频后重试。R^2 反映
%   正弦模型对当前记录的解释程度，不等同于 ADC 全量程线性度。
%
%   inputMode 可使用 50 ohm 下的 dBm 或直接 Vpp。使用 dBm 时必须
%   确认信号源、终端和参考面确实为 50 ohm。输出包括结果 CSV、
%   标定曲线 CSV、正弦拟合图和码值-电压曲线图。
%
%   Example:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       s06_calibrate_ila_single_sine
%
%   See also s07_calibrate_ila_multi_sine, fft, readcell

clear;
clc;

%% ======================== 用户参数区：通常只改这里 ========================

% 文件选择窗口初始目录。
paths = laser_test_paths();
initialDir = fullfile(paths.codeRoot, 'ref', 'virtual_data');

% ILA 数据列。截图中目标数据在第 4 列 D。
dataCol = 4;

% valid 列。没有 valid 列就写 []；如果有 valid 列，填列号或表头。
validCol = [];
validValue = 1;

% 数据从第几行开始：
%   'auto'：第 1 行表头，第 2 行数据；若第 2 行是 Radix，则第 3 行数据。
%   如果 CSV 没有表头，手动改成 1。
firstDataRow = 'auto';

% 数据列进制：
%   'decimal'：十进制，例如 14841、15267 或 -123。
%   'hex'    ：十六进制，例如 030b、0314。
dataRadix = 'decimal';

% ADC/FPGA 数据参数。
fs = 100e6;                 % 采样率，单位 Hz。
adcBits = 16;
inputRangeVpp = 2.25;       % LTC2208 PGA=0: 2.25 Vpp；PGA=1 改 1.50。

% 码型：
%   'twos_complement'：ILA 列已经是 +/- 有符号数据，或二补码原始字。
%   'offset_binary'  ：LTC2208 原始总线，MODE=GND，0x8000 对应 0V。
%   'unipolar'       ：0 到满量程的直二进制 ADC。
outputCoding = 'twos_complement';

% 输入正弦频率。
%   []   : 自动用 FFT 估计主频，推荐默认用这个，避免频率填错导致 R2=0。
%   1e6  : 已知输入是 1 MHz 时可手动填写。
%   10e6 : 已知输入是 10 MHz 时可手动填写。
toneFreqHz = [];

% 如果手动频率拟合失败，是否自动估计频率并重试一次。
retryAutoFreqIfR2Low = true;

% 输入信号幅度：
%   'dBm_50ohm'：用 inputLevel_dBm 按 50 欧正弦换算输入 Vpp。
%   'vpp'      ：直接使用 inputVpp。
inputMode = 'dBm_50ohm';
inputLevel_dBm = 6;         % 0 dBm @ 50 ohm -> 约 0.63246 Vpp。
inputVpp = NaN;             % inputMode='vpp' 时填写，例如 inputVpp = 0.63246。
                            % inputMode='dBm_50ohm' 时保持 NaN 即可，脚本会由 dBm 自动换算。

% 拟合质量门限。低于该值时通常说明频率、码型、采样率或数据列配置不对。
minR2 = 0.98;

% 码值-电压刻度曲线点数。曲线覆盖当前 CSV 中实际出现的 signed code 范围。
calibrationCurvePoints = 1001;

%% ======================== 主流程：一般不用改 ========================

[fileName, dataDir] = uigetfile({'*.csv', 'Vivado ILA CSV files (*.csv)'}, ...
    '请选择一个 ILA CSV 文件', initialDir, 'MultiSelect', 'off');
if isequal(fileName, 0)
    error('已取消文件选择，未处理任何 CSV 文件。');
end

inPath = fullfile(dataDir, fileName);
[~, stem, ~] = fileparts(inPath);
outDir = fullfile(dataDir, 'single_sine_calibrate');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

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
    error('有效数据点太少：%d。请检查数据列和 valid 配置。', numel(rawCode));
end

[adcVoltage, signedCode, lsbV] = codeToVoltage(rawCode, adcBits, inputRangeVpp, outputCoding);
adcVoltage = adcVoltage(:);
signedCode = signedCode(:);
t = (0:numel(adcVoltage)-1).' / fs;

if isempty(toneFreqHz)
    fitFreqHz = estimateSineFrequency(adcVoltage, fs);
    fitFreqSource = 'FFT auto estimate';
else
    fitFreqHz = toneFreqHz;
    fitFreqSource = 'manual parameter';
end

voltageFit = fitSineAtFixedFrequency(t, adcVoltage, fitFreqHz);
codeFit = fitSineAtFixedFrequency(t, signedCode, fitFreqHz);

if voltageFit.r2 < minR2 && retryAutoFreqIfR2Low
    retryFreqHz = estimateSineFrequency(adcVoltage, fs);
    retryVoltageFit = fitSineAtFixedFrequency(t, adcVoltage, retryFreqHz);

    if retryVoltageFit.r2 > voltageFit.r2
        warning(['当前频率 %.6g Hz 拟合质量低，R2=%.5g。', ...
            ' 已自动改用 FFT 估计频率 %.6g Hz，R2=%.5g。'], ...
            fitFreqHz, voltageFit.r2, retryFreqHz, retryVoltageFit.r2);
        fitFreqHz = retryFreqHz;
        fitFreqSource = 'FFT retry after low R2';
        voltageFit = retryVoltageFit;
        codeFit = fitSineAtFixedFrequency(t, signedCode, fitFreqHz);
    end
end

knownInputVpp = getKnownInputVpp(inputMode, inputLevel_dBm, inputVpp);
fitSampleCount = numel(signedCode);
samplesPerPeriod = fs / fitFreqHz;
uniquePhaseCount = countUniqueSamplePhases(fitSampleCount, fitFreqHz, fs);

codePerInputV = codeFit.vpp / knownInputVpp;
adcVPerInputV = voltageFit.vpp / knownInputVpp;
inputVPerCode = knownInputVpp / codeFit.vpp;
codeOffset = codeFit.offset;
calibrationSlope = inputVPerCode;
calibrationIntercept = -codeOffset * inputVPerCode;

rawMinMaxVppCode = max(rawCode) - min(rawCode);
signedMinMaxVppCode = max(signedCode) - min(signedCode);
adcMinMaxVpp = max(adcVoltage) - min(adcVoltage);

calibrationCurve = makeCalibrationCurve(signedCode, calibrationSlope, ...
    calibrationIntercept, lsbV, calibrationCurvePoints);

fprintf('\n=== Single Sine Calibration ===\n');
fprintf('File                    : %s\n', inPath);
fprintf('Samples                 : %d\n', numel(adcVoltage));
fprintf('fs                      : %.12g Hz\n', fs);
fprintf('Fit frequency           : %.12g Hz\n', fitFreqHz);
fprintf('Fit frequency source    : %s\n', fitFreqSource);
fprintf('Samples used in fit     : %d\n', fitSampleCount);
fprintf('Samples per period      : %.9g\n', samplesPerPeriod);
fprintf('Unique sample phases    : %d\n', uniquePhaseCount);
fprintf('Known input Vpp         : %.9g Vpp\n', knownInputVpp);
fprintf('Fit Vpp                 : %.9g codepp\n', codeFit.vpp);
fprintf('Fit ADC Vpp             : %.9g Vpp\n', voltageFit.vpp);
fprintf('Raw min-max Vpp         : %.9g codepp\n', rawMinMaxVppCode);
fprintf('Signed min-max Vpp      : %.9g codepp\n', signedMinMaxVppCode);
fprintf('ADC min-max Vpp         : %.9g Vpp\n', adcMinMaxVpp);
fprintf('code_per_input_v        : %.9g code/V\n', codePerInputV);
fprintf('adc_v_per_input_v       : %.9g V/V\n', adcVPerInputV);
fprintf('input_v_per_code        : %.9g V/code\n', inputVPerCode);
fprintf('code offset             : %.9g code\n', codeOffset);
fprintf('calibration formula     : input_v = %.9g * signed_code %+.9g\n', ...
    calibrationSlope, calibrationIntercept);
fprintf('offset                  : %.9g V\n', voltageFit.offset);
fprintf('phase                   : %.9g rad\n', voltageFit.phaseRad);
fprintf('residual RMS            : %.9g V\n', voltageFit.residualRms);
fprintf('R2                      : %.9g\n', voltageFit.r2);
fprintf('LSB                     : %.9g V/code\n', lsbV);

if voltageFit.r2 < minR2
    warning('R2 = %.5f < %.5f，拟合质量偏低。请检查 toneFreqHz、fs、outputCoding、dataCol。', ...
        voltageFit.r2, minR2);
end

result = table({fileName}, numel(adcVoltage), fs, fitFreqHz, {fitFreqSource}, ...
    fitSampleCount, samplesPerPeriod, uniquePhaseCount, ...
    knownInputVpp, codeFit.vpp, voltageFit.vpp, ...
    rawMinMaxVppCode, signedMinMaxVppCode, adcMinMaxVpp, ...
    codePerInputV, adcVPerInputV, inputVPerCode, codeOffset, ...
    calibrationSlope, calibrationIntercept, ...
    voltageFit.offset, voltageFit.phaseRad, voltageFit.residualRms, ...
    voltageFit.r2, lsbV, ...
    'VariableNames', {'input_file', 'sample_count', 'fs_hz', 'fit_freq_hz', ...
    'fit_freq_source', 'fit_sample_count', 'samples_per_period', 'unique_sample_phases', ...
    'known_input_vpp', 'fit_vpp_code', 'fit_vpp_adc_v', ...
    'raw_minmax_vpp_code', 'signed_minmax_vpp_code', 'adc_minmax_vpp_v', ...
    'code_per_input_v', 'adc_v_per_input_v', 'input_v_per_code', ...
    'code_offset_code', 'calibration_slope_v_per_code', 'calibration_intercept_v', ...
    'fit_offset_v', 'fit_phase_rad', 'residual_rms_v', 'r2', 'lsb_v_per_code'});

resultPath = fullfile(outDir, [safeFileStem(stem) '_single_sine_calibrate_result.csv']);
resultPath = writeTableSafe(result, resultPath);

curvePath = fullfile(outDir, [safeFileStem(stem) '_code_voltage_calibration_curve.csv']);
if voltageFit.r2 >= minR2
    curvePath = writeTableSafe(calibrationCurve, curvePath);
else
    warning('拟合质量不达标，跳过码值-电压刻度曲线 CSV，避免生成错误刻度。');
    curvePath = '<skipped because R2 is too low>';
end

plotPath = fullfile(outDir, [safeFileStem(stem) '_single_sine_fit.png']);
saveFitPlot(t, adcVoltage, voltageFit, fileName, knownInputVpp, plotPath);

if voltageFit.r2 >= minR2
    curvePlotPath = fullfile(outDir, [safeFileStem(stem) '_code_voltage_calibration_curve.png']);
    saveCalibrationCurvePlot(calibrationCurve, signedCode, codeFit, ...
        knownInputVpp, calibrationSlope, calibrationIntercept, fileName, ...
        fitSampleCount, samplesPerPeriod, uniquePhaseCount, curvePlotPath);
else
    curvePlotPath = '<skipped because R2 is too low>';
end

fprintf('\nResult CSV: %s\n', resultPath);
fprintf('Curve CSV : %s\n', curvePath);
fprintf('Fit plot  : %s\n', plotPath);
fprintf('Curve plot: %s\n', curvePlotPath);

%% ======================== 小工具函数：一般不用改 ========================

function rowIndex = resolveFirstDataRow(rawCell, firstDataRow)
%resolveFirstDataRow - 按手动值或 Radix 行自动确定数据起始行
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
%resolveOptionalColumn - 解析可为空的列号或列标题配置
if isempty(colSpec) || (ischar(colSpec) && isempty(strtrim(colSpec)))
    colIndex = [];
else
    colIndex = resolveColumn(rawCell, colSpec, nameForError);
end
end

function colIndex = resolveColumn(rawCell, colSpec, nameForError)
%resolveColumn - 将列号或表头名称解析为有效列索引
if isnumeric(colSpec)
    colIndex = colSpec;
    if colIndex < 1 || colIndex > size(rawCell, 2)
        error('%s 列号超出范围：%d', nameForError, colIndex);
    end
    return;
end

target = strtrim(char(colSpec));
header = rawCell(1, :);
headerText = cellfun(@cellText, header, 'UniformOutput', false);
match = find(strcmp(headerText, target), 1);

if isempty(match)
    error('找不到 %s 表头：%s。请改成列号，例如 4。', nameForError, target);
end
colIndex = match;
end

function code = parseCodeColumn(values, radix, adcBits)
%parseCodeColumn - 按十六进制或十进制解析 ADC 原始码
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
            error('dataRadix 只能是 hex 或 decimal。');
    end
end
end

function values = parseNumericColumn(rawValues)
%parseNumericColumn - 将 valid 等辅助列解析为数值向量
values = NaN(numel(rawValues), 1);
for i = 1:numel(rawValues)
    values(i) = str2double(cellText(rawValues{i}));
end
end

function [voltage, signedCode, lsbV] = codeToVoltage(rawCode, adcBits, inputRangeVpp, outputCoding)
%codeToVoltage - 按位宽、满量程和码型换算有符号码及电压
rawCode = double(rawCode(:));
outputCoding = lower(strtrim(char(outputCoding)));

switch outputCoding
    case 'offset_binary'
        rawUnsigned = mod(rawCode, 2^adcBits);
        signedCode = rawUnsigned - 2^(adcBits - 1);
        lsbV = inputRangeVpp / 2^adcBits;
        voltage = signedCode * lsbV;

    case 'twos_complement'
        if any(rawCode < 0)
            signedCode = rawCode;
        else
            rawUnsigned = mod(rawCode, 2^adcBits);
            signedCode = rawUnsigned;
            wrapMask = signedCode >= 2^(adcBits - 1);
            signedCode(wrapMask) = signedCode(wrapMask) - 2^adcBits;
        end
        lsbV = inputRangeVpp / 2^adcBits;
        voltage = signedCode * lsbV;

    case 'unipolar'
        rawUnsigned = mod(rawCode, 2^adcBits);
        signedCode = rawUnsigned;
        lsbV = inputRangeVpp / (2^adcBits - 1);
        voltage = rawUnsigned * lsbV;

    otherwise
        error('outputCoding 只能是 offset_binary、twos_complement 或 unipolar。');
end
end

function freqHz = estimateSineFrequency(y, fs)
%estimateSineFrequency - 用去均值加窗 FFT 估计最强非直流频率
y = y(:) - mean(y);
n = numel(y);
window = hanning(n);
spectrum = abs(fft(y .* window));
halfN = floor(n / 2);
spectrum(1) = 0;
[~, idx] = max(spectrum(1:halfN));
freqHz = (idx - 1) * fs / n;

if ~isfinite(freqHz) || freqHz <= 0
    error('无法自动估计正弦频率，请手动设置 toneFreqHz。');
end
end

function fit = fitSineAtFixedFrequency(t, y, freqHz)
%fitSineAtFixedFrequency - 在线性 sin/cos 基上拟合幅度、相位和偏置
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

function uniquePhaseCount = countUniqueSamplePhases(sampleCount, freqHz, fs)
%countUniqueSamplePhases - 统计相干采样记录中不同采样相位的数量
% 如果频率和采样率是整数倍关系，例如 10MHz/100MHz，
% 很多周期会重复落在同一组相位点上。这个数量只用于解释图形显示。
phase = mod((0:sampleCount-1).' * freqHz / fs, 1);
uniquePhaseCount = numel(unique(round(phase * 1e12)));
end

function inputVppValue = getKnownInputVpp(inputMode, inputLevel_dBm, inputVpp)
%getKnownInputVpp - 将 50 ohm dBm 或直接 Vpp 统一为输入 Vpp
switch lower(strtrim(char(inputMode)))
    case 'dbm_50ohm'
        if ~isfinite(inputLevel_dBm)
            error('inputMode=dBm_50ohm 时，必须填写 inputLevel_dBm。');
        end
        powerW = 10^((inputLevel_dBm - 30) / 10);
        vrms = sqrt(powerW * 50);
        inputVppValue = 2 * sqrt(2) * vrms;

    case 'vpp'
        if ~isfinite(inputVpp) || inputVpp <= 0
            error('inputMode=vpp 时，必须填写正数 inputVpp，例如 inputVpp = 0.63246。');
        end
        inputVppValue = inputVpp;

    otherwise
        error('inputMode 只能是 dBm_50ohm 或 vpp。');
end

if ~isfinite(inputVppValue) || inputVppValue <= 0
    error('输入信号 Vpp 无效，请检查 inputMode、inputLevel_dBm 或 inputVpp。');
end
end

function calibrationCurve = makeCalibrationCurve(signedCode, slope, intercept, lsbV, pointCount)
%makeCalibrationCurve - 在实际码值范围生成输入等效电压标定曲线
codeMin = floor(min(signedCode));
codeMax = ceil(max(signedCode));
if codeMin == codeMax
    codeMin = codeMin - 1;
    codeMax = codeMax + 1;
end

signedCodeAxis = linspace(codeMin, codeMax, pointCount).';
inputEquivalentV = slope * signedCodeAxis + intercept;
adcInputV = signedCodeAxis * lsbV;

calibrationCurve = table(signedCodeAxis, inputEquivalentV, adcInputV, ...
    'VariableNames', {'signed_code', 'input_equivalent_v', 'adc_input_v'});
end

function saveFitPlot(t, y, fit, fileName, knownInputVpp, plotPath)
%saveFitPlot - 保存原始电压时序和正弦拟合的对比图
figure('Name', ['Single sine calibration - ' fileName], 'Visible', 'off');
plot(t, y, '.', 'MarkerSize', 4);
hold on;
plot(t, fit.yFit, 'r-', 'LineWidth', 1.2);
grid on;
xlabel('Time (s)');
ylabel('ADC voltage (V)');
title(sprintf('%s, fit Vpp=%.6g V, input Vpp=%.6g V, R^2=%.5f', ...
    fileName, fit.vpp, knownInputVpp, fit.r2), 'Interpreter', 'none');
legend({'data', 'sine fit'}, 'Location', 'best');
saveas(gcf, plotPath);
close(gcf);
end

function saveCalibrationCurvePlot(calibrationCurve, signedCode, codeFit, ...
    knownInputVpp, slope, intercept, fileName, ...
    fitSampleCount, samplesPerPeriod, uniquePhaseCount, plotPath)
%saveCalibrationCurvePlot - 保存样本点与单点比例标定线
inputFitV = (knownInputVpp / 2) * (codeFit.yFit - codeFit.offset) / codeFit.amplitude;

figure('Name', ['Code-voltage calibration - ' fileName], 'Visible', 'off');
lineHandle = plot(calibrationCurve.signed_code, calibrationCurve.input_equivalent_v, ...
    'r-', 'LineWidth', 1.4);
hold on;
pointHandle = plot(signedCode, inputFitV, 'o', ...
    'MarkerSize', 5, 'MarkerFaceColor', [0 0.4470 0.7410], ...
    'MarkerEdgeColor', [0 0.4470 0.7410]);
grid on;
xlabel('Signed code after coding conversion');
ylabel('Input-equivalent voltage (V)');
title(sprintf(['%s, input_v = %.6g*code %+.6g\n', ...
    'fit samples=%d, samples/period=%.4g, unique phases=%d'], ...
    fileName, slope, intercept, fitSampleCount, samplesPerPeriod, uniquePhaseCount), ...
    'Interpreter', 'none');
legend([pointHandle, lineHandle], {'sample points from sine fit', 'calibration line'}, ...
    'Location', 'best');
saveas(gcf, plotPath);
close(gcf);
end

function safeName = safeFileStem(name)
%safeFileStem - 将源文件名转换为安全的输出文件名
safeName = regexprep(name, '[^\w\-.]', '_');
end

function writtenPath = writeTableSafe(tbl, targetPath)
%writeTableSafe - 写表失败时改用时间戳文件，避免覆盖已打开文件
try
    writetable(tbl, targetPath, 'Encoding', 'UTF-8');
    writtenPath = targetPath;
catch ME
    [folder, stem, ext] = fileparts(targetPath);
    timestamp = char(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    fallbackPath = fullfile(folder, [stem '_' timestamp ext]);
    warning('无法写入 %s，可能文件正被 Excel 打开。改写入新文件：%s\n原始错误：%s', ...
        targetPath, fallbackPath, ME.message);
    writetable(tbl, fallbackPath, 'Encoding', 'UTF-8');
    writtenPath = fallbackPath;
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

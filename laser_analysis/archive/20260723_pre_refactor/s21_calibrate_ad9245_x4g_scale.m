% s21_calibrate_ad9245_x4g_scale
% AD9245 X4G multi-level Vpp-Codepp calibration from Vivado ILA CSV files.
%
% Important evidence conventions:
%   1. CSV column 1 (Sample in Buffer) is the time coordinate.
%   2. CSV column 8 is X4G signed 14-bit code; column 9 is its valid flag.
%   3. Valid events are not uniformly spaced, so the sine fit uses the
%      original Sample-in-Buffer coordinate rather than re-indexing events.
%   4. Filename Vpp is treated as the recorded signal-generator setting.
%      Termination, connector voltage, and analog-front-end gain were not
%      recorded, so the measured scale is not silently called ADC-pin scale.

clear;
clc;

%% Configuration
dataDir = 'G:\01_laser\202607_电2test\YCQD_AD_9245\9245_scale\X4G';
outDir = fullfile(dataDir, 'AD9245_X4G_scale_result');
scriptVersion = '2026-07-17-r1';

sampleIndexCol = 1;
dataCol = 4;
validCol = 5;
validValue = 1;
adcBits = 14;
negativeRail = -2^(adcBits - 1);
positiveRail = 2^(adcBits - 1) - 1;
nearRailMarginCode = 256;
minSineFitR2 = 0.99;
theoreticalAdcPinScaleUvPerCode = 2 / 2^adcBits * 1e6;

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

files = dir(fullfile(dataDir, '*Vpp.csv'));
if isempty(files)
    error('No *Vpp.csv files found in %s.', dataDir);
end

sourceVpp = NaN(numel(files), 1);
for k = 1:numel(files)
    sourceVpp(k) = parseVppFromFileName(files(k).name);
end
[sourceVpp, order] = sort(sourceVpp);
files = files(order);
nFile = numel(files);

sourceFile = strings(nFile, 1);
sourcePath = strings(nFile, 1);
sourceSizeBytes = zeros(nFile, 1);
sourceModifiedTime = strings(nFile, 1);
sourceSha256 = strings(nFile, 1);
validSampleCount = zeros(nFile, 1);
minimumCode = NaN(nFile, 1);
maximumCode = NaN(nFile, 1);
fitFrequencyCyclesPerIlaRow = NaN(nFile, 1);
fitCodeAmplitude = NaN(nFile, 1);
fitCodeVpp = NaN(nFile, 1);
fitOffsetCode = NaN(nFile, 1);
sineFitR2 = NaN(nFile, 1);
sineResidualRmsCode = NaN(nFile, 1);
extremeDeviationCode = NaN(nFile, 1);
rawNearRailFlag = false(nFile, 1);
nearRailFlag = false(nFile, 1);
isolatedExtremeFlag = false(nFile, 1);
qualityNote = strings(nFile, 1);

for k = 1:nFile
    inPath = fullfile(dataDir, files(k).name);
    fprintf('[%d/%d] %s\n', k, nFile, inPath);

    [rowIndexAll, codeAll, validAll] = readSelectedIlaColumns( ...
        inPath, sampleIndexCol, dataCol, validCol);
    finiteMask = isfinite(rowIndexAll) & isfinite(codeAll) & isfinite(validAll);
    rowIndexAll = rowIndexAll(finiteMask);
    codeAll = decodeSigned14(codeAll(finiteMask), adcBits);
    validAll = validAll(finiteMask);

    useMask = validAll == validValue;
    rowIndex = rowIndexAll(useMask);
    code = codeAll(useMask);
    if numel(code) < 16
        error('Too few valid X4G samples in %s.', inPath);
    end

    fit = fitSineOnOriginalRows(rowIndex, code, codeAll);

    sourceFile(k) = string(files(k).name);
    sourcePath(k) = string(inPath);
    sourceSizeBytes(k) = files(k).bytes;
    sourceModifiedTime(k) = string(datetime(files(k).datenum, ...
        'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    sourceSha256(k) = localSha256(inPath);
    validSampleCount(k) = numel(code);
    minimumCode(k) = min(code);
    maximumCode(k) = max(code);
    fitFrequencyCyclesPerIlaRow(k) = fit.frequencyCyclesPerRow;
    fitCodeAmplitude(k) = fit.amplitudeCode;
    fitCodeVpp(k) = fit.codeVpp;
    fitOffsetCode(k) = fit.offsetCode;
    sineFitR2(k) = fit.r2;
    sineResidualRmsCode(k) = fit.residualRmsCode;

    fittedMinimum = fit.offsetCode - fit.amplitudeCode;
    fittedMaximum = fit.offsetCode + fit.amplitudeCode;
    extremeDeviationCode(k) = max(abs([minimumCode(k) - fittedMinimum, ...
        maximumCode(k) - fittedMaximum]));
    rawNearRailFlag(k) = minimumCode(k) <= negativeRail + nearRailMarginCode ...
        || maximumCode(k) >= positiveRail - nearRailMarginCode;
    nearRailFlag(k) = fittedMinimum <= negativeRail + nearRailMarginCode ...
        || fittedMaximum >= positiveRail - nearRailMarginCode;
    isolatedExtremeFlag(k) = extremeDeviationCode(k) > ...
        max(100, 10 * sineResidualRmsCode(k));

    notes = strings(4, 1);
    noteCount = 0;
    if nearRailFlag(k)
        noteCount = noteCount + 1;
        notes(noteCount) = 'fitted sine near 14-bit code rail';
    end
    if rawNearRailFlag(k) && ~nearRailFlag(k)
        noteCount = noteCount + 1;
        notes(noteCount) = 'isolated raw near-rail sample(s); sine fit retained';
    end
    if isolatedExtremeFlag(k)
        noteCount = noteCount + 1;
        notes(noteCount) = 'isolated raw extreme; sine fit retained';
    end
    if sineFitR2(k) < minSineFitR2
        noteCount = noteCount + 1;
        notes(noteCount) = sprintf('sine fit R2 below %.3f', minSineFitR2);
    end
    if noteCount == 0
        qualityNote(k) = 'ok';
    else
        qualityNote(k) = strjoin(notes(1:noteCount), '; ');
    end
end

primaryFitUsed = ~nearRailFlag & sineFitR2 >= minSineFitR2;
if nnz(primaryFitUsed) < 2
    error('Fewer than two points remain in the primary fit.');
end

primaryFit = linearFit(fitCodeVpp(primaryFitUsed), sourceVpp(primaryFitUsed));
allPointFit = linearFit(fitCodeVpp, sourceVpp);

primaryPredictedVpp = primaryFit.slope .* fitCodeVpp + primaryFit.intercept;
primaryResidualVpp = sourceVpp - primaryPredictedVpp;
allPointPredictedVpp = allPointFit.slope .* fitCodeVpp + allPointFit.intercept;
allPointResidualVpp = sourceVpp - allPointPredictedVpp;

fitExclusionReason = strings(nFile, 1);
for k = 1:nFile
    reasons = strings(2, 1);
    reasonCount = 0;
    if nearRailFlag(k)
        reasonCount = reasonCount + 1;
        reasons(reasonCount) = sprintf('within %d code of 14-bit rail', ...
            nearRailMarginCode);
    end
    if sineFitR2(k) < minSineFitR2
        reasonCount = reasonCount + 1;
        reasons(reasonCount) = sprintf('sine fit R2 below %.3f', minSineFitR2);
    end
    fitExclusionReason(k) = strjoin(reasons(1:reasonCount), '; ');
end

measurementTable = table(sourceFile, sourcePath, sourceSizeBytes, ...
    sourceModifiedTime, sourceSha256, sourceVpp, validSampleCount, ...
    minimumCode, maximumCode, fitFrequencyCyclesPerIlaRow, ...
    fitCodeAmplitude, fitCodeVpp, fitOffsetCode, sineFitR2, ...
    sineResidualRmsCode, extremeDeviationCode, isolatedExtremeFlag, ...
    rawNearRailFlag, nearRailFlag, primaryFitUsed, fitExclusionReason, qualityNote, ...
    primaryPredictedVpp, primaryResidualVpp, allPointPredictedVpp, ...
    allPointResidualVpp);

fitName = ["primary_non_near_rail"; "all_points_cross_check"];
fitDefinition = repmat("source_setting_Vpp = slope * X4G_Codepp + intercept", 2, 1);
referencePlane = repmat( ...
    "signal-generator setting parsed from filename; termination/load not recorded", 2, 1);
slopeVPerCode = [primaryFit.slope; allPointFit.slope];
slopeUvPerCode = slopeVPerCode * 1e6;
interceptV = [primaryFit.intercept; allPointFit.intercept];
interceptMv = interceptV * 1e3;
rSquared = [primaryFit.r2; allPointFit.r2];
residualRmsMv = [primaryFit.residualRms; allPointFit.residualRms] * 1e3;
maxAbsResidualMv = [primaryFit.maxAbsResidual; allPointFit.maxAbsResidual] * 1e3;
pointCount = [nnz(primaryFitUsed); nFile];
usedFiles = [strjoin(sourceFile(primaryFitUsed), ';'); strjoin(sourceFile, ';')];
excludedFiles = [strjoin(sourceFile(~primaryFitUsed), ';'); ""];
if any(~primaryFitUsed)
    primaryExclusionSummary = ...
        "fitted-sine near-rail or low-sine-fit-R2 points excluded";
else
    primaryExclusionSummary = ...
        "none; all fitted sine peaks remain outside the 256-code rail margin";
end
exclusionReason = [primaryExclusionSummary; "none; cross-check only"];
theoreticalAdcPinScaleUvPerCodeColumn = repmat( ...
    theoreticalAdcPinScaleUvPerCode, 2, 1);
inferredGainVsTwoVpp14Bit = theoreticalAdcPinScaleUvPerCodeColumn ./ slopeUvPerCode;
inferredGainEvidenceClass = repmat( ...
    "derived plausibility comparison; not a measured front-end gain", 2, 1);
inputSha256Manifest = repmat(strjoin(sourceFile + "=" + sourceSha256, ';'), 2, 1);

fitSummaryTable = table(fitName, fitDefinition, referencePlane, ...
    slopeVPerCode, slopeUvPerCode, interceptV, interceptMv, rSquared, ...
    residualRmsMv, maxAbsResidualMv, pointCount, usedFiles, excludedFiles, ...
    exclusionReason, theoreticalAdcPinScaleUvPerCodeColumn, ...
    inferredGainVsTwoVpp14Bit, inferredGainEvidenceClass, inputSha256Manifest);

parameter = [ ...
    "analysis_timestamp"; "source_directory"; "output_directory"; ...
    "script_path"; "script_version"; "device_channel"; ...
    "sample_coordinate_column"; "data_column"; "valid_column"; ...
    "valid_value"; "adc_bits"; "output_coding"; "code_rails"; ...
    "near_rail_margin_code"; "code_vpp_method"; "frequency_method"; ...
    "frequency_unit"; "sample_rate_hz"; "source_level"; ...
    "calibration_reference_plane"; "termination_load"; ...
    "formal_report_updated"];
value = [ ...
    string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); ...
    string(dataDir); string(outDir); string(mfilename('fullpath')); ...
    string(scriptVersion); "AD9245 X4G"; ...
    string(sampleIndexCol); string(dataCol); string(validCol); ...
    string(validValue); string(adcBits); "signed decimal / 14-bit two's complement"; ...
    sprintf('%d to %d', negativeRail, positiveRail); ...
    string(nearRailMarginCode); "least-squares sine amplitude (2*A)"; ...
    "FFT initial estimate plus bounded least-squares refinement on original ILA rows"; ...
    "cycles per ILA row"; "not recorded; not required for amplitude calibration"; ...
    "Vpp parsed from filename"; ...
    "signal-generator setting; connector and ADC-pin amplitudes not established"; ...
    "not recorded"; "false"];
unit = [ ...
    "local time"; "path"; "path"; "path"; "text"; "text"; ...
    "1-based CSV column"; "1-based CSV column"; "1-based CSV column"; ...
    "flag"; "bit"; "text"; "code"; "code"; "text"; "text"; ...
    "cycles/row"; "Hz"; "Vpp"; "text"; "text"; "boolean"];
evidenceClass = [ ...
    "calculated"; "directly observed"; "configured"; "configured"; ...
    "configured"; "directly observed"; "directly observed"; ...
    "directly observed"; "directly observed"; "configured"; ...
    "directly observed"; "directly observed"; "configured"; ...
    "configured"; "calculated"; "calculated"; "calculated"; ...
    "unrecorded"; "directly observed"; "limited reference-plane evidence"; ...
    "unrecorded"; "configured"];
analysisParametersTable = table(parameter, value, unit, evidenceClass);

sourceManifestTable = measurementTable(:, { ...
    'sourceFile', 'sourcePath', 'sourceSizeBytes', ...
    'sourceModifiedTime', 'sourceSha256'});

measurementCsv = fullfile(outDir, 'AD9245_X4G_scale_measurements.csv');
summaryCsv = fullfile(outDir, 'AD9245_X4G_scale_fit_summary.csv');
parameterCsv = fullfile(outDir, 'analysis_parameters.csv');
manifestCsv = fullfile(outDir, 'source_manifest.csv');
matPath = fullfile(outDir, 'AD9245_X4G_scale_result.mat');
plotPath = fullfile(outDir, 'AD9245_X4G_scale_fit_residual.png');
textPath = fullfile(outDir, 'result_summary.txt');

writetable(measurementTable, measurementCsv);
writetable(fitSummaryTable, summaryCsv);
writetable(analysisParametersTable, parameterCsv);
writetable(sourceManifestTable, manifestCsv);

save(matPath, 'measurementTable', 'fitSummaryTable', ...
    'analysisParametersTable', 'sourceManifestTable', 'primaryFit', ...
    'allPointFit', 'primaryFitUsed', 'dataDir', 'outDir', 'scriptVersion');

makeCalibrationPlot(plotPath, fitCodeVpp, sourceVpp, primaryFitUsed, ...
    primaryFit, primaryResidualVpp);
writeTextSummary(textPath, primaryFit, allPointFit, ...
    theoreticalAdcPinScaleUvPerCode, sourceFile(~primaryFitUsed));

fprintf('\nPrimary result: Vpp = %.12g * Codepp %+.12g V\n', ...
    primaryFit.slope, primaryFit.intercept);
fprintf('Scale: %.9f uV/code, R2 = %.12f\n', ...
    primaryFit.slope * 1e6, primaryFit.r2);
fprintf('Output: %s\n', outDir);

%% Local functions
function vpp = parseVppFromFileName(fileName)
token = regexp(fileName, '(?i)(\d+(?:\.\d+)?)vpp', 'tokens', 'once');
if isempty(token)
    error('Cannot parse Vpp from filename: %s', fileName);
end
vpp = str2double(token{1});
end

function [rowIndex, code, valid] = readSelectedIlaColumns( ...
    inPath, sampleIndexCol, dataCol, validCol)
opts = detectImportOptions(inPath, 'Delimiter', ',');
columnIndices = [sampleIndexCol, dataCol, validCol];
if max(columnIndices) > numel(opts.VariableNames)
    error('CSV has fewer than %d columns: %s', max(columnIndices), inPath);
end
opts.SelectedVariableNames = opts.VariableNames(columnIndices);
t = readtable(inPath, opts);
rowIndex = toDoubleColumn(t{:, 1});
code = toDoubleColumn(t{:, 2});
valid = toDoubleColumn(t{:, 3});
end

function value = toDoubleColumn(value)
if isnumeric(value) || islogical(value)
    value = double(value);
elseif iscell(value)
    value = str2double(string(value));
else
    value = str2double(string(value));
end
value = value(:);
end

function signedCode = decodeSigned14(rawCode, adcBits)
signedCode = double(rawCode(:));
modulus = 2^adcBits;
threshold = 2^(adcBits - 1);
rawWordMask = signedCode >= threshold & signedCode <= modulus - 1;
signedCode(rawWordMask) = signedCode(rawWordMask) - modulus;
end

function fit = fitSineOnOriginalRows(rowIndex, code, codeAll)
rowIndex = double(rowIndex(:));
rowIndex = rowIndex - rowIndex(1);
code = double(code(:));

yAll = double(codeAll(:));
yAll = yAll - mean(yAll);
n = numel(yAll);
window = 0.5 - 0.5 * cos(2 * pi * (0:n-1).' / max(n-1, 1));
nfft = 2^nextpow2(n);
spectrum = abs(fft(yAll .* window, nfft));
highestBin = min(floor(nfft / 2), max(3, floor(0.01 * nfft)));
[~, localPeak] = max(spectrum(2:highestBin));
peakBin = localPeak + 1;
frequencyInitial = (peakBin - 1) / nfft;
frequencyResolution = 1 / nfft;

lowerBound = max(1 / max(rowIndex(end), nfft), ...
    frequencyInitial - 1.5 * frequencyResolution);
upperBound = min(0.5 - eps, ...
    frequencyInitial + 1.5 * frequencyResolution);
options = optimset('TolX', 1e-13, 'MaxIter', 100, 'Display', 'off');
frequency = fminbnd(@(f) sineSse(f, rowIndex, code), ...
    lowerBound, upperBound, options);

[sse, coef, fitted] = sineSse(frequency, rowIndex, code);
residual = code - fitted;
sst = sum((code - mean(code)).^2);

fit.frequencyCyclesPerRow = frequency;
fit.amplitudeCode = hypot(coef(1), coef(2));
fit.codeVpp = 2 * fit.amplitudeCode;
fit.offsetCode = coef(3);
fit.residualRmsCode = sqrt(mean(residual.^2));
fit.r2 = 1 - sse / sst;
end

function [sse, coef, fitted] = sineSse(frequency, rowIndex, code)
phase = 2 * pi * frequency * rowIndex;
design = [sin(phase), cos(phase), ones(numel(rowIndex), 1)];
coef = design \ code;
fitted = design * coef;
residual = code - fitted;
sse = sum(residual.^2);
end

function fit = linearFit(x, y)
x = double(x(:));
y = double(y(:));
coefficient = polyfit(x, y, 1);
predicted = polyval(coefficient, x);
residual = y - predicted;
sst = sum((y - mean(y)).^2);
fit.slope = coefficient(1);
fit.intercept = coefficient(2);
fit.r2 = 1 - sum(residual.^2) / sst;
fit.residualRms = sqrt(mean(residual.^2));
fit.maxAbsResidual = max(abs(residual));
fit.predicted = predicted;
fit.residual = residual;
end

function makeCalibrationPlot(plotPath, codeVpp, sourceVpp, used, fit, residual)
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100, 100, 1050, 780]);

subplot(2, 1, 1);
hold on;
hUsed = plot(codeVpp(used), sourceVpp(used), 'o', 'MarkerSize', 7, ...
    'LineWidth', 1.3, 'MarkerFaceColor', [0.10 0.45 0.75], ...
    'Color', [0.10 0.45 0.75]);
hExcluded = plot(codeVpp(~used), sourceVpp(~used), 'x', 'MarkerSize', 9, ...
    'LineWidth', 1.8, 'Color', [0.85 0.25 0.15]);
xLine = linspace(0, max(codeVpp) * 1.04, 300).';
hFit = plot(xLine, fit.slope * xLine + fit.intercept, '-', ...
    'LineWidth', 1.6, 'Color', [0.15 0.15 0.15]);
grid on;
box on;
xlabel('X4G Code_{pp} (code)');
ylabel('Source setting (V_{pp})');
title(sprintf(['AD9245 X4G calibration: %.6f uV/code, ', ...
    'R^2 = %.9f'], fit.slope * 1e6, fit.r2));
if any(~used)
    legend([hUsed, hExcluded, hFit], {'Primary fit points', ...
        'Excluded validation point', 'Primary linear fit'}, ...
        'Location', 'northwest');
else
    legend([hUsed, hFit], {'Primary fit points', 'Primary linear fit'}, ...
        'Location', 'northwest');
end

subplot(2, 1, 2);
hold on;
yline(0, '-', 'Color', [0.35 0.35 0.35]);
plot(codeVpp(used), residual(used) * 1e3, 'o-', ...
    'LineWidth', 1.1, 'MarkerSize', 6, 'Color', [0.10 0.45 0.75]);
plot(codeVpp(~used), residual(~used) * 1e3, 'x', ...
    'LineWidth', 1.8, 'MarkerSize', 9, 'Color', [0.85 0.25 0.15]);
grid on;
box on;
xlabel('X4G Code_{pp} (code)');
ylabel('Primary-fit residual (mV_{pp})');
if any(~used)
    title('Residuals; excluded points remain visible');
else
    title('Residuals; all points retained');
end

exportgraphics(figureHandle, plotPath, 'Resolution', 300);
close(figureHandle);
end

function writeTextSummary(textPath, primaryFit, allPointFit, ...
    theoreticalScale, excludedFiles)
fileId = fopen(textPath, 'w');
if fileId < 0
    warning('Cannot write %s.', textPath);
    return;
end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'AD9245 X4G scale calibration\n');
fprintf(fileId, 'Primary: source_setting_Vpp = %.15g * Codepp %+.15g V\n', ...
    primaryFit.slope, primaryFit.intercept);
fprintf(fileId, 'Primary scale: %.9f uV/code\n', primaryFit.slope * 1e6);
fprintf(fileId, 'Primary R2: %.12f\n', primaryFit.r2);
fprintf(fileId, 'Primary residual RMS: %.6f mVpp\n', ...
    primaryFit.residualRms * 1e3);
fprintf(fileId, 'Primary maximum absolute residual: %.6f mVpp\n', ...
    primaryFit.maxAbsResidual * 1e3);
fprintf(fileId, 'Excluded from primary fit: %s (near 14-bit rail)\n', ...
    char(strjoin(excludedFiles, ';')));
fprintf(fileId, 'All-points cross-check scale: %.9f uV/code; R2 %.12f\n', ...
    allPointFit.slope * 1e6, allPointFit.r2);
fprintf(fileId, 'Theoretical 2 Vpp / 14-bit ADC-pin scale: %.9f uV/code\n', ...
    theoreticalScale);
fprintf(fileId, ['Comparison-only inferred gain: %.9f. This is not a ', ...
    'measured front-end gain because termination/reference plane was not recorded.\n'], ...
    theoreticalScale / (primaryFit.slope * 1e6));
end

function hash = localSha256(filePath)
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


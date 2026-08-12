function result = run_ad9245_scale_calibration(cfg)
%RUN_AD9245_SCALE_CALIBRATION Shared AD9245 Vpp-Codepp calibration runner.
%   RESULT contains configuration, source manifest, fits, tables, and output
%   paths.  Set cfg.outputDir to a temporary directory for validation runs.

arguments
    cfg (1, 1) struct
end
cfg = validateConfig(cfg);
channel = string(cfg.channel);
negativeRail = -2^(cfg.adcBits - 1);
positiveRail = 2^(cfg.adcBits - 1) - 1;
if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

files = dir(fullfile(cfg.dataDir, cfg.filePattern));
if isempty(files)
    error('laser_analysis:NoCalibrationFiles', ...
        'No %s files found in %s.', cfg.filePattern, cfg.dataDir);
end
sourceVpp = arrayfun(@(f) parseVpp(f.name), files(:));
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
    inPath = fullfile(cfg.dataDir, files(k).name);
    [rowAll, codeAll, validAll] = readIlaColumns(inPath, ...
        cfg.sampleIndexColumn, cfg.dataColumn, cfg.validColumn);
    finiteMask = isfinite(rowAll) & isfinite(codeAll) & isfinite(validAll);
    rowAll = rowAll(finiteMask);
    codeAll = decodeSigned(codeAll(finiteMask), cfg.adcBits);
    validAll = validAll(finiteMask);
    useMask = validAll == cfg.validValue;
    row = rowAll(useMask);
    code = codeAll(useMask);
    if numel(code) < 16
        error('laser_analysis:TooFewSamples', ...
            'Too few valid %s samples in %s.', channel, inPath);
    end
    sineFit = fitSine(row, code, codeAll);

    sourceFile(k) = string(files(k).name);
    sourcePath(k) = string(inPath);
    sourceSizeBytes(k) = files(k).bytes;
    sourceModifiedTime(k) = string(datetime(files(k).datenum, ...
        'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    sourceSha256(k) = sha256(inPath);
    validSampleCount(k) = numel(code);
    minimumCode(k) = min(code);
    maximumCode(k) = max(code);
    fitFrequencyCyclesPerIlaRow(k) = sineFit.frequencyCyclesPerRow;
    fitCodeAmplitude(k) = sineFit.amplitudeCode;
    fitCodeVpp(k) = sineFit.codeVpp;
    fitOffsetCode(k) = sineFit.offsetCode;
    sineFitR2(k) = sineFit.r2;
    sineResidualRmsCode(k) = sineFit.residualRmsCode;

    fittedMinimum = sineFit.offsetCode - sineFit.amplitudeCode;
    fittedMaximum = sineFit.offsetCode + sineFit.amplitudeCode;
    extremeDeviationCode(k) = max(abs([minimumCode(k) - fittedMinimum, ...
        maximumCode(k) - fittedMaximum]));
    rawNearRailFlag(k) = minimumCode(k) <= negativeRail + cfg.nearRailMarginCode ...
        || maximumCode(k) >= positiveRail - cfg.nearRailMarginCode;
    nearRailFlag(k) = fittedMinimum <= negativeRail + cfg.nearRailMarginCode ...
        || fittedMaximum >= positiveRail - cfg.nearRailMarginCode;
    isolatedExtremeFlag(k) = extremeDeviationCode(k) > ...
        max(100, 10 * sineResidualRmsCode(k));
    notes = strings(0, 1);
    if nearRailFlag(k), notes(end + 1) = "fitted sine near code rail"; end %#ok<AGROW>
    if rawNearRailFlag(k) && ~nearRailFlag(k)
        notes(end + 1) = "isolated raw near-rail sample; fit retained"; %#ok<AGROW>
    end
    if isolatedExtremeFlag(k)
        notes(end + 1) = "isolated raw extreme; fit retained"; %#ok<AGROW>
    end
    if sineFitR2(k) < cfg.minimumSineFitR2
        notes(end + 1) = sprintf('sine fit R2 below %.3f', cfg.minimumSineFitR2); %#ok<AGROW>
    end
    if isempty(notes), qualityNote(k) = "ok"; else, qualityNote(k) = strjoin(notes, '; '); end
end

primaryFitUsed = ~nearRailFlag & sineFitR2 >= cfg.minimumSineFitR2;
if nnz(primaryFitUsed) < 2
    error('laser_analysis:TooFewFitPoints', ...
        'Fewer than two points remain in the primary fit.');
end
primaryFit = linearFit(fitCodeVpp(primaryFitUsed), sourceVpp(primaryFitUsed));
allPointFit = linearFit(fitCodeVpp, sourceVpp);
primaryPredictedVpp = primaryFit.slope .* fitCodeVpp + primaryFit.intercept;
primaryResidualVpp = sourceVpp - primaryPredictedVpp;
allPointPredictedVpp = allPointFit.slope .* fitCodeVpp + allPointFit.intercept;
allPointResidualVpp = sourceVpp - allPointPredictedVpp;

fitExclusionReason = strings(nFile, 1);
for k = 1:nFile
    reasons = strings(0, 1);
    if nearRailFlag(k)
        reasons(end + 1) = sprintf('within %d code of rail', cfg.nearRailMarginCode); %#ok<AGROW>
    end
    if sineFitR2(k) < cfg.minimumSineFitR2
        reasons(end + 1) = sprintf('sine fit R2 below %.3f', cfg.minimumSineFitR2); %#ok<AGROW>
    end
    fitExclusionReason(k) = strjoin(reasons, '; ');
end

measurementTable = table(sourceFile, sourcePath, sourceSizeBytes, ...
    sourceModifiedTime, sourceSha256, sourceVpp, validSampleCount, ...
    minimumCode, maximumCode, fitFrequencyCyclesPerIlaRow, ...
    fitCodeAmplitude, fitCodeVpp, fitOffsetCode, sineFitR2, ...
    sineResidualRmsCode, extremeDeviationCode, isolatedExtremeFlag, ...
    rawNearRailFlag, nearRailFlag, primaryFitUsed, fitExclusionReason, ...
    qualityNote, primaryPredictedVpp, primaryResidualVpp, ...
    allPointPredictedVpp, allPointResidualVpp);

fitName = ["primary_non_near_rail"; "all_points_cross_check"];
fitDefinition = repmat("source_setting_Vpp = slope * Codepp + intercept", 2, 1);
referencePlane = repmat(string(cfg.referencePlane), 2, 1);
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
exclusionReason = ["near-rail or low-R2 points excluded"; "none; cross-check only"];
theoreticalAdcPinScaleUvPerCode = repmat(cfg.theoreticalAdcPinScaleUvPerCode, 2, 1);
inferredGainVsTwoVpp14Bit = theoreticalAdcPinScaleUvPerCode ./ slopeUvPerCode;
inferredGainEvidenceClass = repmat( ...
    "derived plausibility comparison; not a measured front-end gain", 2, 1);
inputSha256Manifest = repmat(strjoin(sourceFile + "=" + sourceSha256, ';'), 2, 1);
fitSummaryTable = table(fitName, fitDefinition, referencePlane, ...
    slopeVPerCode, slopeUvPerCode, interceptV, interceptMv, rSquared, ...
    residualRmsMv, maxAbsResidualMv, pointCount, usedFiles, excludedFiles, ...
    exclusionReason, theoreticalAdcPinScaleUvPerCode, ...
    inferredGainVsTwoVpp14Bit, inferredGainEvidenceClass, inputSha256Manifest);
sourceManifestTable = measurementTable(:, {'sourceFile', 'sourcePath', ...
    'sourceSizeBytes', 'sourceModifiedTime', 'sourceSha256'});

prefix = sprintf('AD9245_%s_scale', channel);
outputFiles = struct;
outputFiles.measurements = fullfile(cfg.outputDir, [prefix '_measurements.csv']);
outputFiles.fitSummary = fullfile(cfg.outputDir, [prefix '_fit_summary.csv']);
outputFiles.parameters = fullfile(cfg.outputDir, 'analysis_parameters.csv');
outputFiles.sourceManifest = fullfile(cfg.outputDir, 'source_manifest.csv');
outputFiles.mat = fullfile(cfg.outputDir, [prefix '_result.mat']);
outputFiles.plot = fullfile(cfg.outputDir, [prefix '_fit_residual.png']);
outputFiles.textSummary = fullfile(cfg.outputDir, 'result_summary.txt');

parameter = ["analysis_timestamp"; "source_directory"; "output_directory"; ...
    "script_version"; "device_channel"; "sample_coordinate_column"; ...
    "data_column"; "valid_column"; "valid_value"; "adc_bits"; ...
    "near_rail_margin_code"; "minimum_sine_fit_R2"; ...
    "calibration_reference_plane"; "formal_report_updated"];
value = [string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')); ...
    string(cfg.dataDir); string(cfg.outputDir); string(cfg.scriptVersion); ...
    channel; string(cfg.sampleIndexColumn); string(cfg.dataColumn); ...
    string(cfg.validColumn); string(cfg.validValue); string(cfg.adcBits); ...
    string(cfg.nearRailMarginCode); string(cfg.minimumSineFitR2); ...
    string(cfg.referencePlane); "false"];
unit = ["local time"; "path"; "path"; "text"; "text"; "column"; ...
    "column"; "column"; "flag"; "bit"; "code"; "ratio"; "text"; "boolean"];
evidenceClass = ["calculated"; "directly observed"; "configured"; ...
    "configured"; "configured"; "configured"; "configured"; "configured"; ...
    "configured"; "configured"; "configured"; "configured"; ...
    "limited reference-plane evidence"; "configured"];
analysisParametersTable = table(parameter, value, unit, evidenceClass);

writetable(measurementTable, outputFiles.measurements);
writetable(fitSummaryTable, outputFiles.fitSummary);
writetable(analysisParametersTable, outputFiles.parameters);
writetable(sourceManifestTable, outputFiles.sourceManifest);
makeCalibrationPlot(outputFiles.plot, channel, fitCodeVpp, sourceVpp, ...
    primaryFitUsed, primaryFit, primaryResidualVpp, cfg.plotDpi);
writeSummary(outputFiles.textSummary, channel, primaryFit, allPointFit, ...
    cfg.theoreticalAdcPinScaleUvPerCode, sourceFile(~primaryFitUsed));

result = struct;
result.config = cfg;
result.sourceFiles = sourceManifestTable;
result.calibrationSource = string(cfg.referencePlane);
result.fit = struct('primary', primaryFit, 'allPoints', allPointFit, ...
    'usedMask', primaryFitUsed);
result.spectrum = [];
result.measurementTable = measurementTable;
result.summaryTable = fitSummaryTable;
result.analysisParametersTable = analysisParametersTable;
result.outputFiles = outputFiles;
save(outputFiles.mat, 'result', '-v7.3');
end

function cfg = validateConfig(cfg)
required = {'channel', 'dataDir', 'outputDir', 'filePattern', ...
    'sampleIndexColumn', 'dataColumn', 'validColumn', 'validValue', ...
    'adcBits', 'nearRailMarginCode', 'minimumSineFitR2', ...
    'theoreticalAdcPinScaleUvPerCode', 'referencePlane', ...
    'scriptVersion', 'plotDpi'};
for k = 1:numel(required)
    if ~isfield(cfg, required{k})
        error('laser_analysis:MissingConfig', 'Missing cfg.%s.', required{k});
    end
end
end

function vpp = parseVpp(fileName)
token = regexp(fileName, '(?i)(\d+(?:\.\d+)?)vpp', 'tokens', 'once');
if isempty(token), error('Cannot parse Vpp from filename: %s', fileName); end
vpp = str2double(token{1});
end

function [rowIndex, code, valid] = readIlaColumns(path, sampleCol, dataCol, validCol)
opts = detectImportOptions(path, 'Delimiter', ',');
indices = [sampleCol, dataCol, validCol];
if max(indices) > numel(opts.VariableNames)
    error('CSV has fewer than %d columns: %s', max(indices), path);
end
opts.SelectedVariableNames = opts.VariableNames(indices);
t = readtable(path, opts);
rowIndex = toDouble(t{:, 1});
code = toDouble(t{:, 2});
valid = toDouble(t{:, 3});
end

function value = toDouble(value)
if isnumeric(value) || islogical(value), value = double(value);
else, value = str2double(string(value)); end
value = value(:);
end

function code = decodeSigned(code, bits)
code = double(code(:));
modulus = 2^bits;
mask = code >= 2^(bits - 1) & code <= modulus - 1;
code(mask) = code(mask) - modulus;
end

function fit = fitSine(row, code, codeAll)
row = double(row(:)); row = row - row(1); code = double(code(:));
yAll = double(codeAll(:)); yAll = yAll - mean(yAll);
n = numel(yAll);
window = 0.5 - 0.5 * cos(2 * pi * (0:n-1).' / max(n-1, 1));
nfft = 2^nextpow2(n);
spectrum = abs(fft(yAll .* window, nfft));
highestBin = min(floor(nfft / 2), max(3, floor(0.01 * nfft)));
[~, localPeak] = max(spectrum(2:highestBin));
frequencyInitial = localPeak / nfft;
resolution = 1 / nfft;
lower = max(1 / max(row(end), nfft), frequencyInitial - 1.5 * resolution);
upper = min(0.5 - eps, frequencyInitial + 1.5 * resolution);
options = optimset('TolX', 1e-13, 'MaxIter', 100, 'Display', 'off');
frequency = fminbnd(@(f) sineSse(f, row, code), lower, upper, options);
[sse, coef, fitted] = sineSse(frequency, row, code);
residual = code - fitted;
sst = sum((code - mean(code)).^2);
fit = struct('frequencyCyclesPerRow', frequency, ...
    'amplitudeCode', hypot(coef(1), coef(2)), ...
    'codeVpp', 2 * hypot(coef(1), coef(2)), 'offsetCode', coef(3), ...
    'residualRmsCode', sqrt(mean(residual.^2)), 'r2', 1 - sse / sst);
end

function [sse, coef, fitted] = sineSse(frequency, row, code)
phase = 2 * pi * frequency * row;
design = [sin(phase), cos(phase), ones(numel(row), 1)];
coef = design \ code;
fitted = design * coef;
sse = sum((code - fitted).^2);
end

function fit = linearFit(x, y)
p = polyfit(double(x(:)), double(y(:)), 1);
predicted = polyval(p, x);
residual = y - predicted;
sst = sum((y - mean(y)).^2);
fit = struct('slope', p(1), 'intercept', p(2), ...
    'r2', 1 - sum(residual.^2) / sst, ...
    'residualRms', sqrt(mean(residual.^2)), ...
    'maxAbsResidual', max(abs(residual)));
end

function makeCalibrationPlot(path, channel, codeVpp, sourceVpp, used, fit, residual, dpi)
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 780]);
subplot(2, 1, 1); hold on;
plot(codeVpp(used), sourceVpp(used), 'o', 'MarkerFaceColor', [0.1 0.45 0.75]);
plot(codeVpp(~used), sourceVpp(~used), 'x', 'Color', [0.85 0.25 0.15]);
xLine = linspace(0, max(codeVpp) * 1.04, 300).';
plot(xLine, fit.slope * xLine + fit.intercept, 'k-', 'LineWidth', 1.5);
grid on; xlabel(sprintf('%s Code_{pp} (code)', channel)); ylabel('Source setting (V_{pp})');
title(sprintf('AD9245 %s calibration: %.6f uV/code, R^2=%.9f', ...
    channel, fit.slope * 1e6, fit.r2));
subplot(2, 1, 2); hold on; yline(0, '-');
plot(codeVpp(used), residual(used) * 1e3, 'o-');
plot(codeVpp(~used), residual(~used) * 1e3, 'x');
grid on; xlabel(sprintf('%s Code_{pp} (code)', channel));
ylabel('Primary-fit residual (mV_{pp})');
exportgraphics(fig, path, 'Resolution', dpi); close(fig);
end

function writeSummary(path, channel, primaryFit, allFit, theoretical, excluded)
fid = fopen(path, 'w');
if fid < 0, warning('Cannot write %s.', path); return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'AD9245 %s scale calibration\n', channel);
fprintf(fid, 'Primary scale: %.12g V/code (%.9f uV/code)\n', ...
    primaryFit.slope, primaryFit.slope * 1e6);
fprintf(fid, 'Primary intercept: %.12g V; R2: %.12f\n', ...
    primaryFit.intercept, primaryFit.r2);
fprintf(fid, 'All-points scale: %.12g V/code; R2: %.12f\n', ...
    allFit.slope, allFit.r2);
fprintf(fid, 'Excluded: %s\n', char(strjoin(excluded, ';')));
fprintf(fid, 'Theoretical 2 Vpp / 14-bit ADC-pin scale: %.9f uV/code\n', theoretical);
end

function hash = sha256(path)
[status, output] = system(sprintf('certutil -hashfile "%s" SHA256', ...
    strrep(char(path), '"', '""')));
if status ~= 0, hash = ""; return; end
token = regexp(output, '[0-9A-Fa-f]{64}', 'match', 'once');
if isempty(token), hash = ""; else, hash = lower(string(token)); end
end

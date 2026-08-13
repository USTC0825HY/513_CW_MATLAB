function results = adc_analysis_main(mode, inputFolder, selectedFileNames)
%ADC_ANALYSIS_MAIN Run one ADC analysis task.
%   RESULTS = ADC_ANALYSIS_MAIN opens a menu for SFDR, bandwidth,
%   isolation, or input-power-scale analysis. RESULTS =
%   ADC_ANALYSIS_MAIN(MODE) runs MODE directly, where MODE is 'sfdr',
%   'bandwidth', 'isolation', or 'power_scale'. A folder can be supplied
%   as the second input to process a known data directory without a dialog.
%
%   The calculation-only public module is analyze_adc_metrics.m. This file
%   handles configuration, file selection, plotting, and result files.

if nargin < 1 || isempty(mode)
    mode = selectAnalysisMode();
end
if isempty(mode)
    results = table;
    return;
end
config = createDefaultConfig();
if nargin < 2
    inputFolder = [];
end
if nargin < 3
    selectedFileNames = [];
end

switch lower(char(mode))
    case 'sfdr'
        results = runSfdrAnalysis(config, inputFolder, selectedFileNames);
    case 'bandwidth'
        results = runBandwidthAnalysis(config, inputFolder, selectedFileNames);
    case 'isolation'
        results = runIsolationAnalysis(config, inputFolder, selectedFileNames);
    case 'power_scale'
        results = runPowerScaleAnalysis(config, inputFolder, selectedFileNames);
    otherwise
        error('Unknown analysis mode: %s', char(mode));
end
end

function config = createDefaultConfig()
% All user-facing physical parameters are configured in this one block.
config.sampleRate = 25e6;                % ADC sample clock, Hz.
config.nfft = 128 * 1024;                % FFT length for SFDR.
config.adcDataColumn = 0;                % 0 = last CSV column.
config.adcBits = 14;                     % ADC resolution, bits.
config.adcFullScalePeakCode = 2^(config.adcBits - 1); % Signed peak code.
config.dcSpan = 16;                      % DC bins excluded from metrics.
config.signalSpan = 16;                 % Fundamental bins used in power.
config.harmonicSpan = 8;                % Bins around each harmonic.
config.maxHarmonicOrder = 8;            % Highest harmonic for THD.
config.fitCycles = 20;                  % Cycles used by known-frequency fit.
config.minimumFitSamples = 1024;        % Minimum samples used by fit.
config.minimumFitR2 = 0.99;             % Bandwidth fit quality threshold.
config.referenceUpperFrequencyHz = 1e6; % Low-frequency reference upper edge.
config.isolationFrequencyHz = 1e6;      % Isolation test tone, Hz.
config.minimumIsolationDb = 40;         % Requirement from test specification.
config.drivenChannel = 'X3G';           % Driven channel in current dataset.
config.powerScaleFrequencyHz = 1e6;      % Power-scale test tone, Hz.
config.powerRangeDbm = [-10 6];          % Formal input-power range, dBm.
config.clippingThreshold = 0.98;         % Fraction of ADC peak code.
config.clippingFractionLimit = 0.01;     % Fraction of near-full-scale samples.
config.plateauChangeThreshold = 0.01;    % Relative Code_pp change threshold.
config.showFitFigure = false;           % Avoid one window per batch file.
config.saveFigures = true;              % Save PNG and editable FIG outputs.
config.defaultIsolationFolder = fullfile( ...
    fileparts(mfilename('fullpath')), '..', '..', '..', ...
    'DATA_GS', '9245', 'GeLiDu', 'X3G_1MHz_7dBm');
config.defaultPowerScaleFolder = fullfile( ...
    fileparts(mfilename('fullpath')), '..', '..', '..', ...
    'DATA_GS', '9245', 'Power_Scale_1MHz');
end

function mode = selectAnalysisMode()
choice = menu('AD9245 analysis', 'SFDR', ...
    'Frequency response / 3 dB bandwidth', ...
    'Four-channel isolation', 'Input power scale', 'Exit');
modeList = {'sfdr', 'bandwidth', 'isolation', 'power_scale', ''};
mode = modeList{choice};
end

function results = runSfdrAnalysis(config, inputFolder, selectedFileNames)
[fileNames, pathName] = chooseCsvFiles(inputFolder, selectedFileNames, ...
    'Select CSV files for SFDR analysis', fileparts(mfilename('fullpath')));
if isempty(fileNames)
    results = table;
    return;
end

diary(fullfile(pathName, 'output.txt'));
diaryCleanup = onCleanup(@() diary('off')); %#ok<NASGU>
fileCount = numel(fileNames);
metricsList = cell(fileCount, 1);
for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(pathName, fileName);
    adcCode = readAdcCode(filePath, config.adcDataColumn);
    metrics = analyze_adc_metrics(adcCode, setFitMode(config, 'auto'));
    metricsList{fileIndex} = metrics;
    fprintf('\nFile: %s\n', fileName);
    fprintf('Fundamental frequency: %.9g Hz\n', ...
        metrics.spectrum.fundamentalFrequencyHz);
    fprintf('Code_pp: %.6f LSB\n', metrics.fit.codePp);
    fprintf('SFDR: %.6f dB\n', metrics.dynamic.SFDR);
    fprintf('SNR: %.6f dB\n', metrics.dynamic.SNR);
    fprintf('SINAD: %.6f dB\n', metrics.dynamic.SINAD);
    fprintf('THD: %.6f dB\n', metrics.dynamic.THD);
    fprintf('ENOB: %.6f bit\n', metrics.dynamic.ENOB);
    plotSfdrResult(metrics, fileName, filePath, config);
end

results = table(string(fileNames(:)), ...
    cellfun(@(m) m.spectrum.fundamentalFrequencyHz, metricsList), ...
    cellfun(@(m) m.fit.codePp, metricsList), ...
    cellfun(@(m) m.dynamic.SFDR, metricsList), ...
    cellfun(@(m) m.dynamic.SNR, metricsList), ...
    cellfun(@(m) m.dynamic.SINAD, metricsList), ...
    cellfun(@(m) m.dynamic.THD, metricsList), ...
    cellfun(@(m) m.dynamic.ENOB, metricsList), ...
    'VariableNames', {'FileName', 'FundamentalFrequencyHz', 'CodePp', ...
    'SFDR', 'SNR', 'SINAD', 'THD', 'ENOB'});
disp(results);
end

function plotSfdrResult(metrics, fileName, filePath, config)
if ~config.saveFigures && ~config.showFitFigure
    return;
end
if config.showFitFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Name', ['SFDR - ' fileName], ...
    'NumberTitle', 'off', 'Visible', visibility);
frequencyMHz = metrics.spectrum.frequencyHz / 1e6;
levelDbfs = metrics.spectrum.levelDb - ...
    metrics.spectrum.fundamentalLevelDb + metrics.dynamic.signalAmplitudeDbfs;
plot(frequencyMHz, levelDbfs, 'r-', 'LineWidth', 1);
hold on;
fundamentalIndex = metrics.spectrum.fundamentalIndex;
spurIndex = metrics.spectrum.largestSpurIndex;
plot(frequencyMHz(fundamentalIndex), levelDbfs(fundamentalIndex), ...
    'ko', 'MarkerFaceColor', 'y');
plot(frequencyMHz(spurIndex), levelDbfs(spurIndex), ...
    'ko', 'MarkerFaceColor', 'c');
plot([min(frequencyMHz) max(frequencyMHz)], ...
    [levelDbfs(spurIndex) levelDbfs(spurIndex)], '--g');
hold off;
grid on;
xlabel('Frequency (MHz)');
ylabel('Amplitude (dBFS)');
title(sprintf('%s | Fundamental = %.6f MHz', fileName, ...
    metrics.spectrum.fundamentalFrequencyHz / 1e6), ...
    'Interpreter', 'none');
legend('Spectrum', 'Fundamental', 'Largest spur', 'Spur level', ...
    'Location', 'best');
ylim([-140 0]);
text(0.70, 0.96, sprintf(['SFDR = %.2f dB\nSNR = %.2f dB\n' ...
    'SINAD = %.2f dB\nTHD = %.2f dB\nENOB = %.2f bit'], ...
    metrics.dynamic.SFDR, metrics.dynamic.SNR, metrics.dynamic.SINAD, ...
    metrics.dynamic.THD, metrics.dynamic.ENOB), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 12, 'FontWeight', 'bold', 'BackgroundColor', 'w');
if config.saveFigures
    exportgraphics(figureHandle, [filePath '.png'], 'Resolution', 180);
    savefig(figureHandle, [filePath '.fig']);
end
end

function results = runBandwidthAnalysis(config, inputFolder, selectedFileNames)
[fileNames, pathName] = chooseCsvFiles(inputFolder, selectedFileNames, ...
    'Select frequency-response CSV files', fileparts(mfilename('fullpath')));
if isempty(fileNames)
    results = table;
    return;
end

hasFrequency = cellfun(@(name) ...
    isfinite(extractFrequencyFromFileName(name)), fileNames);
if any(~hasFrequency)
    ignoredNames = fileNames(~hasFrequency);
    fprintf('Ignored CSV files without a frequency token:\n');
    fprintf('  %s\n', ignoredNames{:});
    fileNames = fileNames(hasFrequency);
end
if isempty(fileNames)
    error('No CSV file with a frequency token was selected.');
end

fileCount = numel(fileNames);
frequencyHz = zeros(fileCount, 1);
codePp = zeros(fileCount, 1);
fitR2 = zeros(fileCount, 1);
fitRmsCode = zeros(fileCount, 1);
for fileIndex = 1:fileCount
    frequencyHz(fileIndex) = extractFrequencyFromFileName(fileNames{fileIndex});
    if ~isfinite(frequencyHz(fileIndex)) || frequencyHz(fileIndex) <= 0
        error('Cannot extract a positive frequency from %s.', fileNames{fileIndex});
    end
    adcCode = readAdcCode(fullfile(pathName, fileNames{fileIndex}), ...
        config.adcDataColumn);
    fitConfig = setFitMode(config, 'known');
    fitConfig.knownFrequencyHz = frequencyHz(fileIndex);
    metrics = analyze_adc_metrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitRmsCode(fileIndex) = metrics.fit.residualRmsCode;
end

[frequencyHz, sortIndex] = sort(frequencyHz);
fileNames = fileNames(sortIndex);
codePp = codePp(sortIndex);
fitR2 = fitR2(sortIndex);
fitRmsCode = fitRmsCode(sortIndex);
valid = isfinite(codePp) & codePp > 0 & isfinite(fitR2) & ...
    fitR2 >= config.minimumFitR2;
if any(~valid)
    fprintf('\nRemoved abnormal bandwidth files:\n');
    removedNames = fileNames(~valid);
    fprintf('  %s\n', removedNames{:});
end
fileNames = fileNames(valid);
frequencyHz = frequencyHz(valid);
codePp = codePp(valid);
fitR2 = fitR2(valid);
fitRmsCode = fitRmsCode(valid);
if numel(frequencyHz) < 2
    error('At least two valid frequency points are required.');
end

reference = frequencyHz <= config.referenceUpperFrequencyHz;
if ~any(reference)
    reference = true(size(frequencyHz));
end
referenceCodePp = median(codePp(reference));
relativeDb = 20 * log10(codePp / referenceCodePp);
bandwidth3dBHz = findThreeDbCrossing(frequencyHz, relativeDb);

results = table(string(fileNames(:)), frequencyHz, codePp, relativeDb, ...
    fitR2, fitRmsCode, repmat(bandwidth3dBHz, numel(frequencyHz), 1), ...
    'VariableNames', {'FileName', 'FrequencyHz', 'CodePp', 'RelativeDb', ...
    'FitR2', 'FitResidualRmsCode', 'Bandwidth3dBHz'});
disp(results);
fprintf('\nEstimated -3 dB bandwidth: %.9g Hz\n', bandwidth3dBHz);
writetable(results, fullfile(pathName, 'ADC_bandwidth_sinefit_summary.csv'));
plotBandwidthResult(frequencyHz, codePp, relativeDb, bandwidth3dBHz, ...
    pathName, config);
end

function plotBandwidthResult(frequencyHz, codePp, relativeDb, bandwidth3dBHz, ...
        pathName, config)
if ~config.saveFigures && ~config.showFitFigure
    return;
end
if config.showFitFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Name', 'AD9245 bandwidth', ...
    'NumberTitle', 'off', 'Visible', visibility);
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('AD9245 amplitude response, Fs = %.3f MHz', ...
    config.sampleRate / 1e6));
nexttile;
semilogx(frequencyHz, codePp, 'bo-', 'LineWidth', 1.2, ...
    'MarkerFaceColor', 'b');
grid on;
xlabel('Input frequency (Hz)');
ylabel('Fitted Code_{pp} (LSB)');
title('Fitted ADC-code peak-to-peak amplitude');
nexttile;
semilogx(frequencyHz, relativeDb, 'ro-', 'LineWidth', 1.2, ...
    'MarkerFaceColor', 'r');
hold on;
yline(-3, 'k--', '-3 dB');
if isfinite(bandwidth3dBHz)
    xline(bandwidth3dBHz, 'g--', ...
        sprintf('-3 dB = %.6g MHz', bandwidth3dBHz / 1e6));
end
hold off;
grid on;
xlabel('Input frequency (Hz)');
ylabel('Relative amplitude (dB)');
title('Normalized amplitude response');
if config.saveFigures
    exportgraphics(figureHandle, ...
        fullfile(pathName, 'ADC_bandwidth_sinefit_response.png'), ...
        'Resolution', 180);
    savefig(figureHandle, ...
        fullfile(pathName, 'ADC_bandwidth_sinefit_response.fig'));
end
end

function results = runIsolationAnalysis(config, inputFolder, selectedFileNames)
if nargin < 2 || isempty(inputFolder)
    inputFolder = config.defaultIsolationFolder;
end
[fileNames, pathName] = chooseCsvFiles(inputFolder, selectedFileNames, ...
    'Select four AD9245 isolation CSV files', inputFolder);
if isempty(fileNames)
    results = table;
    return;
end

hasChannel = cellfun(@(name) strlength(extractChannelName(name)) > 0, fileNames);
if any(~hasChannel)
    ignoredNames = fileNames(~hasChannel);
    fprintf('Ignored CSV files without an X1G-X4G channel token:\n');
    fprintf('  %s\n', ignoredNames{:});
    fileNames = fileNames(hasChannel);
end
if isempty(fileNames)
    error('No X1G-X4G channel CSV file was selected.');
end

channelNames = strings(numel(fileNames), 1);
codePp = zeros(numel(fileNames), 1);
fitR2 = zeros(numel(fileNames), 1);
fitRmsCode = zeros(numel(fileNames), 1);
for fileIndex = 1:numel(fileNames)
    channelNames(fileIndex) = extractChannelName(fileNames{fileIndex});
    if strlength(channelNames(fileIndex)) == 0
        error('Cannot identify X1G-X4G channel from %s.', fileNames{fileIndex});
    end
    adcCode = readAdcCode(fullfile(pathName, fileNames{fileIndex}), ...
        config.adcDataColumn);
    fitConfig = setFitMode(config, 'known');
    fitConfig.knownFrequencyHz = config.isolationFrequencyHz;
    metrics = analyze_adc_metrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitRmsCode(fileIndex) = metrics.fit.residualRmsCode;
end

allChannels = ["X1G"; "X2G"; "X3G"; "X4G"];
isolationMatrix = NaN(4, 4);
drivenIndex = find(allChannels == string(config.drivenChannel), 1);
if isempty(drivenIndex) || ~any(channelNames == allChannels(drivenIndex))
    error('Configured driven channel %s was not found.', config.drivenChannel);
end
drivenCodePp = codePp(channelNames == allChannels(drivenIndex));
quietMask = channelNames ~= allChannels(drivenIndex);
quietChannels = channelNames(quietMask);
quietCodePp = codePp(quietMask);
isolationDb = 20 * log10(drivenCodePp ./ quietCodePp);
isolationMatrix(drivenIndex, allChannels ~= allChannels(drivenIndex)) = ...
    isolationDb;
pass = isolationDb > config.minimumIsolationDb;

results = table(repmat(allChannels(drivenIndex), numel(quietChannels), 1), ...
    quietChannels, repmat(config.isolationFrequencyHz, numel(quietChannels), 1), ...
    repmat(drivenCodePp, numel(quietChannels), 1), quietCodePp, isolationDb, ...
    fitR2(quietMask), fitRmsCode(quietMask), pass, ...
    'VariableNames', {'DrivenChannel', 'QuietChannel', 'FrequencyHz', ...
    'DrivenCodePp', 'QuietCodePp', 'IsolationDb', 'QuietFitR2', ...
    'QuietResidualRmsCode', 'Pass'});
disp(results);
fprintf('\nWorst isolation: %.3f dB\n', min(isolationDb));
writetable(results, fullfile(pathName, 'AD9245_isolation_summary.csv'));
plotIsolationMatrix(isolationMatrix, allChannels, pathName, config);
end

function results = runPowerScaleAnalysis(config, inputFolder, selectedFileNames)
if nargin < 2 || isempty(inputFolder)
    inputFolder = config.defaultPowerScaleFolder;
end
[fileNames, pathName] = chooseCsvFiles(inputFolder, selectedFileNames, ...
    'Select ADC input-power CSV files', inputFolder);
if isempty(fileNames)
    results = table;
    return;
end

hasPower = cellfun(@(name) isfinite(extractInputPowerFromFileName(name)), fileNames);
if any(~hasPower)
    ignoredNames = fileNames(~hasPower);
    fprintf('Ignored CSV files without a dBm power token:\n');
    fprintf('  %s\n', ignoredNames{:});
    fileNames = fileNames(hasPower);
end
if isempty(fileNames)
    error('No CSV file with a dBm power token was selected.');
end

fileCount = numel(fileNames);
inputPowerDbm = zeros(fileCount, 1);
frequencyHz = repmat(config.powerScaleFrequencyHz, fileCount, 1);
channelNames = strings(fileCount, 1);
codePp = zeros(fileCount, 1);
codeRms = zeros(fileCount, 1);
codeRmsDbfs = zeros(fileCount, 1);
peakCode = zeros(fileCount, 1);
valleyCode = zeros(fileCount, 1);
fitR2 = zeros(fileCount, 1);
fitRmsCode = zeros(fileCount, 1);
nearFullScaleFraction = zeros(fileCount, 1);

for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(pathName, fileName);
    inputPowerDbm(fileIndex) = extractInputPowerFromFileName(fileName);
    header = readCsvHeader(filePath);
    channelNames(fileIndex) = detectAdcChannel(header, fileName, pathName);
    adcCode = readAdcCode(filePath, config.adcDataColumn);

    fitConfig = setFitMode(config, 'known');
    fitConfig.knownFrequencyHz = config.powerScaleFrequencyHz;
    metrics = analyze_adc_metrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    codeRms(fileIndex) = codePp(fileIndex) / (2 * sqrt(2));
    codeRmsDbfs(fileIndex) = 20 * log10(codeRms(fileIndex) / ...
        config.adcFullScalePeakCode);
    peakCode(fileIndex) = metrics.fit.peakCode;
    valleyCode(fileIndex) = metrics.fit.valleyCode;
    fitR2(fileIndex) = metrics.fit.r2;
    fitRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    nearFullScaleFraction(fileIndex) = mean(abs(adcCode) >= ...
        config.clippingThreshold * config.adcFullScalePeakCode);
end

[inputPowerDbm, sortIndex] = sort(inputPowerDbm);
fileNames = fileNames(sortIndex);
frequencyHz = frequencyHz(sortIndex);
channelNames = channelNames(sortIndex);
codePp = codePp(sortIndex);
codeRms = codeRms(sortIndex);
codeRmsDbfs = codeRmsDbfs(sortIndex);
peakCode = peakCode(sortIndex);
valleyCode = valleyCode(sortIndex);
fitR2 = fitR2(sortIndex);
fitRmsCode = fitRmsCode(sortIndex);
nearFullScaleFraction = nearFullScaleFraction(sortIndex);

clippingFlag = nearFullScaleFraction > config.clippingFractionLimit;
plateauFlag = false(fileCount, 1);
for fileIndex = 2:fileCount
    relativeChange = abs(codePp(fileIndex) - codePp(fileIndex-1)) / ...
        max(codePp(fileIndex-1), eps);
    plateauFlag(fileIndex) = relativeChange <= config.plateauChangeThreshold;
end
inSpecifiedRange = inputPowerDbm >= config.powerRangeDbm(1) & ...
    inputPowerDbm <= config.powerRangeDbm(2);
calibrationIncluded = inSpecifiedRange & ~clippingFlag & ~plateauFlag;

if nnz(calibrationIncluded) < 2
    error('At least two usable power points are required for calibration.');
end
calibrationCoefficient = polyfit(inputPowerDbm(calibrationIncluded), ...
    codeRmsDbfs(calibrationIncluded), 1);
calibrationPredictedDbfs = polyval(calibrationCoefficient, inputPowerDbm);
calibrationResidualDb = codeRmsDbfs - calibrationPredictedDbfs;
calibrationResidual = calibrationResidualDb(calibrationIncluded);
calibrationMeasured = codeRmsDbfs(calibrationIncluded);
calibrationR2 = 1 - sum(calibrationResidual.^2) / ...
    max(sum((calibrationMeasured - mean(calibrationMeasured)).^2), eps);

uniqueChannels = unique(channelNames);
if numel(uniqueChannels) ~= 1
    warning('Multiple ADC channels were found; using the first channel in the output name.');
end
channelName = uniqueChannels(1);
results = table(repmat(channelName, fileCount, 1), string(fileNames(:)), ...
    inputPowerDbm, frequencyHz, codePp, codeRms, codeRmsDbfs, peakCode, ...
    valleyCode, fitR2, fitRmsCode, nearFullScaleFraction, clippingFlag, ...
    plateauFlag, inSpecifiedRange, calibrationIncluded, calibrationResidualDb, ...
    repmat(calibrationCoefficient(1), fileCount, 1), ...
    repmat(calibrationCoefficient(2), fileCount, 1), ...
    repmat(calibrationR2, fileCount, 1), ...
    'VariableNames', {'Channel', 'FileName', 'InputPowerDbm', 'FrequencyHz', ...
    'CodePp', 'CodeRms', 'CodeRmsDbfs', 'PeakCode', 'ValleyCode', ...
    'FitR2', 'FitResidualRmsCode', 'NearFullScaleFraction', ...
    'ClippingFlag', 'PlateauFlag', 'InSpecifiedRange', ...
    'CalibrationIncluded', 'CalibrationResidualDb', ...
    'CalibrationSlopeDbPerDbm', 'CalibrationInterceptDb', ...
    'CalibrationR2'});
disp(results);
fprintf('\nChannel: %s\n', channelName);
fprintf('Calibration slope: %.6f dB/dBm\n', calibrationCoefficient(1));
fprintf('Calibration intercept: %.6f dBFS\n', calibrationCoefficient(2));
fprintf('Calibration R^2: %.8f\n', calibrationR2);
fprintf('Calibration points: %d of %d\n', nnz(calibrationIncluded), fileCount);

outputStem = fullfile(pathName, ['AD9245_power_scale_' char(channelName)]);
writetable(results, [outputStem '_summary.csv']);
plotPowerScaleResult(results, calibrationCoefficient, calibrationR2, ...
    outputStem, config);
end

function plotPowerScaleResult(results, coefficient, calibrationR2, outputStem, config)
if ~config.saveFigures && ~config.showFitFigure
    return;
end
if config.showFitFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Name', 'AD9245 input power scale', ...
    'NumberTitle', 'off', 'Visible', visibility);
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, sprintf('%s | %.3f MHz input-power response', ...
    results.Channel(1), results.FrequencyHz(1) / 1e6));

nexttile;
plot(results.InputPowerDbm, results.CodePp, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
plot(results.InputPowerDbm(results.ClippingFlag), ...
    results.CodePp(results.ClippingFlag), 'rx', ...
    'LineWidth', 1.8, 'MarkerSize', 10);
plot(results.InputPowerDbm(results.PlateauFlag), ...
    results.CodePp(results.PlateauFlag), 'ks', ...
    'LineWidth', 1.4, 'MarkerSize', 8);
xline(config.powerRangeDbm(1), 'k--');
xline(config.powerRangeDbm(2), 'k--');
fitPower = linspace(config.powerRangeDbm(1), config.powerRangeDbm(2), 100);
fitDbfs = polyval(coefficient, fitPower);
fitCodeRms = config.adcFullScalePeakCode * 10.^(fitDbfs / 20);
plot(fitPower, fitCodeRms * 2 * sqrt(2), 'g-', 'LineWidth', 1.2);
hold off;
grid on;
xlabel('Input power (dBm)');
ylabel('Fitted Code_{pp} (LSB)');
title('ADC code response');
legend('Measured', 'Clipping', 'Plateau', 'Test range', '', 'Linear fit', ...
    'Location', 'best');

nexttile;
plot(results.InputPowerDbm, results.CodeRmsDbfs, 'ro-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
plot(results.InputPowerDbm(results.ClippingFlag), ...
    results.CodeRmsDbfs(results.ClippingFlag), 'rx', ...
    'LineWidth', 1.8, 'MarkerSize', 10);
plot(results.InputPowerDbm(results.PlateauFlag), ...
    results.CodeRmsDbfs(results.PlateauFlag), 'ks', ...
    'LineWidth', 1.4, 'MarkerSize', 8);
plot(fitPower, fitDbfs, 'g-', 'LineWidth', 1.2);
xline(config.powerRangeDbm(1), 'k--');
xline(config.powerRangeDbm(2), 'k--');
hold off;
grid on;
xlabel('Input power (dBm)');
ylabel('ADC RMS amplitude (dBFS)');
title(sprintf('dBFS response | slope = %.3f dB/dBm | R^2 = %.5f', ...
    coefficient(1), calibrationR2));
legend('Measured', 'Clipping', 'Plateau', 'Linear fit', 'Test range', ...
    'Location', 'best');

if config.saveFigures
    exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 180);
    savefig(figureHandle, [outputStem '.fig']);
end
end

function plotIsolationMatrix(isolationMatrix, channelNames, pathName, config)
if ~config.saveFigures && ~config.showFitFigure
    return;
end
if config.showFitFigure
    visibility = 'on';
else
    visibility = 'off';
end
figureHandle = figure('Color', 'w', 'Name', 'AD9245 isolation', ...
    'NumberTitle', 'off', 'Visible', visibility);
imageHandle = imagesc(isolationMatrix);
imageHandle.AlphaData = isfinite(isolationMatrix);
set(gca, 'Color', [0.88 0.88 0.88]);
axis equal tight;
colorbar;
colormap(parula);
xlabel('Quiet channel');
ylabel('Driven channel');
title(sprintf('AD9245 isolation at %.3f MHz (requirement > %.1f dB)', ...
    config.isolationFrequencyHz / 1e6, config.minimumIsolationDb));
set(gca, 'XTick', 1:4, 'XTickLabel', channelNames, ...
    'YTick', 1:4, 'YTickLabel', channelNames, 'FontSize', 12);
hold on;
for row = 1:4
    for column = 1:4
        if isfinite(isolationMatrix(row, column))
            text(column, row, sprintf('%.2f', isolationMatrix(row, column)), ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
                'Color', 'w');
        else
            text(column, row, '-', 'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
        end
    end
end
hold off;
if config.saveFigures
    exportgraphics(figureHandle, ...
        fullfile(pathName, 'AD9245_isolation_matrix.png'), ...
        'Resolution', 180);
    savefig(figureHandle, ...
        fullfile(pathName, 'AD9245_isolation_matrix.fig'));
end
end

function [fileNames, pathName] = chooseCsvFiles(inputFolder, selectedFileNames, ...
        dialogTitle, initialPath)
if ~isempty(inputFolder)
    pathName = char(inputFolder);
    if ~isempty(selectedFileNames)
        if ischar(selectedFileNames) || isstring(selectedFileNames)
            fileNames = cellstr(selectedFileNames);
        else
            fileNames = selectedFileNames;
        end
    else
        listing = dir(fullfile(pathName, '*.csv'));
        fileNames = {listing.name};
    end
    return;
end

[fileNames, pathName] = uigetfile(fullfile(initialPath, '*.csv'), ...
    dialogTitle, 'MultiSelect', 'on');
if isequal(fileNames, 0)
    fileNames = {};
elseif ~iscell(fileNames)
    fileNames = {fileNames};
end
end

function adcCode = readAdcCode(filePath, dataColumn)
numericData = readmatrix(filePath);
if isempty(numericData)
    error('No numeric data found in %s.', filePath);
end
if dataColumn == 0
    dataColumn = size(numericData, 2);
end
if dataColumn < 1 || dataColumn > size(numericData, 2)
    error('ADC data column is outside the CSV range.');
end
adcCode = double(numericData(:, dataColumn));
adcCode = adcCode(isfinite(adcCode));
end

function config = setFitMode(config, fitMode)
config.fitMode = fitMode;
end

function frequencyHz = extractFrequencyFromFileName(fileName)
token = regexp(char(fileName), ...
    '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz)', 'tokens', 'once');
if isempty(token)
    frequencyHz = NaN;
    return;
end
scales = struct('hz', 1, 'khz', 1e3, 'mhz', 1e6, 'ghz', 1e9);
frequencyHz = str2double(token{1}) * scales.(lower(token{2}));
end

function powerDbm = extractInputPowerFromFileName(fileName)
% Extract an input power value such as -10dBm or 10.8 dBm from a filename.
token = regexp(char(fileName), ...
    '(?i)(-?\d+(?:\.\d+)?)\s*dBm', 'tokens', 'once');
if isempty(token)
    powerDbm = NaN;
else
    powerDbm = str2double(token{1});
end
end

function header = readCsvHeader(filePath)
% Read only the first line of a CSV file for channel identification.
fileId = fopen(filePath, 'r');
if fileId < 0
    error('Cannot open CSV file: %s', filePath);
end
header = fgetl(fileId);
fclose(fileId);
if ~ischar(header)
    error('CSV file has no readable header: %s', filePath);
end
end

function channelName = detectAdcChannel(header, fileName, pathName)
% Identify X1G-X4G from ad9245_test_module[index], then use path fallback.
moduleToken = regexp(char(header), ...
    '(?i)ad9245_test_module\[(\d+)\]', 'tokens', 'once');
if ~isempty(moduleToken)
    moduleIndex = str2double(moduleToken{1});
    if isfinite(moduleIndex) && moduleIndex >= 0 && moduleIndex <= 3
        channelName = "X" + string(moduleIndex + 1) + "G";
        return;
    end
end

channelName = extractChannelName(fileName);
if strlength(channelName) == 0
    channelName = extractChannelName(pathName);
end
if strlength(channelName) == 0
    channelName = "Unknown";
end
end

function channelName = extractChannelName(fileName)
token = regexp(upper(char(fileName)), 'X([1-4])G', 'tokens', 'once');
if isempty(token)
    channelName = "";
else
    channelName = "X" + string(token{1}) + "G";
end
end

function bandwidthHz = findThreeDbCrossing(frequencyHz, relativeDb)
crossingIndex = find(relativeDb(1:end-1) >= -3 & ...
    relativeDb(2:end) <= -3, 1, 'first');
if isempty(crossingIndex)
    bandwidthHz = NaN;
    return;
end
f1 = frequencyHz(crossingIndex);
f2 = frequencyHz(crossingIndex + 1);
db1 = relativeDb(crossingIndex);
db2 = relativeDb(crossingIndex + 1);
bandwidthHz = f1 + (-3 - db1) * (f2 - f1) / (db2 - db1);
end

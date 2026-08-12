function run_ad766_full_analysis
%RUN_AD766_FULL_ANALYSIS Recalculate AD766 linearity and output noise.

bundleFolder = fileparts(mfilename('fullpath'));
projectFolder = fileparts(fileparts(bundleFolder));
dataRoot = fullfile(projectFolder, '02_Data_测试数据', '766');
linearityFolder = fullfile(bundleFolder, 'AD766_Linearity');
noiseFolder = fullfile(bundleFolder, 'AD766_Noise');
logFolder = fullfile(bundleFolder, 'Logs');

set(groot, 'defaultFigureVisible', 'off');
diary(fullfile(logFolder, 'AD766_matlab_run.log'));
cleanupObject = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('MATLAB version: %s\n', version);
fprintf('AD766 analysis started: %s\n', datestr(now, 31));

analyzeLinearity( ...
    fullfile(dataRoot, 'INL', 'X9', 'RTB2004_CHAN2.csv'), ...
    linearityFolder);

noiseFiles = {
    fullfile(dataRoot, 'NOISE', '6V_7FFF_DC.csv')
    fullfile(dataRoot, 'NOISE', 'CODE_8000_DC.csv')
    };
analyzeNoise(noiseFiles, noiseFolder);

fprintf('AD766 analysis completed: %s\n', datestr(now, 31));
end

function analyzeLinearity(filePath, outputFolder)
fprintf('\nReading linearity file: %s\n', filePath);
data = readmatrix(filePath);
timeS = data(:, 1);
voltageV = data(:, end);
valid = isfinite(timeS) & isfinite(voltageV);
timeS = timeS(valid);
voltageV = voltageV(valid);

sampleCount = numel(voltageV);
halfIndex = floor(sampleCount / 2);
[~, localMinimumIndex] = min(voltageV(1:halfIndex));
[~, localMaximumIndex] = max(voltageV(halfIndex + 1:end));
maximumIndex = halfIndex + localMaximumIndex;

if maximumIndex <= localMinimumIndex
    error('Unable to locate a valid rising ramp in %s.', filePath);
end

rampVoltageV = voltageV(localMinimumIndex:maximumIndex);
rampIndex = (0:numel(rampVoltageV) - 1)';
coefficient = polyfit(rampIndex, rampVoltageV, 1);
fitVoltageV = polyval(coefficient, rampIndex);
residualV = rampVoltageV - fitVoltageV;

sumSquaredError = sum(residualV .^ 2);
sumSquaredTotal = sum((rampVoltageV - mean(rampVoltageV)) .^ 2);
fitR2 = 1 - sumSquaredError / sumSquaredTotal;

summary = table( ...
    string(getFileName(filePath)), sampleCount, ...
    median(diff(timeS)), 1 / median(diff(timeS)), ...
    min(rampVoltageV), max(rampVoltageV), ...
    coefficient(1), coefficient(2), fitR2, ...
    min(residualV), max(residualV), ...
    max(abs(residualV)), max(residualV) - min(residualV), ...
    'VariableNames', { ...
    'FileName', 'SampleCount', 'SampleIntervalS', 'SampleRateHz', ...
    'RampMinimumV', 'RampMaximumV', 'SlopeVPerSample', ...
    'InterceptV', 'FitR2', 'MinimumResidualV', 'MaximumResidualV', ...
    'MaximumAbsoluteResidualV', 'ResidualPeakToPeakV'});
writetable(summary, fullfile(outputFolder, 'AD766_linearity_summary.csv'));

figureHandle = figure('Color', 'w', 'Position', [100 100 1200 760]);
subplot(2, 1, 1);
plot(rampIndex, rampVoltageV, 'b-', 'LineWidth', 0.8);
hold on;
plot(rampIndex, fitVoltageV, 'r--', 'LineWidth', 1.2);
hold off;
grid on;
xlabel('Relative sample index');
ylabel('Output voltage (V)');
title('AD766 X9 rising ramp and linear fit');
legend('Measured', 'Linear fit', 'Location', 'best');

subplot(2, 1, 2);
plot(rampIndex, residualV * 1e3, 'k-', 'LineWidth', 0.8);
grid on;
xlabel('Relative sample index');
ylabel('Fit residual (mV)');
title(sprintf(['Voltage residual: max |error| = %.3f mV, ' ...
    'peak-to-peak = %.3f mV, R^2 = %.8f'], ...
    max(abs(residualV)) * 1e3, ...
    (max(residualV) - min(residualV)) * 1e3, fitR2));

outputStem = fullfile(outputFolder, 'AD766_X9_linearity_result');
exportgraphics(figureHandle, [outputStem '.png'], 'Resolution', 220);
savefig(figureHandle, [outputStem '.fig']);
close(figureHandle);

disp(summary);
end

function analyzeNoise(filePaths, outputFolder)
fileCount = numel(filePaths);
fileName = strings(fileCount, 1);
sampleCount = zeros(fileCount, 1);
sampleIntervalS = zeros(fileCount, 1);
sampleRateHz = zeros(fileCount, 1);
durationS = zeros(fileCount, 1);
meanVoltageV = zeros(fileCount, 1);
noiseRmsV = zeros(fileCount, 1);
noisePeakToPeakV = zeros(fileCount, 1);
asdAt1HzVPerSqrtHz = zeros(fileCount, 1);
integratedNoise1kTo100kVrms = zeros(fileCount, 1);
asdPass = false(fileCount, 1);
integratedPass = false(fileCount, 1);
welchWindowSamples = zeros(fileCount, 1);
frequencyResolutionHz = zeros(fileCount, 1);

for fileIndex = 1:fileCount
    filePath = filePaths{fileIndex};
    fprintf('\nReading noise file: %s\n', filePath);
    data = readmatrix(filePath);
    timeS = data(:, 1);
    voltageV = data(:, end);
    valid = isfinite(timeS) & isfinite(voltageV);
    timeS = timeS(valid);
    voltageV = voltageV(valid);

    dt = median(diff(timeS));
    fs = 1 / dt;
    signalV = voltageV - mean(voltageV);

    % Four-second Hann records provide approximately 0.25 Hz native
    % resolution while retaining multiple averages in the 24 s record.
    windowLength = min(numel(signalV), max(1024, round(4 * fs)));
    windowLength = windowLength - mod(windowLength, 2);
    overlapLength = floor(windowLength / 2);
    nfft = 2 ^ nextpow2(windowLength);
    [psdV2PerHz, frequencyHz] = pwelch(signalV, ...
        hann(windowLength, 'periodic'), overlapLength, nfft, fs, ...
        'onesided');
    asdVPerSqrtHz = sqrt(psdV2PerHz);

    asd1Hz = interp1(frequencyHz, asdVPerSqrtHz, 1, ...
        'linear', 'extrap');
    bandMask = frequencyHz >= 1e3 & frequencyHz <= 100e3;
    integratedNoise = sqrt(trapz( ...
        frequencyHz(bandMask), psdV2PerHz(bandMask)));

    fileName(fileIndex) = string(getFileName(filePath));
    sampleCount(fileIndex) = numel(signalV);
    sampleIntervalS(fileIndex) = dt;
    sampleRateHz(fileIndex) = fs;
    durationS(fileIndex) = timeS(end) - timeS(1);
    meanVoltageV(fileIndex) = mean(voltageV);
    noiseRmsV(fileIndex) = sqrt(mean(signalV .^ 2));
    noisePeakToPeakV(fileIndex) = max(signalV) - min(signalV);
    asdAt1HzVPerSqrtHz(fileIndex) = asd1Hz;
    integratedNoise1kTo100kVrms(fileIndex) = integratedNoise;
    asdPass(fileIndex) = asd1Hz < 12e-6;
    integratedPass(fileIndex) = integratedNoise < 1e-3;
    welchWindowSamples(fileIndex) = windowLength;
    frequencyResolutionHz(fileIndex) = fs / nfft;

    figureHandle = figure('Color', 'w', ...
        'Position', [100 100 1200 700]);
    loglog(frequencyHz(2:end), asdVPerSqrtHz(2:end) * 1e6, ...
        'b-', 'LineWidth', 0.9);
    hold on;
    plot(1, asd1Hz * 1e6, 'ro', 'MarkerFaceColor', 'r');
    plot([frequencyHz(2) frequencyHz(end)], [12 12], ...
        'r--', 'LineWidth', 1.0);
    hold off;
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Output noise ASD (\muV/\surdHz)');
    title(sprintf(['%s | ASD@1 Hz = %.3f \\muV/\\surdHz | ' ...
        '1 kHz-100 kHz = %.3f mVrms'], ...
        getFileName(filePath), asd1Hz * 1e6, integratedNoise * 1e3), ...
        'Interpreter', 'none');
    legend('Measured ASD', '1 Hz', '12 \muV/\surdHz limit', ...
        'Location', 'best');
    xlim([max(frequencyHz(2), 0.1), fs / 2]);

    [~, stemName] = fileparts(filePath);
    outputStem = fullfile(outputFolder, ...
        ['AD766_noise_' stemName]);
    exportgraphics(figureHandle, [outputStem '.png'], ...
        'Resolution', 220);
    savefig(figureHandle, [outputStem '.fig']);
    close(figureHandle);

    clear data timeS voltageV signalV psdV2PerHz frequencyHz
end

summary = table(fileName, sampleCount, sampleIntervalS, sampleRateHz, ...
    durationS, meanVoltageV, noiseRmsV, noisePeakToPeakV, ...
    asdAt1HzVPerSqrtHz, integratedNoise1kTo100kVrms, ...
    asdPass, integratedPass, welchWindowSamples, ...
    frequencyResolutionHz);
writetable(summary, fullfile(outputFolder, 'AD766_noise_summary.csv'));
disp(summary);
end

function fileName = getFileName(filePath)
[~, stem, extension] = fileparts(filePath);
fileName = [stem extension];
end

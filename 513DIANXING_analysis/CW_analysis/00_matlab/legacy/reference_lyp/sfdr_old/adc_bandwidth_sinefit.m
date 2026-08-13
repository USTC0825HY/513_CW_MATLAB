function results = adc_bandwidth_sinefit(inputFolder, selectedFileNames)
%adc_bandwidth_sinefit - Estimate ADC amplitude response and -3 dB bandwidth
%   RESULTS = adc_bandwidth_sinefit opens a GUI to select CSV files. The
%   excitation frequency is extracted automatically from each file name,
%   for example 100kHz.csv, 1MHz.csv, or 10Mhz_1.csv.
%
%   RESULTS = adc_bandwidth_sinefit(INPUTFOLDER, FILENAMES) processes the
%   specified files without opening the file-selection dialog. This form is
%   useful for repeatable batch processing and example-data verification.
%
%   The default sampling clock is 25 MHz. Edit the user parameters below
%   when the acquisition setup is different.

%% User parameters
sampleRate = 25e6;             % ADC sampling clock, Hz
fitCycles = 20;                % Minimum number of fitted sine cycles
minimumFitSamples = 1024;      % Avoid fitting too few samples
adcDataColumn = 0;             % 0 = use the last CSV column
showFitFigures = false;        % Avoid opening one window per batch file
minimumFitR2 = 0.99;           % Reject visibly failed sine fits for bandwidth
referenceUpperFrequencyHz = 1e6; % Low-frequency reference band upper limit

%% Select CSV files
if nargin < 1 || isempty(inputFolder)
    initialPath = fileparts(mfilename('fullpath'));
    [fileNames, pathName] = uigetfile( ...
        fullfile(initialPath, '*.csv'), ...
        'Select ADC CSV files; frequency is read from each file name', ...
        'MultiSelect', 'on');

    if isequal(fileNames, 0)
        fprintf('No file selected. Analysis cancelled.\n');
        results = table;
        return;
    end

    if ~iscell(fileNames)
        fileNames = {fileNames};
    end
else
    pathName = char(inputFolder);
    if nargin < 2 || isempty(selectedFileNames)
        directoryListing = dir(fullfile(pathName, '*.csv'));
        fileNames = {directoryListing.name};
        % Ignore previous result tables when processing a whole directory.
        fileNames = fileNames(cellfun(@(name) ...
            isfinite(extractFrequencyFromFileName(name)), fileNames));
    elseif ischar(selectedFileNames) || isstring(selectedFileNames)
        fileNames = cellstr(selectedFileNames);
    else
        fileNames = selectedFileNames;
    end
end

% Extract the excitation frequency from each selected file name.
fileCount = numel(fileNames);
frequencyHz = zeros(fileCount, 1);
for fileIndex = 1:fileCount
    frequencyHz(fileIndex) = extractFrequencyFromFileName(fileNames{fileIndex});
    if ~isfinite(frequencyHz(fileIndex)) || frequencyHz(fileIndex) <= 0
        error(['Cannot extract a positive frequency from file name "%s". ' ...
            'Use a name such as 100kHz.csv or 1MHz.csv.'], fileNames{fileIndex});
    end
end

if sampleRate <= 2 * max(frequencyHz)
    warning(['At least one frequency is at or above the Nyquist limit. ' ...
        'Check sampleRate and excitation frequencies.']);
end

%% Preallocate result arrays
fitFrequencyHz = zeros(fileCount, 1);
sampleCount = zeros(fileCount, 1);
samplesPerCycle = zeros(fileCount, 1);
fitSampleCount = zeros(fileCount, 1);
peakToPeakCode = zeros(fileCount, 1);
fitRmsCode = zeros(fileCount, 1);
fitR2 = zeros(fileCount, 1);

%% Fit a sine wave to each CSV file
for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(pathName, fileName);
    numericData = readmatrix(filePath);

    if isempty(numericData)
        error('No numeric data found in %s.', filePath);
    end

    if adcDataColumn == 0
        dataColumn = size(numericData, 2);
    else
        dataColumn = adcDataColumn;
    end

    if dataColumn < 1 || dataColumn > size(numericData, 2)
        error('adcDataColumn is outside the CSV column range.');
    end

    adcCode = double(numericData(:, dataColumn));
    adcCode = adcCode(isfinite(adcCode));

    if numel(adcCode) < minimumFitSamples
        warning('File %s contains fewer than %d valid samples.', ...
            fileName, minimumFitSamples);
    end

    excitationFrequency = frequencyHz(fileIndex);
    samplesPerCycleValue = sampleRate / excitationFrequency;
    requestedSamples = round(samplesPerCycleValue * fitCycles);
    numberOfFitSamples = min(numel(adcCode), ...
        max(minimumFitSamples, requestedSamples));
    fitCode = adcCode(1:numberOfFitSamples);
    timeSamples = (0:numberOfFitSamples-1)' / sampleRate;

    % Known-frequency linear sine fit:
    % code(t) = A*sin(2*pi*f*t) + B*cos(2*pi*f*t) + C.
    % It estimates amplitude robustly even when only a few ADC samples
    % occur in each period, provided the excitation frequency is known.
    designMatrix = [ ...
        sin(2*pi*excitationFrequency*timeSamples), ...
        cos(2*pi*excitationFrequency*timeSamples), ...
        ones(numberOfFitSamples, 1)];
    fitCoefficient = designMatrix \ fitCode;
    fittedCode = designMatrix * fitCoefficient;
    residualCode = fitCode - fittedCode;

    fittedPeakAmplitude = hypot(fitCoefficient(1), fitCoefficient(2));
    fittedPeakToPeakCode = 2 * fittedPeakAmplitude;
    residualRmsCode = sqrt(mean(residualCode.^2));
    totalVariation = fitCode - mean(fitCode);
    fitR2Value = 1 - sum(residualCode.^2) / ...
        max(sum(totalVariation.^2), eps);

    fitFrequencyHz(fileIndex) = excitationFrequency;
    sampleCount(fileIndex) = numel(adcCode);
    samplesPerCycle(fileIndex) = samplesPerCycleValue;
    fitSampleCount(fileIndex) = numberOfFitSamples;
    peakToPeakCode(fileIndex) = fittedPeakToPeakCode;
    fitRmsCode(fileIndex) = residualRmsCode;
    fitR2(fileIndex) = fitR2Value;

    fprintf('\nFile: %s\n', fileName);
    fprintf('Excitation frequency: %.9g Hz\n', excitationFrequency);
    fprintf('Samples per cycle: %.4f\n', samplesPerCycleValue);
    fprintf('Fitted samples: %d\n', numberOfFitSamples);
    fprintf('Fitted peak-to-peak code: %.6f LSB\n', ...
        fittedPeakToPeakCode);
    fprintf('Fit residual RMS: %.6f LSB\n', residualRmsCode);
    fprintf('Fit R^2: %.8f\n', fitR2Value);

    if showFitFigures
        figure('Color', 'w', 'Name', ['Sine fit - ' fileName], ...
            'NumberTitle', 'off');
        plot(timeSamples * 1e6, fitCode, 'b.', ...
            'DisplayName', 'ADC code');
        hold on;
        plot(timeSamples * 1e6, fittedCode, 'r-', ...
            'LineWidth', 1.2, 'DisplayName', 'Known-frequency sine fit');
        hold off;
        grid on;
        xlabel('Time (us)');
        ylabel('ADC Code (LSB)');
        title(sprintf('%s | f = %.6g MHz | Vpp = %.3f LSB', ...
            fileName, excitationFrequency/1e6, fittedPeakToPeakCode), ...
            'Interpreter', 'none');
        legend('Location', 'best');
    end
end

%% Normalize amplitude and estimate -3 dB bandwidth
[fitFrequencyHz, sortIndex] = sort(fitFrequencyHz);
fileNames = fileNames(sortIndex);
sampleCount = sampleCount(sortIndex);
samplesPerCycle = samplesPerCycle(sortIndex);
fitSampleCount = fitSampleCount(sortIndex);
peakToPeakCode = peakToPeakCode(sortIndex);
fitRmsCode = fitRmsCode(sortIndex);
fitR2 = fitR2(sortIndex);

% Remove failed fits before normalization, plotting, and bandwidth interpolation.
invalidFit = ~isfinite(fitR2) | fitR2 < minimumFitR2 | ...
    ~isfinite(peakToPeakCode) | peakToPeakCode <= 0;
if any(invalidFit)
    removedFileNames = fileNames(invalidFit);
    fprintf('\nRemoved abnormal data files (Fit R^2 < %.2f or invalid Code_pp):\n', ...
        minimumFitR2);
    fprintf('  %s\n', removedFileNames{:});

    fileNames = fileNames(~invalidFit);
    fitFrequencyHz = fitFrequencyHz(~invalidFit);
    sampleCount = sampleCount(~invalidFit);
    samplesPerCycle = samplesPerCycle(~invalidFit);
    fitSampleCount = fitSampleCount(~invalidFit);
    peakToPeakCode = peakToPeakCode(~invalidFit);
    fitRmsCode = fitRmsCode(~invalidFit);
    fitR2 = fitR2(~invalidFit);
end

fileCount = numel(fileNames);
if fileCount < 2
    error('At least two valid frequency points are required for bandwidth analysis.');
end

% All rows that remain at this point are valid analysis data.
fitValidForBandwidth = isfinite(fitR2) & ...
    fitR2 >= minimumFitR2 & isfinite(peakToPeakCode) & peakToPeakCode > 0;
if any(fitValidForBandwidth & fitFrequencyHz <= referenceUpperFrequencyHz)
    referencePeakToPeakCode = median(peakToPeakCode( ...
        fitValidForBandwidth & fitFrequencyHz <= referenceUpperFrequencyHz));
else
    warning(['No valid point is available below the configured reference ' ...
        'frequency. Using the maximum valid fitted Code_pp instead.']);
    referencePeakToPeakCode = max(peakToPeakCode(fitValidForBandwidth));
end
relativeDb = 20 * log10(peakToPeakCode / referencePeakToPeakCode);
targetDb = -3;
validFrequencyHz = fitFrequencyHz(fitValidForBandwidth);
validRelativeDb = relativeDb(fitValidForBandwidth);
crossingIndex = find(validRelativeDb(1:end-1) >= targetDb & ...
    validRelativeDb(2:end) <= targetDb, 1, 'first');

if isempty(crossingIndex)
    bandwidth3dBHz = NaN;
    fprintf('\nNo -3 dB crossing is bracketed by valid fitted points.\n');
else
    f1 = validFrequencyHz(crossingIndex);
    f2 = validFrequencyHz(crossingIndex + 1);
    db1 = validRelativeDb(crossingIndex);
    db2 = validRelativeDb(crossingIndex + 1);
    bandwidth3dBHz = f1 + (targetDb-db1) * ...
        (f2-f1) / (db2-db1);
    fprintf('\nEstimated -3 dB bandwidth: %.9g Hz (%.6f MHz)\n', ...
        bandwidth3dBHz, bandwidth3dBHz/1e6);
end

bandwidth3dBResult = repmat(bandwidth3dBHz, fileCount, 1);

results = table( ...
    string(fileNames(:)), fitFrequencyHz, sampleCount, samplesPerCycle, ...
    fitSampleCount, peakToPeakCode, relativeDb, fitRmsCode, fitR2, ...
    fitValidForBandwidth, bandwidth3dBResult, ...
    'VariableNames', {'FileName', 'FrequencyHz', 'SampleCount', ...
    'SamplesPerCycle', 'FitSampleCount', 'PeakToPeakCode', ...
    'RelativeDb', 'FitResidualRmsCode', 'FitR2', ...
    'FitValidForBandwidth', 'Bandwidth3dBHz'});

disp(results);

%% Plot amplitude and relative dB response
figure('Color', 'w', 'Name', 'ADC amplitude response and bandwidth', ...
    'NumberTitle', 'off');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', ...
    'Padding', 'compact');
title(layout, sprintf('ADC amplitude response, Fs = %.6g MHz', ...
    sampleRate/1e6));

nexttile;
semilogx(fitFrequencyHz(fitValidForBandwidth), ...
    peakToPeakCode(fitValidForBandwidth), 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
if any(~fitValidForBandwidth)
    semilogx(fitFrequencyHz(~fitValidForBandwidth), ...
        peakToPeakCode(~fitValidForBandwidth), 'kx', ...
        'LineWidth', 1.8, 'MarkerSize', 10);
end
hold off;
grid on;
xlabel('Excitation Frequency (Hz)');
ylabel('Fitted Vpp (LSB)');
title('Fitted ADC-code peak-to-peak amplitude');

nexttile;
semilogx(fitFrequencyHz(fitValidForBandwidth), ...
    relativeDb(fitValidForBandwidth), 'ro-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
invalidIndex = ~fitValidForBandwidth;
if any(invalidIndex)
    semilogx(fitFrequencyHz(invalidIndex), relativeDb(invalidIndex), ...
        'kx', 'LineWidth', 1.8, 'MarkerSize', 10, ...
        'DisplayName', sprintf('Fit R^2 < %.2f', minimumFitR2));
end
yline(targetDb, 'k--', '-3 dB');
if isfinite(bandwidth3dBHz)
    xline(bandwidth3dBHz, 'g--', ...
        sprintf('-3 dB = %.6g MHz', bandwidth3dBHz/1e6));
end
hold off;
grid on;
xlabel('Excitation Frequency (Hz)');
ylabel('Relative Amplitude (dB)');
title('Normalized amplitude response');
legend('Measured response', 'Location', 'best');

% Save the bandwidth plot next to the input CSV files.
responsePng = fullfile(pathName, 'ADC_bandwidth_sinefit_response.png');
responseFig = fullfile(pathName, 'ADC_bandwidth_sinefit_response.fig');
exportgraphics(gcf, responsePng, 'Resolution', 200);
savefig(gcf, responseFig);
fprintf('Bandwidth plot saved to:\n%s\n', responsePng);

%% Save machine-readable summary next to the selected CSV files
summaryFile = fullfile(pathName, 'ADC_bandwidth_sinefit_summary.csv');
writetable(results, summaryFile);
fprintf('\nSummary saved to:\n%s\n', summaryFile);
end

function frequencyHz = extractFrequencyFromFileName(fileName)
%extractFrequencyFromFileName Extract the first frequency token from a name.
%   Supported units are Hz, kHz, MHz, and GHz, case-insensitively.

frequencyHz = NaN;
token = regexp(char(fileName), ...
    '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz)', 'tokens', 'once');
if isempty(token)
    return;
end

frequencyValue = str2double(token{1});
unit = lower(token{2});
unitScale = struct('hz', 1, 'khz', 1e3, 'mhz', 1e6, 'ghz', 1e9);
frequencyHz = frequencyValue * unitScale.(unit);
end

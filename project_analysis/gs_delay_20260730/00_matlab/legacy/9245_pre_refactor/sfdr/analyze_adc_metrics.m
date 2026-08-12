function metrics = analyze_adc_metrics(adcCode, config)
%ANALYZE_ADC_METRICS Calculate reusable ADC fitting and dynamic metrics.
%   METRICS = ANALYZE_ADC_METRICS(ADCCODE, CONFIG) analyzes ADC codes in
%   LSB. CONFIG.fitMode is either 'auto' for SFDR analysis or 'known' for
%   a known input frequency. The function does not read files or create
%   figures.
%
%   For known-frequency analysis, Code_pp is the fitted sine-wave
%   peak-to-peak code: Code_pp = 2*abs(A). For automatic analysis, the
%   fundamental is first located in the Hann-windowed FFT.

% MATLAB R2018 compatibility: use ordinary input checks instead of an
% arguments block (arguments was introduced after R2018).
if nargin < 2 || ~isstruct(config)
    error('CONFIG must be a structure.');
end
if ~isnumeric(adcCode) || ~isvector(adcCode)
    error('ADCCODE must be a numeric vector.');
end
adcCode = double(adcCode(:));

adcCode = adcCode(isfinite(adcCode));
if isempty(adcCode)
    error('ADC data contains no finite samples.');
end

if ~isfield(config, 'fitMode')
    config.fitMode = 'auto';
end

if strcmpi(config.fitMode, 'known')
    metrics = createKnownFrequencyMetrics(adcCode, config);
    return;
end

if ~strcmpi(config.fitMode, 'auto')
    error('config.fitMode must be ''auto'' or ''known''.');
end

metrics = createAutomaticFrequencyMetrics(adcCode, config);
end

function metrics = createAutomaticFrequencyMetrics(adcCode, config)
% Estimate the fundamental and calculate FFT-based dynamic metrics.

sampleRate = config.sampleRate;
fftLength = min(config.nfft, numel(adcCode));
if fftLength < 2 * config.signalSpan + 3
    error('Not enough samples for the configured FFT search span.');
end

signal = adcCode(1:fftLength);
signal = signal - mean(signal);
% Periodic Hann window written explicitly to avoid a toolbox dependency.
windowIndex = (0:fftLength-1)';
window = 0.5 - 0.5 * cos(2 * pi * windowIndex / fftLength);
fftData = fft(signal .* window);
oneSidedLength = floor(fftLength / 2) + 1;
oneSidedFft = fftData(1:oneSidedLength);
frequencyHz = (0:oneSidedLength-1)' * sampleRate / fftLength;
levelDb = 20 * log10(abs(oneSidedFft) + eps);

[fundamentalLevelDb, fundamentalIndex] = max(levelDb);
lowIndex = max(2, fundamentalIndex - config.signalSpan);
highIndex = min(oneSidedLength - 1, fundamentalIndex + config.signalSpan);
[~, accurateIndex] = find_accu_peak(levelDb, lowIndex, highIndex);
fundamentalFrequencyHz = (accurateIndex - 1) * sampleRate / fftLength;

fitConfig = config;
fitConfig.fitMode = 'known';
fitConfig.knownFrequencyHz = fundamentalFrequencyHz;
fit = createKnownFrequencyMetrics(adcCode, fitConfig).fit;

powerSpectrum = abs(oneSidedFft).^2 / fftLength / sampleRate;
dcIndices = 1:min(config.dcSpan, oneSidedLength);
signalIndices = max(1, fundamentalIndex-config.signalSpan): ...
    min(oneSidedLength, fundamentalIndex+config.signalSpan);
harmonicIndices = findHarmonicIndices(fundamentalIndex, fftLength, ...
    oneSidedLength, config);
harmonicIndices = setdiff(harmonicIndices, [dcIndices signalIndices]);

spurSpectrum = levelDb;
spurSpectrum([dcIndices signalIndices oneSidedLength]) = min(levelDb);
[largestSpurLevelDb, largestSpurIndex] = max(spurSpectrum);

totalPower = sum(powerSpectrum);
dcPower = sum(powerSpectrum(dcIndices));
signalPower = sum(powerSpectrum(signalIndices));
harmonicPower = sum(powerSpectrum(harmonicIndices));
noisePower = totalPower - dcPower - signalPower - harmonicPower;
noisePower = max(noisePower, eps);
noiseBinCount = oneSidedLength - numel(dcIndices) - ...
    numel(signalIndices) - numel(harmonicIndices);
noisePower = noisePower * oneSidedLength / max(noiseBinCount, 1);

sinadPower = max(totalPower - dcPower - signalPower, eps);
signalAmplitudeDbfs = 20 * log10(max(fit.amplitudeCode, eps) / ...
    config.adcFullScalePeakCode);

metrics.fit = fit;
metrics.spectrum = struct( ...
    'frequencyHz', frequencyHz, ...
    'levelDb', levelDb, ...
    'fundamentalFrequencyHz', fundamentalFrequencyHz, ...
    'fundamentalLevelDb', fundamentalLevelDb, ...
    'largestSpurFrequencyHz', frequencyHz(largestSpurIndex), ...
    'largestSpurLevelDb', largestSpurLevelDb, ...
    'fundamentalIndex', fundamentalIndex, ...
    'largestSpurIndex', largestSpurIndex, ...
    'signalIndices', signalIndices, ...
    'dcIndices', dcIndices, ...
    'harmonicIndices', harmonicIndices);
metrics.dynamic = struct( ...
    'SFDR', fundamentalLevelDb - largestSpurLevelDb, ...
    'SNR', 10 * log10(signalPower / noisePower), ...
    'SINAD', 10 * log10(signalPower / sinadPower), ...
    'THD', 10 * log10(max(signalPower, eps) / max(harmonicPower, eps)), ...
    'ENOB', (10 * log10(signalPower / sinadPower) - ...
    signalAmplitudeDbfs - 1.76) / 6.02, ...
    'signalAmplitudeDbfs', signalAmplitudeDbfs);
end

function metrics = createKnownFrequencyMetrics(adcCode, config)
% Fit a sine wave when the input frequency is known.

frequencyHz = config.knownFrequencyHz;
if ~isscalar(frequencyHz) || ~isfinite(frequencyHz) || frequencyHz <= 0
    error('config.knownFrequencyHz must be a positive finite scalar.');
end

samplesPerCycle = config.sampleRate / frequencyHz;
requestedSamples = round(samplesPerCycle * config.fitCycles);
fitSampleCount = min(numel(adcCode), ...
    max(config.minimumFitSamples, requestedSamples));
fitCode = adcCode(1:fitSampleCount);
timeSeconds = (0:fitSampleCount-1)' / config.sampleRate;

designMatrix = [ ...
    sin(2*pi*frequencyHz*timeSeconds), ...
    cos(2*pi*frequencyHz*timeSeconds), ...
    ones(fitSampleCount, 1)];
coefficient = designMatrix \ fitCode;
fittedCode = designMatrix * coefficient;
residualCode = fitCode - fittedCode;

amplitudeCode = hypot(coefficient(1), coefficient(2));
offsetCode = coefficient(3);
peakCode = offsetCode + amplitudeCode;
valleyCode = offsetCode - amplitudeCode;
codePp = 2 * amplitudeCode;
totalVariation = fitCode - mean(fitCode);
fitR2 = 1 - sum(residualCode.^2) / ...
    max(sum(totalVariation.^2), eps);

metrics.fit = struct( ...
    'frequencyHz', frequencyHz, ...
    'amplitudeCode', amplitudeCode, ...
    'codePp', codePp, ...
    'offsetCode', offsetCode, ...
    'peakCode', peakCode, ...
    'valleyCode', valleyCode, ...
    'r2', fitR2, ...
    'residualRmsCode', sqrt(mean(residualCode.^2)), ...
    'fitSampleCount', fitSampleCount, ...
    'samplesPerCycle', samplesPerCycle, ...
    'timeSeconds', timeSeconds, ...
    'fitCode', fitCode, ...
    'fittedCode', fittedCode);
metrics.spectrum = emptySpectrum();
metrics.dynamic = emptyDynamic();
end

function harmonicIndices = findHarmonicIndices(fundamentalIndex, fftLength, ...
        oneSidedLength, config)
harmonicMask = false(1, oneSidedLength);
for harmonicOrder = 2:config.maxHarmonicOrder
    harmonicIndex = mod(harmonicOrder * (fundamentalIndex - 1), fftLength) + 1;
    if harmonicIndex > oneSidedLength
        harmonicIndex = fftLength - harmonicIndex + 2;
    end
    lowerIndex = max(1, harmonicIndex - config.harmonicSpan);
    upperIndex = min(oneSidedLength, harmonicIndex + config.harmonicSpan);
    harmonicMask(lowerIndex:upperIndex) = true;
end
harmonicIndices = find(harmonicMask);
end

function spectrum = emptySpectrum()
spectrum = struct( ...
    'frequencyHz', [], 'levelDb', [], ...
    'fundamentalFrequencyHz', NaN, 'fundamentalLevelDb', NaN, ...
    'largestSpurFrequencyHz', NaN, 'largestSpurLevelDb', NaN, ...
    'fundamentalIndex', NaN, 'largestSpurIndex', NaN, ...
    'signalIndices', [], 'dcIndices', [], 'harmonicIndices', []);
end

function dynamic = emptyDynamic()
dynamic = struct('SFDR', NaN, 'SNR', NaN, 'SINAD', NaN, ...
    'THD', NaN, 'ENOB', NaN, 'signalAmplitudeDbfs', NaN);
end

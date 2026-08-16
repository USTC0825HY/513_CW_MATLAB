function metrics = analyzeDynamicMetrics(adcCode, config)
%ANALYZEDYNAMICMETRICS Calculate ADC fitting and dynamic metrics.

converter.runtime.validateConfig(config, {'sampleRate', 'fitMode'});
if ~isnumeric(adcCode) || ~isvector(adcCode)
    error('converter:adc:InvalidAdcCode', 'adcCode 必须是数值向量。');
end
adcCode = double(adcCode(:));
adcCode = adcCode(isfinite(adcCode));
if isempty(adcCode)
    error('converter:adc:NoFiniteSamples', 'ADC 数据没有有效样点。');
end

if strcmpi(config.fitMode, 'known')
    metrics = createKnownFrequencyMetrics(adcCode, config);
elseif strcmpi(config.fitMode, 'auto')
    metrics = createAutomaticFrequencyMetrics(adcCode, config);
else
    error('converter:adc:InvalidFitMode', 'fitMode 必须是 auto 或 known。');
end
end

function metrics = createAutomaticFrequencyMetrics(adcCode, config)
converter.runtime.validateConfig(config, {'nfft', 'adcFullScalePeakCode', ...
    'dcSpan', 'signalSpan', 'harmonicSpan', 'maxHarmonicOrder', ...
    'fitCycles', 'minimumFitSamples'});
sampleRate = config.sampleRate;
fftLength = min(config.nfft, numel(adcCode));
if fftLength < 2 * config.signalSpan + 3
    error('converter:adc:InsufficientFftSamples', ...
        '样点数不足以覆盖配置的 FFT 搜索范围。');
end

signal = adcCode(1:fftLength);
signal = signal - mean(signal);
windowIndex = (0:fftLength - 1)';
window = 0.5 - 0.5 * cos(2 * pi * windowIndex / fftLength);
fftData = fft(signal .* window);
oneSidedLength = floor(fftLength / 2) + 1;
oneSidedFft = fftData(1:oneSidedLength);
frequencyHz = (0:oneSidedLength - 1)' * sampleRate / fftLength;
levelDb = 20 * log10(abs(oneSidedFft) + eps);

[fundamentalLevelDb, fundamentalIndex] = max(levelDb);
lowIndex = max(2, fundamentalIndex - config.signalSpan);
highIndex = min(oneSidedLength - 1, fundamentalIndex + config.signalSpan);
[~, accurateIndex] = converter.adc.findAccuratePeak(levelDb, lowIndex, highIndex);
fundamentalFrequencyHz = (accurateIndex - 1) * sampleRate / fftLength;
fitSampleCount = requestedFitSampleCount( ...
    numel(adcCode), fundamentalFrequencyHz, config);
fit = converter.adc.fitSine(adcCode, fundamentalFrequencyHz, ...
    config.sampleRate, fitSampleCount);

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
noisePower = max(totalPower - dcPower - signalPower - harmonicPower, eps);
noiseBinCount = oneSidedLength - numel(dcIndices) - ...
    numel(signalIndices) - numel(harmonicIndices);
noisePower = noisePower * oneSidedLength / max(noiseBinCount, 1);
sinadPower = max(totalPower - dcPower - signalPower, eps);
signalAmplitudeDbfs = 20 * log10(max(fit.amplitudeCode, eps) / ...
    config.adcFullScalePeakCode);

metrics.fit = fit;
metrics.spectrum = struct( ...
    'frequencyHz', frequencyHz, 'levelDb', levelDb, ...
    'fundamentalFrequencyHz', fundamentalFrequencyHz, ...
    'fundamentalLevelDb', fundamentalLevelDb, ...
    'largestSpurFrequencyHz', frequencyHz(largestSpurIndex), ...
    'largestSpurLevelDb', largestSpurLevelDb, ...
    'fundamentalIndex', fundamentalIndex, ...
    'largestSpurIndex', largestSpurIndex, ...
    'signalIndices', signalIndices, 'dcIndices', dcIndices, ...
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
converter.runtime.validateConfig(config, {'knownFrequencyHz', ...
    'fitCycles', 'minimumFitSamples'});
fitSampleCount = requestedFitSampleCount( ...
    numel(adcCode), config.knownFrequencyHz, config);
metrics.fit = converter.adc.fitSine(adcCode, config.knownFrequencyHz, ...
    config.sampleRate, fitSampleCount);
metrics.spectrum = emptySpectrum();
metrics.dynamic = emptyDynamic();
end

function sampleCount = requestedFitSampleCount(totalSamples, frequencyHz, config)
samplesPerCycle = config.sampleRate / frequencyHz;
requestedSamples = round(samplesPerCycle * config.fitCycles);
sampleCount = min(totalSamples, max(config.minimumFitSamples, requestedSamples));
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
spectrum = struct('frequencyHz', [], 'levelDb', [], ...
    'fundamentalFrequencyHz', NaN, 'fundamentalLevelDb', NaN, ...
    'largestSpurFrequencyHz', NaN, 'largestSpurLevelDb', NaN, ...
    'fundamentalIndex', NaN, 'largestSpurIndex', NaN, ...
    'signalIndices', [], 'dcIndices', [], 'harmonicIndices', []);
end

function dynamic = emptyDynamic()
dynamic = struct('SFDR', NaN, 'SNR', NaN, 'SINAD', NaN, ...
    'THD', NaN, 'ENOB', NaN, 'signalAmplitudeDbfs', NaN);
end


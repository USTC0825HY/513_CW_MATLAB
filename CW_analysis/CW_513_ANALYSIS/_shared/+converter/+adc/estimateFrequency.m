function [frequencyHz, peakLevelDb] = estimateFrequency(adcCode, sampleRate)
%ESTIMATEFREQUENCY Estimate the strongest ADC-code tone with an FFT.

if ~isscalar(sampleRate) || ~isfinite(sampleRate) || sampleRate <= 0
    error('converter:adc:InvalidSampleRate', 'sampleRate 必须是正有限标量。');
end
if ~isnumeric(adcCode) || ~isvector(adcCode)
    error('converter:adc:InvalidAdcCode', 'adcCode 必须是数值向量。');
end
adcCode = double(adcCode(:));
adcCode = adcCode(isfinite(adcCode));
if numel(adcCode) < 16
    error('converter:adc:InsufficientSamples', 'FFT 频率估计至少需要 16 个有效样点。');
end

fftLength = min(128 * 1024, numel(adcCode));
signal = adcCode(1:fftLength) - mean(adcCode(1:fftLength));
sampleIndex = (0:fftLength - 1)';
window = 0.5 - 0.5 * cos(2 * pi * sampleIndex / fftLength);
fftData = fft(signal .* window);
oneSidedLength = floor(fftLength / 2) + 1;
levelDb = 20 * log10(abs(fftData(1:oneSidedLength)) + eps);
searchLevelDb = levelDb;
searchLevelDb(1) = -Inf;
if oneSidedLength > 2
    searchLevelDb(end) = -Inf;
end
[~, peakIndex] = max(searchLevelDb);
lowIndex = max(2, peakIndex - 3);
highIndex = min(oneSidedLength - 1, peakIndex + 3);
[peakLevelDb, accurateIndex] = converter.adc.findAccuratePeak( ...
    levelDb, lowIndex, highIndex);
frequencyHz = (accurateIndex - 1) * sampleRate / fftLength;
end


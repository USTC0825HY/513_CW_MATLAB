function [frequencyHz, peakLevelDb] = estimate_adc_frequency(adcCode, sampleRate)
%ESTIMATE_ADC_FREQUENCY Estimate the strongest ADC-code tone by FFT.
%   The filename is not used. The estimate is used as the sine-fit
%   frequency for bandwidth and input-power analysis.

if nargin < 2 || ~isscalar(sampleRate) || ~isfinite(sampleRate) || ...
        sampleRate <= 0
    error('sampleRate must be a positive finite scalar.');
end
if ~isnumeric(adcCode) || ~isvector(adcCode)
    error('adcCode must be a numeric vector.');
end

adcCode = double(adcCode(:));
adcCode = adcCode(isfinite(adcCode));
if numel(adcCode) < 16
    error('At least 16 finite ADC samples are required for FFT frequency estimation.');
end

fftLength = min(128 * 1024, numel(adcCode));
signal = adcCode(1:fftLength) - mean(adcCode(1:fftLength));
sampleIndex = (0:fftLength - 1)';
window = 0.5 - 0.5 * cos(2 * pi * sampleIndex / fftLength);
fftData = fft(signal .* window);
oneSidedLength = floor(fftLength / 2) + 1;
levelDb = 20 * log10(abs(fftData(1:oneSidedLength)) + eps);

% DC and Nyquist are not candidate input tones.
searchLevelDb = levelDb;
searchLevelDb(1) = -Inf;
if oneSidedLength > 2
    searchLevelDb(end) = -Inf;
end
[~, peakIndex] = max(searchLevelDb);
lowIndex = max(2, peakIndex - 3);
highIndex = min(oneSidedLength - 1, peakIndex + 3);
[peakLevelDb, accurateIndex] = find_accu_peak(levelDb, lowIndex, highIndex);
frequencyHz = (accurateIndex - 1) * sampleRate / fftLength;
end

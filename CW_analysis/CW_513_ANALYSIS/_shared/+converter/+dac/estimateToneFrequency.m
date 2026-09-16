function estimate = estimateToneFrequency(voltage, sampleRateHz, nominalFrequencyHz, searchFraction)
%ESTIMATETONEFREQUENCY Find the strongest tone and refine its frequency.
%   ESTIMATE = ESTIMATETONEFREQUENCY(VOLTAGE, SAMPLERATEHZ) searches the
%   positive-frequency spectrum. Supplying NOMINALFREQUENCYHZ restricts
%   the search to SEARCHFRACTION around the nominal value.

if nargin < 3, nominalFrequencyHz = []; end
if nargin < 4 || isempty(searchFraction), searchFraction = 0.01; end
validateattributes(sampleRateHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});
validateattributes(searchFraction, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive', '<', 0.5});

voltage = double(voltage(:));
voltage = voltage(isfinite(voltage));
if numel(voltage) < 16
    error('converter:dac:ToneLength', '有效波形点数不足，无法搜索驱动频率。');
end
voltage = voltage - mean(voltage);
sampleCount = numel(voltage);
window = hann(sampleCount, 'periodic');
nfft = 2 ^ nextpow2(4 * sampleCount);
oneSidedCount = floor(nfft / 2) + 1;
spectrum = abs(fft(voltage .* window, nfft));
spectrum = spectrum(1:oneSidedCount);
frequencyAxis = (0:oneSidedCount - 1).' * (sampleRateHz / nfft);
frequencyResolutionHz = sampleRateHz / nfft;

if isempty(nominalFrequencyHz) || ~isfinite(nominalFrequencyHz)
    searchLowerHz = frequencyResolutionHz;
    searchUpperHz = sampleRateHz / 2 - frequencyResolutionHz;
    nominalValue = NaN;
else
    validateattributes(nominalFrequencyHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<', sampleRateHz / 2});
    nominalValue = double(nominalFrequencyHz);
    searchHalfWidthHz = max(searchFraction * nominalValue, ...
        10 * sampleRateHz / sampleCount);
    searchLowerHz = max(frequencyResolutionHz, nominalValue - searchHalfWidthHz);
    searchUpperHz = min(sampleRateHz / 2 - frequencyResolutionHz, ...
        nominalValue + searchHalfWidthHz);
end

searchIndices = find(frequencyAxis >= searchLowerHz & ...
    frequencyAxis <= searchUpperHz);
if isempty(searchIndices)
    error('converter:dac:ToneSearchEmpty', '指定频率范围内没有可搜索频点。');
end
[~, localPeakIndex] = max(spectrum(searchIndices));
peakIndex = searchIndices(localPeakIndex);
lowerHz = frequencyAxis(max(peakIndex - 1, searchIndices(1)));
upperHz = frequencyAxis(min(peakIndex + 1, searchIndices(end)));
objective = @(candidateHz) localResidual(voltage, sampleRateHz, candidateHz);
if upperHz > lowerHz
    frequencyHz = fminbnd(objective, lowerHz, upperHz, ...
        optimset('Display', 'off', 'TolX', ...
        max(frequencyResolutionHz * 1e-6, 1e-6)));
else
    frequencyHz = frequencyAxis(peakIndex);
end
fit = converter.dac.fitTone(voltage, sampleRateHz, frequencyHz);

estimate = struct('frequencyHz', frequencyHz, ...
    'nominalFrequencyHz', nominalValue, ...
    'frequencyOffsetHz', frequencyHz - nominalValue, ...
    'frequencyResolutionHz', frequencyResolutionHz, ...
    'searchBandHz', [searchLowerHz, searchUpperHz], ...
    'sampleRateHz', sampleRateHz, 'sampleCount', sampleCount, ...
    'fit', fit);
end

function residualRmsV = localResidual(voltage, sampleRateHz, frequencyHz)
fit = converter.dac.fitTone(voltage, sampleRateHz, frequencyHz);
residualRmsV = fit.residualRmsV;
end

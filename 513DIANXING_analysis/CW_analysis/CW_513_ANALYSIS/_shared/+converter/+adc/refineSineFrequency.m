function frequencyHz = refineSineFrequency(adcCode, initialFrequencyHz, ...
        sampleRate, fitCycles, minimumFitSamples)
%REFINESINEFREQUENCY Refine an FFT tone estimate by minimizing sine-fit error.

adcCode = double(adcCode(:));
adcCode = adcCode(isfinite(adcCode));
if isempty(adcCode) || ~isfinite(initialFrequencyHz) || initialFrequencyHz <= 0
    error('converter:adc:InvalidFrequencyRefinementInput', ...
        '频率精细拟合需要有效样点和正的初始频率。');
end

fftLength = min(128 * 1024, numel(adcCode));
searchHalfWidthHz = 2 * sampleRate / fftLength;
lowerFrequencyHz = max(eps(sampleRate), ...
    initialFrequencyHz - searchHalfWidthHz);
upperFrequencyHz = min(sampleRate / 2 * (1 - eps), ...
    initialFrequencyHz + searchHalfWidthHz);

requestedSamples = round(sampleRate / initialFrequencyHz * fitCycles);
fitSampleCount = min(numel(adcCode), ...
    max(minimumFitSamples, requestedSamples));
fitCode = adcCode(1:fitSampleCount);
timeSeconds = (0:fitSampleCount - 1)' / sampleRate;
objective = @(candidateHz) sineResidualPower( ...
    candidateHz, timeSeconds, fitCode);
options = optimset('Display', 'off', 'TolX', ...
    max(initialFrequencyHz * 1e-10, sampleRate / numel(adcCode) * 1e-6));
frequencyHz = fminbnd(objective, lowerFrequencyHz, upperFrequencyHz, options);
end

function residualPower = sineResidualPower(frequencyHz, timeSeconds, fitCode)
designMatrix = [sin(2*pi*frequencyHz*timeSeconds), ...
    cos(2*pi*frequencyHz*timeSeconds), ones(numel(timeSeconds), 1)];
coefficient = designMatrix \ fitCode;
residualCode = fitCode - designMatrix * coefficient;
residualPower = mean(residualCode.^2);
end

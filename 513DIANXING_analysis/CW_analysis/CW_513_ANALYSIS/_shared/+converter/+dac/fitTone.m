function fit = fitTone(voltage, sampleRateHz, toneFrequencyHz)
%FITTONE Fit a fixed-frequency sine and return amplitude and quality metrics.
sampleCount = numel(voltage);
time = (0:sampleCount-1).' ./ sampleRateHz;
design = [ones(sampleCount, 1), cos(2*pi*toneFrequencyHz*time), ...
    sin(2*pi*toneFrequencyHz*time)];
coefficient = design \ voltage;
fitted = design * coefficient;
residual = voltage - fitted;
signalPeak = hypot(coefficient(2), coefficient(3));
totalVariation = voltage - mean(voltage);
ssTotal = sum(totalVariation.^2);
if ssTotal > 0
    rSquared = 1 - sum(residual.^2) / ssTotal;
else
    rSquared = NaN;
end
fit = struct('offsetV', coefficient(1), 'amplitudePeakV', signalPeak, ...
    'vppV', 2 * signalPeak, 'rSquared', rSquared, ...
    'residualRmsV', sqrt(mean(residual.^2)), ...
    'frequencyHz', toneFrequencyHz);
end

function fit = fitTone(voltage, sampleRateHz, toneFrequencyHz)
%FITTONE Fit a fixed-frequency sine and return amplitude and quality metrics.
validateattributes(sampleRateHz, {'numeric'}, {'real','scalar','finite','positive'});
if ~isscalar(toneFrequencyHz) || ~isfinite(toneFrequencyHz) || ...
        toneFrequencyHz <= 0 || toneFrequencyHz >= sampleRateHz / 2
    error('converter:dac:ToneOutsideNyquist', ...
        '正弦频率必须满足0<f<Nyquist：f=%.12g Hz，fs=%.12g Hz。', toneFrequencyHz, sampleRateHz);
end
validateattributes(voltage, {'numeric'}, {'real','vector','finite','nonempty'});
voltage = voltage(:);
sampleCount = numel(voltage);
if sampleCount < 4
    error('converter:dac:ToneTooShort', '正弦拟合至少需要4个样点。');
end
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

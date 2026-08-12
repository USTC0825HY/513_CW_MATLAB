function fit = fit_tone(timeS, values, frequencyHz)
%FIT_TONE Fit offset plus sine and cosine at one fixed frequency.
%   FIT = laser_analysis.fit_tone(TIME, VALUES, FREQUENCY) returns
%   amplitude, peak-to-peak amplitude, phase, offset, R-squared, residual,
%   fitted values, and the complex phasor A*cos(wt)+B*sin(wt).

arguments
    timeS (:, 1) double
    values (:, 1) double
    frequencyHz (1, 1) double {mustBeFinite, mustBePositive}
end
if numel(timeS) ~= numel(values) || numel(values) < 4
    error('laser_analysis:ToneFitInput', ...
        'TIME and VALUES must have equal length of at least four.');
end

omegaT = 2 * pi * frequencyHz .* timeS;
design = [cos(omegaT), sin(omegaT), ones(size(timeS))];
coefficient = design \ values;
fitted = design * coefficient;
residual = values - fitted;
amplitude = hypot(coefficient(1), coefficient(2));
phase = atan2(-coefficient(2), coefficient(1));
sse = sum(residual .^ 2);
sst = sum((values - mean(values)) .^ 2);
if sst > 0
    rSquared = 1 - sse / sst;
else
    rSquared = NaN;
end

fit = struct;
fit.frequency_hz = frequencyHz;
fit.amplitude = amplitude;
fit.vpp = 2 * amplitude;
fit.phase_rad = phase;
fit.phase_deg = rad2deg(phase);
fit.offset = coefficient(3);
fit.r_squared = rSquared;
fit.residual_rms = sqrt(mean(residual .^ 2));
fit.phasor = coefficient(1) - 1i * coefficient(2);
fit.fitted = fitted;
fit.residual = residual;
end

function metrics = spectrum_metrics(values, fsHz, expectedToneHz, guardBins)
%SPECTRUM_METRICS Compute auditable one-sided SFDR spectrum metrics.
%   METRICS = laser_analysis.spectrum_metrics(X, FS, TONE, GUARDBINS)
%   removes the mean, applies a periodic Hann window, and integrates power
%   over +/- GUARDBINS around the fundamental and each spur candidate.
%   Harmonics remain eligible spurs. SFDR is 10*log10(Pfund/PmaxSpur).

arguments
    values (:, 1) double
    fsHz (1, 1) double {mustBeFinite, mustBePositive}
    expectedToneHz (1, 1) double = NaN
    guardBins (1, 1) double {mustBeInteger, mustBeNonnegative} = 3
end
if numel(values) < 16
    error('laser_analysis:SpectrumInput', ...
        'At least 16 samples are required.');
end

x = values - mean(values);
n = numel(x);
window = hann(n, 'periodic');
[psd, frequencyHz] = periodogram(x, window, n, fsHz, 'onesided');
dfHz = frequencyHz(2) - frequencyHz(1);
integratedPower = movsum(psd, 2 * guardBins + 1) * dfHz;

if isfinite(expectedToneHz)
    if expectedToneHz <= 0 || expectedToneHz >= fsHz / 2
        error('laser_analysis:SpectrumTone', ...
            'Expected tone must lie between DC and Nyquist.');
    end
    [~, fundamentalIndex] = min(abs(frequencyHz - expectedToneHz));
else
    [~, relativeIndex] = max(integratedPower(2:end));
    fundamentalIndex = relativeIndex + 1;
end

exclude = false(size(frequencyHz));
exclude(1:min(numel(exclude), guardBins + 2)) = true;
lower = max(1, fundamentalIndex - 2 * guardBins - 1);
upper = min(numel(exclude), fundamentalIndex + 2 * guardBins + 1);
exclude(lower:upper) = true;
spurPower = integratedPower;
spurPower(exclude) = -Inf;
[maximumSpurPower, spurIndex] = max(spurPower);
fundamentalPower = integratedPower(fundamentalIndex);

if fundamentalPower > 0 && isfinite(maximumSpurPower) && maximumSpurPower > 0
    sfdrDb = 10 * log10(fundamentalPower / maximumSpurPower);
else
    sfdrDb = NaN;
end

metrics = struct;
metrics.frequency_hz = frequencyHz;
metrics.psd_per_hz = psd;
metrics.integrated_bin_power = integratedPower;
metrics.df_hz = dfHz;
metrics.fundamental_frequency_hz = frequencyHz(fundamentalIndex);
metrics.fundamental_power = fundamentalPower;
metrics.maximum_spur_frequency_hz = frequencyHz(spurIndex);
metrics.maximum_spur_power = maximumSpurPower;
metrics.sfdr_db = sfdrDb;
metrics.guard_bins = guardBins;
end

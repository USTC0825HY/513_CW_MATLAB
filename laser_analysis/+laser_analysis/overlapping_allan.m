function result = overlapping_allan( ...
    frequencyHz, tau0S, centerFrequencyHz, targetTauS)
%OVERLAPPING_ALLAN Compute overlapping ADEV and MDEV from frequency data.
%   RESULT = laser_analysis.overlapping_allan(F, TAU0, F0, TAU)
%   converts absolute frequency samples to fractional frequency and
%   evaluates each requested averaging time. TAU must be integer multiples
%   of TAU0. Unsupported long tau values remain NaN instead of being
%   extrapolated.
%
%   ADEV uses differences of adjacent m-sample averages. MDEV is evaluated
%   from the equivalent fractional-time sequence with the standard
%   overlapping second-difference sum.

arguments
    frequencyHz (:, 1) double
    tau0S (1, 1) double {mustBeFinite, mustBePositive}
    centerFrequencyHz (1, 1) double {mustBeFinite, mustBePositive}
    targetTauS (:, 1) double {mustBeFinite, mustBePositive}
end

frequencyHz = frequencyHz(isfinite(frequencyHz));
n = numel(frequencyHz);
y = (frequencyHz - centerFrequencyHz) / centerFrequencyHz;
x = [0; cumsum(y) * tau0S];

tauS = targetTauS(:);
mValue = round(tauS / tau0S);
adev = nan(size(tauS));
mdev = nan(size(tauS));
samplePairs = zeros(size(tauS));
status = repmat("暂不能判定", size(tauS));

for k = 1:numel(tauS)
    m = mValue(k);
    if m < 1 || abs(tauS(k) - m * tau0S) > 1e-9 * tauS(k)
        continue;
    end
    if n >= 2 * m
        cumulative = [0; cumsum(y)];
        firstAverage = (cumulative(1 + m:n - m + 1) - ...
            cumulative(1:n - 2 * m + 1)) / m;
        secondAverage = (cumulative(1 + 2 * m:n + 1) - ...
            cumulative(1 + m:n - m + 1)) / m;
        delta = secondAverage - firstAverage;
        adev(k) = sqrt(0.5 * mean(delta .^ 2));
        samplePairs(k) = numel(delta);
    end
    if n >= 3 * m
        secondDifference = x(1 + 2 * m:end) - ...
            2 * x(1 + m:end - m) + x(1:end - 2 * m);
        summedDifference = movsum(secondDifference, [m - 1, 0]);
        summedDifference = summedDifference(m:end);
        denominator = 2 * m ^ 2 * (m * tau0S) ^ 2;
        mdev(k) = sqrt(mean(summedDifference .^ 2) / denominator);
    end
    if isfinite(adev(k)) && isfinite(mdev(k))
        status(k) = "已计算";
    end
end

result = table(tauS, mValue, adev, mdev, samplePairs, status, ...
    'VariableNames', {'tau_s', 'm', 'adev', 'mdev', ...
    'sample_pairs', 'calculation_status'});
end

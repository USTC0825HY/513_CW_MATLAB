function bandwidthHz = findThreeDbCrossing(frequencyHz, relativeDb)
%FINDTHREEDBCROSSING Interpolate the first -3 dB crossing in log frequency.

crossingIndex = find(relativeDb(1:end-1) >= -3 & ...
    relativeDb(2:end) <= -3, 1, 'first');
if isempty(crossingIndex)
    bandwidthHz = NaN;
    warning('converter:adc:NoThreeDbCrossing', '测试范围内未找到 -3 dB 交点。');
    return;
end
f1 = frequencyHz(crossingIndex);
f2 = frequencyHz(crossingIndex + 1);
db1 = relativeDb(crossingIndex);
db2 = relativeDb(crossingIndex + 1);
logF1 = log10(f1);
logF2 = log10(f2);
bandwidthHz = 10^(logF1 + (-3 - db1) * ...
    (logF2 - logF1) / (db2 - db1));
end


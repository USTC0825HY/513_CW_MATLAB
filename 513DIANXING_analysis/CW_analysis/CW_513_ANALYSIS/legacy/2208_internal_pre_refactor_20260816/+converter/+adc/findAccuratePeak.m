function [peak, peakIndex] = findAccuratePeak(data, lowIndex, highIndex)
%FINDACCURATEPEAK Refine a spectral peak with spline interpolation.

lowIndex = max(round(lowIndex), 2);
highIndex = min(round(highIndex), numel(data) - 1);
if highIndex < lowIndex
    error('converter:adc:InvalidPeakRange', '频谱峰值插值范围无效。');
end
x = lowIndex:highIndex;
y = data(lowIndex:highIndex);
interpolationCount = 100;
xQuery = lowIndex:1/interpolationCount:highIndex;
yQuery = interp1(x, y, xQuery, 'spline');
[peak, queryIndex] = max(yQuery);
peakIndex = (queryIndex - 1) / interpolationCount + lowIndex;
end


function [ peak, peakIndex ] = find_accu_peak( data, lowIndex, highIndex )

lowIndex = max(round(lowIndex),2);
highIndex = min(round(highIndex),length(data)-1);

x = lowIndex:highIndex;
y = data(lowIndex:highIndex);

nint = 100; % interp number
xq = lowIndex:1/nint:highIndex;
yq = interp1(x, y, xq, 'spline');

[peak, peakIndex] = max(yq);
peakIndex = (peakIndex-1)/nint+lowIndex;

end


function [inputPowerDbm, codeRmsDbfs] = codePpToInputPowerDbm( ...
        codePp, calibrationSlopeDbfsPerDbm, calibrationInterceptDbfs, ...
        adcFullScalePeakCode)
%CODEPPTOINPUTPOWERDBM Convert a historical dBFS/dBm calibration to dBm.
%   This compatibility helper is not the formal AD calibration path. New AD
%   calibration must use converter.adc.calculatePowerScale with CodePp -> Vpp
%   and an explicit dBm-to-Vpp conversion at the reference impedance.
%   [POWERDBM, CODERMSDBFS] = CODEPPTOINPUTPOWERDBM(CODEPP, SLOPE, ...
%       INTERCEPT, FULLSCALEPEAKCODE) applies a run-specific ADC power
%   calibration. CODEPP is the fitted sinusoidal peak-to-peak code value
%   in LSBpp. SLOPE and INTERCEPT describe:
%
%       CodeRmsDbfs = SLOPE * InputPowerDbm + INTERCEPT
%
%   where CodeRmsDbfs = 20*log10(CodePp/(2*sqrt(2)*FULLSCALEPEAKCODE)).
%   The inverse is valid only inside the measured calibration range and at
%   the channel, frequency, reference plane, and code format of that run.

if nargin ~= 4
    error('converter:adc:InvalidPowerScaleInput', ...
        'CodePp 到 dBm 换算需要 CodePp、斜率、截距和满量程码值。');
end
if ~isscalar(calibrationSlopeDbfsPerDbm) || ...
        ~isfinite(calibrationSlopeDbfsPerDbm) || ...
        calibrationSlopeDbfsPerDbm == 0
    error('converter:adc:InvalidPowerScaleSlope', ...
        '功率标定斜率必须为有限非零标量。');
end
if ~isscalar(calibrationInterceptDbfs) || ...
        ~isfinite(calibrationInterceptDbfs)
    error('converter:adc:InvalidPowerScaleIntercept', ...
        '功率标定截距必须为有限标量。');
end
if ~isscalar(adcFullScalePeakCode) || ...
        ~isfinite(adcFullScalePeakCode) || adcFullScalePeakCode <= 0
    error('converter:adc:InvalidFullScaleCode', ...
        'ADC 满量程峰值码必须为正的有限标量。');
end

codePp = double(codePp);
codeRmsDbfs = NaN(size(codePp));
inputPowerDbm = NaN(size(codePp));
validCode = isfinite(codePp) & codePp > 0;
if ~any(validCode(:))
    return;
end

codeRms = codePp(validCode) / (2 * sqrt(2));
codeRmsDbfs(validCode) = 20 * log10(codeRms / adcFullScalePeakCode);
inputPowerDbm(validCode) = (codeRmsDbfs(validCode) - ...
    calibrationInterceptDbfs) / calibrationSlopeDbfsPerDbm;
end

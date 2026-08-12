% s01_generate_virtual_ltc2208_test_csv
% Generate one virtual LTC2208-style ILA CSV for sine calibration testing.
%
% Output data column is signed decimal code, so it matches:
%   dataRadix = 'decimal'
%   outputCoding = 'twos_complement'
%
% The default case is 10 MHz, 6 dBm into 50 ohm, with front-end gain 1.8.
% This is intentionally near/slightly above the LTC2208 PGA=0 full scale.

clear;
clc;
rng(20260703);

%% ======================== User parameters ========================

outDir = fullfile(fileparts(mfilename('fullpath')), 'generated');
outCsvName = 'ltc2208_virtual_10M_6dBm_signed_decimal.csv';
outResultName = 'ltc2208_virtual_10M_6dBm_expected_result.csv';
outPlotName = 'ltc2208_virtual_10M_6dBm_preview.png';

fs = 100e6;
toneFreqHz = 10e6;
sampleCount = 100000;
sinePhaseRad = pi / 2;       % Make samples hit positive/negative peaks at 10 samples/period.

inputLevel_dBm = 6;
sourceOhm = 50;
frontEndGain = 1.8;

adcBits = 16;
inputRangeVpp = 2.25;       % LTC2208 PGA=0 differential full-scale span.
noiseCodeRms = 30;          % Random code disturbance RMS.
dcOffsetCode = 0;

%% ======================== Generate virtual signed codes ========================

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

powerW = 10^((inputLevel_dBm - 30) / 10);
inputVrms = sqrt(powerW * sourceOhm);
inputVpp = 2 * sqrt(2) * inputVrms;

adcVppIdeal = inputVpp * frontEndGain;
adcAmpIdeal = adcVppIdeal / 2;
adcHalfScale = inputRangeVpp / 2;
lsbV = inputRangeVpp / 2^adcBits;

n = (0:sampleCount-1).';
t = n / fs;
adcVoltageIdeal = adcAmpIdeal * sin(2 * pi * toneFreqHz * t + sinePhaseRad);
idealCode = adcVoltageIdeal / lsbV + dcOffsetCode;
noiseCode = noiseCodeRms * randn(sampleCount, 1);
signedCode = round(idealCode + noiseCode);

minSigned = -2^(adcBits - 1);
maxSigned = 2^(adcBits - 1) - 1;
signedCodeClipped = min(max(signedCode, minSigned), maxSigned);
clippedMask = signedCode ~= signedCodeClipped;
signedCode = signedCodeClipped;

adcVoltageQuantized = signedCode * lsbV;

csvCell = cell(sampleCount + 1, 4);
csvCell(1, :) = {'Sample in Window', 'Sample in Buffer', 'TRIGGER', ...
    'cwjg_top_inst/PDH_ctr/ad2208_data16b_pdh_w[15:0]'};
csvCell(2:end, 1) = num2cell(n);
csvCell(2:end, 2) = num2cell(n);
csvCell(2:end, 3) = num2cell(zeros(sampleCount, 1));
csvCell(2:end, 4) = num2cell(signedCode);

outCsvPath = fullfile(outDir, outCsvName);
writecell(csvCell, outCsvPath);

%% ======================== Fit generated data for preview ========================

fit = fitSineAtFixedFrequency(t, adcVoltageQuantized, toneFreqHz);
codeFit = fitSineAtFixedFrequency(t, signedCode, toneFreqHz);

result = table({outCsvName}, fs, toneFreqHz, sinePhaseRad, sampleCount, inputLevel_dBm, ...
    inputVpp, frontEndGain, adcVppIdeal, inputRangeVpp, adcHalfScale, ...
    lsbV, noiseCodeRms, mean(clippedMask) * 100, ...
    codeFit.vpp, fit.vpp, fit.residualRms, fit.r2, ...
    'VariableNames', {'csv_file', 'fs_hz', 'tone_freq_hz', 'sine_phase_rad', 'sample_count', ...
    'input_level_dBm', 'input_vpp_v', 'front_end_gain', 'ideal_adc_vpp_v', ...
    'adc_input_range_vpp', 'adc_half_scale_v', 'lsb_v_per_code', ...
    'noise_code_rms', 'clipped_percent', 'fit_vpp_code', ...
    'fit_vpp_adc_v', 'residual_rms_v', 'r2'});

outResultPath = fullfile(outDir, outResultName);
writetable(result, outResultPath, 'Encoding', 'UTF-8');

figure('Name', 'Virtual LTC2208 10M 6dBm preview', 'Visible', 'off');
plot(t(1:300), adcVoltageQuantized(1:300), '.', 'MarkerSize', 6);
hold on;
plot(t(1:300), fit.yFit(1:300), 'r-', 'LineWidth', 1.2);
grid on;
xlabel('Time (s)');
ylabel('ADC input equivalent voltage (V)');
title(sprintf('10 MHz 6 dBm virtual LTC2208, clipped %.3f%%, R^2 %.5f', ...
    mean(clippedMask) * 100, fit.r2));
legend({'quantized noisy code', 'sine fit'}, 'Location', 'best');
outPlotPath = fullfile(outDir, outPlotName);
saveas(gcf, outPlotPath);
close(gcf);

fprintf('Virtual CSV generated:\n%s\n', outCsvPath);
fprintf('Expected result:\n%s\n', outResultPath);
fprintf('Preview plot:\n%s\n\n', outPlotPath);
disp(result);

%% ======================== Local helper ========================

function fit = fitSineAtFixedFrequency(t, y, freqHz)
y = y(:);
w = 2 * pi * freqHz;
X = [sin(w * t(:)), cos(w * t(:)), ones(numel(t), 1)];
coef = X \ y;

fit.freqHz = freqHz;
fit.sinCoef = coef(1);
fit.cosCoef = coef(2);
fit.offset = coef(3);
fit.amplitude = hypot(coef(1), coef(2));
fit.vpp = 2 * fit.amplitude;
fit.phaseRad = atan2(coef(2), coef(1));
fit.yFit = X * coef;

residual = y - fit.yFit;
fit.residualRms = sqrt(mean(residual.^2));
sse = sum(residual.^2);
sst = sum((y - mean(y)).^2);
if sst > 0
    fit.r2 = 1 - sse / sst;
else
    fit.r2 = NaN;
end
end

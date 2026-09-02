function results = adc_input_noise_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_INPUT_NOISE_ANALYSIS Analyze direct AD2208 ILA input-equivalent noise.
%   This is the current 513 library entry for the direct grounded-ADC ILA
%   path. The legacy s10 workflow is retained only as a compatibility
%   reference; numerical processing is implemented by converter.adc.runInputNoise.

bootstrapRuntime();
if nargin < 1 || isempty(dataFolder)
    dataFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
        'CW_Data', '513_CW_DATA', 'AD2208', '06_Noise', '01_HighFrequency_ILA');
end
if nargin < 2 || isempty(selectedFiles)
    selectedFiles = {fullfile(dataFolder, 'JG15.csv'), ...
        fullfile(dataFolder, 'JG17_NOISE.ila.csv'), ...
        fullfile(dataFolder, 'JG22.ila.csv')};
end
if nargin < 3 || isempty(outputFolder)
    outputFolder = fullfile(fileparts(fileparts(dataFolder)), 'results');
end

config = ad2208Config('input_noise');
calibration = localCalibrationRows();
results = converter.adc.runInputNoise(config, dataFolder, selectedFiles, ...
    outputFolder, calibration);
end

function calibration = localCalibrationRows()
% The report-approved 1 MHz rows are intentionally explicit. JG17/JG22
% also have 15 MHz rows in the workbook; those are recorded as alternatives
% in the evidence notes but are not silently substituted here.
calibration = struct();
calibration(1).channel = 'ADC1_JG15';
calibration(1).slopeVPerCode = 2.34852372320206e-05;
calibration(1).interceptV = 7.77305829419062e-04;
calibration(1).fitR2 = 0.999993770969417;
calibration(1).calibrationFrequencyHz = 1e6;
calibration(2).channel = 'ADC2_JG17';
calibration(2).slopeVPerCode = 4.43108812426092e-05;
calibration(2).interceptV = 7.10079007621424e-04;
calibration(2).fitR2 = 0.999993018442261;
calibration(2).calibrationFrequencyHz = 1e6;
calibration(3).channel = 'ADC5_JG22';
calibration(3).slopeVPerCode = 2.37640311177720e-05;
calibration(3).interceptV = 7.05278915906142e-04;
calibration(3).fitR2 = 0.999993734053730;
calibration(3).calibrationFrequencyHz = 1e6;
end

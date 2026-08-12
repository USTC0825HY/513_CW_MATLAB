function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_POWER_SCALE_ANALYSIS Run the fixed AD9245 power-scale analysis.
%   RESULTS = ADC_POWER_SCALE_ANALYSIS() prompts for a data directory and
%   CSV files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runPowerScale(ad9245Config('power_scale'), ...
    dataFolder, selectedFiles, outputFolder);
end

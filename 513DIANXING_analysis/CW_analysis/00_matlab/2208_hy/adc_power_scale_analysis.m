function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_POWER_SCALE_ANALYSIS Run the fixed AD2208 input-power analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runPowerScale(ad2208Config('power_scale'), ...
    dataFolder, selectedFiles, outputFolder);
end

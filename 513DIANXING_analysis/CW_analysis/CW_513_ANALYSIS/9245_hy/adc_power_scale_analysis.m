function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_POWER_SCALE_ANALYSIS Run the fixed AD9245 CodePp-to-Vpp analysis.
%   RESULTS = ADC_POWER_SCALE_ANALYSIS() prompts for a data directory and
%   CSV files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, runOptions] = converter.runtime.applyRunOptions( ...
    ad9245Config('power_scale'), runOptions);
results = converter.adc.runPowerScale(config, dataFolder, selectedFiles, ...
    outputFolder, runOptions);
end

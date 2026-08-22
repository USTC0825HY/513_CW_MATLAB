function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_POWER_SCALE_ANALYSIS Build the AD2208 CodePp-to-Vpp scale.
%   Filename dBm labels are converted to Vpp at the configured reference
%   impedance; the result bundle exports the CodePp-to-Vpp fit and inverse
%   Vpp-to-CodePp rule.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, runOptions] = converter.runtime.applyRunOptions( ...
    ad2208Config('power_scale'), runOptions);
results = converter.adc.runPowerScale(config, dataFolder, selectedFiles, ...
    outputFolder, runOptions);
end

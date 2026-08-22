function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_BANDWIDTH_ANALYSIS Run the fixed AD2208 bandwidth analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, ~] = converter.runtime.applyRunOptions( ...
    ad2208Config('bandwidth'), runOptions);
results = converter.adc.runBandwidth(config, ...
    dataFolder, selectedFiles, outputFolder);
end

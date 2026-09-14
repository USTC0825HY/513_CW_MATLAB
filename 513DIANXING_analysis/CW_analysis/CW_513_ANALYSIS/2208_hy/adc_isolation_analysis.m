function results = adc_isolation_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%ADC_ISOLATION_ANALYSIS Run the fixed AD2208 isolation analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
config = ad2208Config('isolation');
if nargin >= 4 && ~isempty(configOverride)
    config = converter.runtime.mergeConfig(config, configOverride);
end
results = converter.adc.runIsolation(config, ...
    dataFolder, selectedFiles, outputFolder);
end

function results = adc_sfdr_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_SFDR_ANALYSIS Run the fixed AD2208 SFDR analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = struct(); end
[config, ~] = converter.runtime.applyRunOptions(ad2208Config('sfdr'), runOptions);
config.allowRadixPrompt = isempty(selectedFiles);
[config, selectedFiles, dataFolder, radixCancelled] = converter.io.prepareAdcRadix( ...
    config, dataFolder, selectedFiles);
if radixCancelled, results = []; return; end
results = converter.adc.runSfdr(config, ...
    dataFolder, selectedFiles, outputFolder);
end

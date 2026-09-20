function results = adc_sfdr_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_SFDR_ANALYSIS Run the fixed AD9245 SFDR analysis.
%   RESULTS = ADC_SFDR_ANALYSIS() prompts for a data directory and CSV
%   files, then writes a new timestamped result directory. Legacy 25 MHz
%   ILA records keep one row out of every five and are analyzed at 5 MHz.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = struct(); end
[config, ~] = converter.runtime.applyRunOptions( ...
    ad9245Config('sfdr'), runOptions);
config.allowRadixPrompt = isempty(selectedFiles);
[config, selectedFiles, dataFolder, radixCancelled] = converter.io.prepareAdcRadix( ...
    config, dataFolder, selectedFiles);
if radixCancelled, results = []; return; end
results = converter.adc.runSfdr(config, ...
    dataFolder, selectedFiles, outputFolder);
end

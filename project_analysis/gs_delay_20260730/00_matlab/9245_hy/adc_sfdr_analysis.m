function results = adc_sfdr_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_SFDR_ANALYSIS Run the fixed AD9245 SFDR analysis.
%   RESULTS = ADC_SFDR_ANALYSIS() prompts for a data directory and CSV
%   files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runSfdr(ad9245Config('sfdr'), ...
    dataFolder, selectedFiles, outputFolder);
end

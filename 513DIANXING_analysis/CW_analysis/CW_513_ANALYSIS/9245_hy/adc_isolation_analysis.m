function results = adc_isolation_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_ISOLATION_ANALYSIS Run the fixed AD9245 isolation analysis.
%   RESULTS = ADC_ISOLATION_ANALYSIS() prompts for a data directory and CSV
%   files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runIsolation(ad9245Config('isolation'), ...
    dataFolder, selectedFiles, outputFolder);
end

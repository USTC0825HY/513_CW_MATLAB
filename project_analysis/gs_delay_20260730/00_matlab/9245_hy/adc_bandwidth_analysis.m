function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_BANDWIDTH_ANALYSIS Run the fixed AD9245 bandwidth analysis.
%   RESULTS = ADC_BANDWIDTH_ANALYSIS() prompts for a data directory and CSV
%   files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runBandwidth(ad9245Config('bandwidth'), ...
    dataFolder, selectedFiles, outputFolder);
end

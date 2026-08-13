function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_BANDWIDTH_ANALYSIS Run the fixed AD2208 bandwidth analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runBandwidth(ad2208Config('bandwidth'), ...
    dataFolder, selectedFiles, outputFolder);
end

function results = adc_isolation_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_ISOLATION_ANALYSIS Run the fixed AD2208 isolation analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runIsolation(ad2208Config('isolation'), ...
    dataFolder, selectedFiles, outputFolder);
end

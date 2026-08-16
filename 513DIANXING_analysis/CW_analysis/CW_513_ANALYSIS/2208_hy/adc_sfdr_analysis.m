function results = adc_sfdr_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_SFDR_ANALYSIS Run the fixed AD2208 SFDR analysis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runSfdr(ad2208Config('sfdr'), ...
    dataFolder, selectedFiles, outputFolder);
end

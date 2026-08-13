function results = adc_inl_dnl_analysis(dataFolder, selectedFiles, outputFolder)
%ADC_INL_DNL_ANALYSIS Run the fixed AD9245 INL/DNL analysis.
%   RESULTS = ADC_INL_DNL_ANALYSIS() prompts for a data directory and CSV
%   files, then writes a new timestamped result directory.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
results = converter.adc.runInlDnl(ad9245Config('inl_dnl'), ...
    dataFolder, selectedFiles, outputFolder);
end

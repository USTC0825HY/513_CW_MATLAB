function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_BANDWIDTH_ANALYSIS Analyze AD677 input-frequency response.
%   RESULTS = ADC_BANDWIDTH_ANALYSIS(DATAFOLDER, FILES, OUTPUTFOLDER)
%   reuses the shared converter.adc bandwidth workflow. With DATAFOLDER
%   supplied and FILES omitted, every CSV directly in DATAFOLDER is used.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[dataFolder, selectedFiles, outputFolder] = ad677ResolveInputs( ...
    dataFolder, selectedFiles, outputFolder);
if isempty(selectedFiles)
    fprintf('未选择文件，AD677 带宽分析已取消。\n');
    results = table;
    return;
end
[config, ~] = converter.runtime.applyRunOptions( ...
    ad677Config('bandwidth'), runOptions);
results = converter.adc.runBandwidth(config, dataFolder, ...
    selectedFiles, outputFolder);
end

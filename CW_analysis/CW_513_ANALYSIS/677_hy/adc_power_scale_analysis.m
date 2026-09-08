function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_POWER_SCALE_ANALYSIS Build the AD677 CodePp-to-Vpp calibration.
%   The formal fit is Vpp = a*CodePp + b. Vpp comes from the acquisition
%   manifest or filename label; dBm is not a fit axis.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4 || isempty(runOptions), runOptions = struct(); end
[dataFolder, selectedFiles, outputFolder] = ad677ResolveInputs( ...
    dataFolder, selectedFiles, outputFolder);
if isempty(selectedFiles)
    fprintf('未选择文件，AD677 刻度分析已取消。\n');
    results = table;
    return;
end
if ~isfield(runOptions, 'powerSetpoints') || ...
        isempty(runOptions.powerSetpoints)
    runOptions.powerSetpoints = ad677PowerSetpoints( ...
        dataFolder, selectedFiles);
end
[config, runOptions] = converter.runtime.applyRunOptions( ...
    ad677Config('power_scale'), runOptions);
results = converter.adc.runPowerScale(config, dataFolder, ...
    selectedFiles, outputFolder, runOptions);
end

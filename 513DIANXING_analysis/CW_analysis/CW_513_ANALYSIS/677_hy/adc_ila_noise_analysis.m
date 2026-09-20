function results = adc_ila_noise_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_ILA_NOISE_ANALYSIS Analyze AD677 noise from 100 MHz ILA CSV captures.
%   All captured rows are analyzed, including held ADC codes between
%   adc_data_vld pulses. The valid column is reported only as acquisition
%   evidence and does not select samples.

bootstrapRuntime();
if nargin < 4, runOptions = struct(); end
if nargin < 1 || isempty(dataFolder)
    dataFolder = fullfile('F:', filesep, '01_Laser', ...
        '0_20260727_513test', 'CW_Data', '513_CW_DATA', ...
        'AD677', '01_noise');
end
if nargin < 2, selectedFiles = []; end
interactive = isempty(selectedFiles);
if interactive
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles(dataFolder, [], ...
        '选择本次 AD677 ILA 噪声 CSV（可多选）');
    if isempty(selectedFiles)
        fprintf('未选择文件，AD677 ILA 噪声分析已取消。\n');
        results = struct([]);
        return;
    end
end
[selectedFiles, dataFolder] = converter.io.selectCsvFiles(dataFolder, selectedFiles);
selectedFiles = cellfun(@(f) converter.io.resolveInputPath(dataFolder, f), ...
    selectedFiles, 'UniformOutput', false);
if nargin < 3 || isempty(outputFolder)
    outputFolder = converter.io.resolveOutputBase(dataFolder, []);
end

[config, ~] = converter.runtime.applyRunOptions(ad677Config('input_noise'), runOptions);
config.allowRadixPrompt = interactive;
channels = converter.io.resolveAdcChannels(config, dataFolder, selectedFiles, interactive);
if isempty(channels), results = struct([]); return; end
config.inputChannels = cellstr(channels);
[config, selectedFiles, dataFolder, radixCancelled] = converter.io.prepareAdcRadix( ...
    config, dataFolder, selectedFiles);
if radixCancelled, results = []; return; end
results = converter.adc.runInputNoise(config, dataFolder, selectedFiles, ...
    outputFolder, config.noiseCalibration);
end

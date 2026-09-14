function results = adc_ila_noise_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_ILA_NOISE_ANALYSIS Analyze direct AD2208 ILA input-equivalent noise.
%   This is the current 513 library entry for the direct grounded-ADC ILA
%   path. The legacy s10 workflow is retained only as a compatibility
%   reference; numerical processing is implemented by converter.adc.runInputNoise.

bootstrapRuntime();
if nargin < 4, runOptions = struct(); end
if nargin < 1 || isempty(dataFolder)
    dataFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
        'CW_Data', '513_CW_DATA', 'AD2208', '06_Noise', '01_HighFrequency_ILA');
end
if nargin < 2, selectedFiles = []; end
interactive = isempty(selectedFiles);
if interactive
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles(dataFolder, [], ...
        '选择本次 AD2208 ILA 噪声 CSV（可多选）');
    if isempty(selectedFiles)
        fprintf('未选择文件，AD2208 ILA 噪声分析已取消。\n');
        results = struct([]);
        return;
    end
end
[selectedFiles, dataFolder] = converter.io.selectCsvFiles(dataFolder, selectedFiles);
selectedFiles = cellfun(@(f) converter.io.resolveInputPath(dataFolder,f), selectedFiles, 'UniformOutput',false);
if nargin < 3 || isempty(outputFolder)
    outputFolder = converter.io.resolveOutputBase(dataFolder, []);
end

[config, ~] = converter.runtime.applyRunOptions(ad2208Config('input_noise'), runOptions);
channels = converter.io.resolveAdcChannels(config, dataFolder, selectedFiles, interactive);
if isempty(channels), results = struct([]); return; end
config.inputChannels = cellstr(channels);
calibration = config.reportCalibration;
results = converter.adc.runInputNoise(config, dataFolder, selectedFiles, ...
    outputFolder, calibration);
end

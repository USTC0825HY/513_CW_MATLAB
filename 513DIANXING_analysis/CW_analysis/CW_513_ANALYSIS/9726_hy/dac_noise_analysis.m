function result = dac_noise_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_NOISE_ANALYSIS Select DA9726 MAT captures and run the existing noise core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
defaultFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'DA9726', '03_Noise');
[config, cancelled] = converter.io.prepareDacInputs( ...
    da9726Config('noise'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runNoise(config);
end

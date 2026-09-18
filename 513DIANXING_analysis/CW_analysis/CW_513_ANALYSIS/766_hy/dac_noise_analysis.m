function result = dac_noise_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_NOISE_ANALYSIS Select DA766 MAT captures and run the existing noise core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
defaultFolder = fullfile('I:', filesep, '513_CW_test', 'CW_Data', ...
    '513_CW_DATA_jianding', 'DA766', '03_DCNoise');
[config, cancelled] = converter.io.prepareDacInputs( ...
    da766Config('noise'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runNoise(config);
end

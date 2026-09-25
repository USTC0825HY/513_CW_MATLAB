function result = dac_noise_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_NOISE_ANALYSIS Select DA9726 MAT captures and run the existing noise core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
%   Noise analysis uses the voltage and MAT time base only; it does not read
%   the DAC scale files.  For a capture stored outside the default roots use,
%   for example:
%       d = 'G:/513_CW_test/CW_Data/513_CW_DATA/DA9726/03_Noise/nosie_20260901';
%       r = dac_noise_analysis(d, {'JG18.mat'}, fullfile(d, 'results'));
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
[dataFolder, selectedFiles] = normalizeDa9726Input(dataFolder, selectedFiles);
% An explicit folder must not probe obsolete/removable default drives.
defaultFolder = '';
if isempty(dataFolder) && ...
        (~isfield(configOverride, 'dataFolder') || isempty(configOverride.dataFolder))
    defaultFolder = resolveDa9726DataFolder('noise');
end
[config, cancelled] = converter.io.prepareDacInputs( ...
    da9726Config('noise'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runNoise(config);
end

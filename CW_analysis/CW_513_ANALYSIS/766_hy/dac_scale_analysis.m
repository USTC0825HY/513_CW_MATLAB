function result = dac_scale_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_SCALE_ANALYSIS Select DA766 MAT captures and run the existing scale core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
defaultFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'DA766', '06_scale');
[config, cancelled] = converter.io.prepareDacInputs( ...
    da766Config('scale'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runScale(config);
end

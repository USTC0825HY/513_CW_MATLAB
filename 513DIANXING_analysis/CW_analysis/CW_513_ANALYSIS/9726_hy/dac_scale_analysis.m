function result = dac_scale_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_SCALE_ANALYSIS Select DA9726 MAT captures and run the existing scale core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
%   Scale analysis requires filenames containing CODE/COADE hexadecimal code
%   labels.  Noise captures such as JG18.mat are not scale inputs.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
[dataFolder, selectedFiles] = normalizeDa9726Input(dataFolder, selectedFiles);
defaultFolder = resolveDa9726DataFolder('scale');
[config, cancelled] = converter.io.prepareDacInputs( ...
    da9726Config('scale'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runScale(config);
end

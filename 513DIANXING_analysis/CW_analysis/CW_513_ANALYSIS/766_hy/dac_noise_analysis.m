function result = dac_noise_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_NOISE_ANALYSIS Run the standalone DA766 noise analysis.
bootstrapRuntime();
config = da766Config('noise');
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
config = localApplyInputs(config, dataFolder, selectedFiles, outputFolder);
if nargin >= 4, config = converter.runtime.mergeConfig(config, configOverride); end
result = converter.dac.runNoise(config);
end

function config = localApplyInputs(config, dataFolder, selectedFiles, outputFolder)
if nargin < 1 || isempty(dataFolder), dataFolder = uigetdir(pwd, '选择DA766噪声MAT目录'); end
if isequal(dataFolder, 0), error('cw513:SelectionCancelled', '已取消数据目录选择。'); end
if nargin < 2 || isempty(selectedFiles), selectedFiles = {}; end
if nargin < 3 || isempty(outputFolder), outputFolder = ''; end
config.dataFolder = char(dataFolder); config.inputFiles = selectedFiles;
config.outputFolder = char(outputFolder);
end

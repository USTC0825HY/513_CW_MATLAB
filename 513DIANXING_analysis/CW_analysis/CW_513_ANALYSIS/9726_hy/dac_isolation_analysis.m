function result = dac_isolation_analysis(dataFolder, pairManifest, outputFolder, configOverride)
%DAC_ISOLATION_ANALYSIS Run the standalone DA9726 isolation analysis.
bootstrapRuntime();
config = da9726Config('isolation');
if nargin < 1 || isempty(dataFolder), dataFolder = uigetdir(pwd, '选择DA9726隔离度数据目录'); end
if isequal(dataFolder, 0), error('cw513:SelectionCancelled', '已取消数据目录选择。'); end
if nargin < 2, pairManifest = []; end
if nargin < 3, outputFolder = ''; end
config.dataFolder = char(dataFolder); config.pairManifest = pairManifest;
config.outputFolder = char(outputFolder);
if nargin >= 4, config = converter.runtime.mergeConfig(config, configOverride); end
result = converter.dac.runIsolation(config);
end

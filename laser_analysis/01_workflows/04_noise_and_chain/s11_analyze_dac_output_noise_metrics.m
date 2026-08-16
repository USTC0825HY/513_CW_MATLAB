%S11_ANALYZE_DAC_OUTPUT_NOISE_METRICS Compatibility adapter for CW_513_ANALYSIS.
%   No PSD/ASD implementation is kept in this workflow path.  A caller may
%   provide dacNoiseCfgOverride using the historical field names; fields
%   are translated by the portable DA entry point.

workflowFolder = fileparts(mfilename('fullpath'));
laserAnalysisFolder = fileparts(fileparts(workflowFolder));
cwRoot = fullfile(fileparts(laserAnalysisFolder), '513DIANXING_analysis', ...
    'CW_analysis', 'CW_513_ANALYSIS');
if ~isfolder(cwRoot)
    error('cw513:LibraryMissing', ...
        '需要先添加 CW_513_ANALYSIS 分析库路径：%s', cwRoot);
end
addpath(fullfile(cwRoot, '_shared'));

if exist('dacNoiseCfgOverride', 'var') && isstruct(dacNoiseCfgOverride)
    override = dacNoiseCfgOverride;
else
    override = struct();
end
analysisName = char(localField(override, 'analysisName', 'DA9726'));
if ~isempty(strfind(upper(analysisName), '766')) || strcmpi(analysisName, 'X7') %#ok<STREMP>
    addpath(fullfile(cwRoot, '766_hy'));
else
    addpath(fullfile(cwRoot, '9726_hy'));
end
dataFolder = localField(override, 'dataDir', '');
if isempty(dataFolder)
    dataFolder = getenv('S11_DAC_DATA_DIR');
end
if isempty(dataFolder)
    dataFolder = uigetdir(pwd, '选择DAC噪声MAT目录');
end
if isequal(dataFolder, 0)
    error('cw513:SelectionCancelled', '已取消数据目录选择。');
end
dataFolder = char(dataFolder);
inputFiles = localField(override, 'inputFiles', {});
if isempty(inputFiles), inputFiles = {}; end
outputFolder = localField(override, 'outputDir', '');
if isempty(outputFolder), outputFolder = fullfile(dataFolder, 'results'); end
cfg = override;
cfg.dataDir = dataFolder;
cfg.outputDir = char(outputFolder);
result = dac_noise_analysis(dataFolder, inputFiles, outputFolder, cfg);
resultTable = result.summary;
outputDir = result.outputFolder;
cfg.outputDir = outputDir;
fprintf('CW_513_ANALYSIS噪声适配完成：%s\n', outputDir);

function value = localField(structure, name, defaultValue)
if isfield(structure, name) && ~isempty(structure.(name))
    value = structure.(name);
else
    value = defaultValue;
end
end

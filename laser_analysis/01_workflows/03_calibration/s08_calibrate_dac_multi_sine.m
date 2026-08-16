%S08_CALIBRATE_DAC_MULTI_SINE Compatibility adapter for CW_513_ANALYSIS.
%   The historical implementation is archived under
%   archive/legacy_20260816_cw513_pre_refactor.  This entry only builds a
%   configuration and delegates the calculation to the portable library.

workflowFolder = fileparts(mfilename('fullpath'));
laserAnalysisFolder = fileparts(fileparts(workflowFolder));
cwRoot = fullfile(fileparts(laserAnalysisFolder), '513DIANXING_analysis', ...
    'CW_analysis', 'CW_513_ANALYSIS');
if ~isfolder(cwRoot)
    error('cw513:LibraryMissing', ...
        '需要先添加 CW_513_ANALYSIS 分析库路径：%s', cwRoot);
end
addpath(fullfile(cwRoot, '_shared'));
addpath(fullfile(cwRoot, '9726_hy'));

dataFolder = getenv('S08_DAC_DATA_DIR');
if isempty(dataFolder)
    dataFolder = uigetdir(pwd, '选择DAC刻度MAT目录');
end
if isequal(dataFolder, 0)
    error('cw513:SelectionCancelled', '已取消数据目录选择。');
end
outputFolder = fullfile(char(dataFolder), 'results');
override = struct('toneFrequencyHz', 1e3, 'hardwareGain', 1);
excludedText = getenv('S08_EXCLUDED_SIGNED_CODES');
if ~isempty(excludedText)
    override.excludedSignedCodes = sscanf(strrep(excludedText, ',', ' '), '%f').';
end
result = dac_scale_analysis(dataFolder, {}, outputFolder, override);
results = result.measurements;
summary = result.summary;
cfg = result.config;
outputDir = result.outputFolder;
fprintf('CW_513_ANALYSIS刻度适配完成：%s\n', outputDir);

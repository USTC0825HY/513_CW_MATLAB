%S17_BATCH_DA766_DC_NOISE Compatibility adapter for CW_513_ANALYSIS.
%   The historical channel-by-channel Welch implementation is archived.
%   This adapter discovers channel MAT files and calls the DA766 entry.

workflowFolder = fileparts(mfilename('fullpath'));
laserAnalysisFolder = fileparts(fileparts(workflowFolder));
cwRoot = fullfile(fileparts(laserAnalysisFolder), '513DIANXING_analysis', ...
    'CW_analysis', 'CW_513_ANALYSIS');
if ~isfolder(cwRoot)
    error('cw513:LibraryMissing', ...
        '需要先添加 CW_513_ANALYSIS 分析库路径：%s', cwRoot);
end
addpath(fullfile(cwRoot, '_shared'));
addpath(fullfile(cwRoot, '766_hy'));

dataRoot = getenv('S17_DA766_DATA_ROOT');
if isempty(dataRoot)
    dataRoot = fullfile('F:', '01_Laser', '20260727_513test', ...
        'CW_Data', '513_CW_DATA', 'DA766', '03_DCNoise');
end
if ~isfolder(dataRoot)
    error('cw513:DataRootNotFound', 'DA766数据目录不存在：%s', dataRoot);
end
channelDirs = dir(dataRoot);
channelDirs = channelDirs([channelDirs.isdir] & ...
    ~ismember({channelDirs.name}, {'.', '..'}));
allSummary = [];
for channelIndex = 1:numel(channelDirs)
    channelFolder = fullfile(channelDirs(channelIndex).folder, ...
        channelDirs(channelIndex).name);
    rawFiles = dir(fullfile(channelFolder, '**', '*.mat'));
    if isempty(rawFiles), continue; end
    inputFiles = cell(numel(rawFiles), 1);
    for fileIndex = 1:numel(rawFiles)
        inputFiles{fileIndex} = fullfile(rawFiles(fileIndex).folder, ...
            rawFiles(fileIndex).name);
    end
    outputFolder = fullfile(channelFolder, 'result');
    override = struct('asdCheckHz', 1, 'asdLimit_uVPerSqrtHz', 12, ...
        'integratedBandHz', [1e3, 100e3], 'integratedLimit_uVrms', 1000, ...
        'targetResolutionHz', 0.2, 'overlapRatio', 0.5, ...
        'windowType', 'hann', 'asdOnly', false, 'formalEnabled', false);
    oneResult = dac_noise_analysis(channelFolder, inputFiles, ...
        outputFolder, override);
    if isempty(allSummary)
        allSummary = oneResult.summary;
    else
        allSummary = [allSummary; oneResult.summary]; %#ok<AGROW>
    end
end
if ~isempty(allSummary)
    converter.report.writeTable(allSummary, fullfile(dataRoot, ...
        'DA766_CW_513_ANALYSIS_summary.csv'));
end

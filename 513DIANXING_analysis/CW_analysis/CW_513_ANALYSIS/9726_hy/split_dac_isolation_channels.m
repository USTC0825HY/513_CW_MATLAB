function result = split_dac_isolation_channels(dataFolder, selectedFiles, outputFolder, options)
%SPLIT_DAC_ISOLATION_CHANNELS Split Pico MAT waveforms without drive analysis.
%   Maps filename JG labels to present A/B/C/D variables in order, saves
%   each waveform as A, and preserves acquisition metadata and source hashes.
%   No driven channel, folder naming, tone fit or reference plane is required.
%   OPTIONS.channelMapping optionally supplies source_file, source_variable,
%   channel_label. No isolation pair manifest is generated.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4 || isempty(options), options = struct(); end

defaultFolder = fullfile('I:', filesep, '513_CW_test', 'CW_Data', ...
    '513_CW_DATA_jianding', 'DA9726', '05_Isolation');
if isempty(dataFolder), dataFolder = defaultFolder; end
[selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, ...
    selectedFiles, '选择需要切分的PICO隔离度MAT');
if isempty(selectedFiles)
    result = struct([]);
    return;
end

if ~isfield(options, 'channelMapping'), options.channelMapping = []; end
channelEntries = localInspectSources(dataFolder, selectedFiles, options);
localValidateUniqueLabels(channelEntries);
if isempty(outputFolder), outputFolder = fullfile(dataFolder, 'split'); end
runFolder = localCreateRunFolder(outputFolder);
channelRows = localWriteChannels(channelEntries, runFolder);
channelManifestPath = fullfile(runFolder, 'channel_manifest.csv');
converter.report.writeTable(channelRows, channelManifestPath);
result = struct('version', '0.2.0', 'dataFolder', dataFolder, ...
    'outputFolder', runFolder, 'channelManifestPath', channelManifestPath, ...
    'channelRows', channelRows);
save(fullfile(runFolder, 'channel_split_result.mat'), 'result');
fprintf('MAT通道切分完成：%s；共%d路。\n', runFolder, height(channelRows));
end

function entries = localInspectSources(dataFolder, selectedFiles, options)
emptyEntry = struct('sourceFile', '', 'sourceName', '', ...
    'sourceVariable', '', 'channelLabel', '', 'waveform', [], ...
    'sampleCount', NaN, 'sampleRateHz', NaN, 'tstartS', NaN, ...
    'sourceSha256', '');
entries = repmat(emptyEntry, 0, 1);
for fileIndex = 1:numel(selectedFiles)
    sourcePath = converter.io.resolveInputPath(dataFolder, selectedFiles{fileIndex});
    sourceData = load(sourcePath);
    [~, sourceName] = fileparts(sourcePath);
    variables = {'A', 'B', 'C', 'D'};
    present = variables(cellfun(@(name) isfield(sourceData, name), variables));
    if isempty(present)
        error('converter:dac:IsolationWaveformMissing', ...
            'MAT文件不含A/B/C/D波形：%s', sourcePath);
    end
    labels = localSourceLabels(sourcePath, present, options.channelMapping);
    [sampleRateHz, tstartS] = localTimebase(sourceData, sourcePath);
    sourceHash = converter.runtime.sha256File(sourcePath);
    for variableIndex = 1:numel(present)
        waveform = sourceData.(present{variableIndex});
        if ~isnumeric(waveform) || ~isvector(waveform) || isempty(waveform)
            error('converter:dac:IsolationWaveformInvalid', ...
                '通道%s必须是非空数值向量：%s', present{variableIndex}, sourcePath);
        end
        entry = emptyEntry;
        entry.sourceFile = sourcePath;
        entry.sourceName = sourceName;
        entry.sourceVariable = present{variableIndex};
        entry.channelLabel = labels{variableIndex};
        entry.waveform = waveform(:);
        entry.sampleCount = numel(waveform);
        entry.sampleRateHz = sampleRateHz;
        entry.tstartS = tstartS;
        entry.sourceSha256 = sourceHash;
        entries(end + 1, 1) = entry; %#ok<AGROW>
    end
end
end

function labels = localSourceLabels(sourcePath, presentVariables, explicitMapping)
[~, sourceName, sourceExtension] = fileparts(sourcePath);
if ~isempty(explicitMapping)
    labels = localExplicitLabels([sourceName sourceExtension], ...
        presentVariables, explicitMapping);
    return;
end
labels = regexp(sourceName, '(?i)JG\d+', 'match');
labels = cellfun(@upper, labels, 'UniformOutput', false);
if numel(labels) ~= numel(presentVariables)
    error('converter:dac:IsolationChannelMapAmbiguous', ...
        ['文件名中的JG接口数与A/B/C/D波形数不一致：%s。' ...
        '请提供options.channelMapping。'], sourcePath);
end
end

function labels = localExplicitLabels(sourceFileName, presentVariables, mapping)
if isstruct(mapping), mapping = struct2table(mapping); end
if ~istable(mapping)
    error('converter:dac:IsolationChannelMappingType', ...
        'options.channelMapping必须是table或struct。');
end
required = {'source_file', 'source_variable', 'channel_label'};
if ~all(ismember(required, mapping.Properties.VariableNames))
    error('converter:dac:IsolationChannelMappingFields', ...
        'channelMapping必须包含source_file、source_variable、channel_label。');
end
mappingNames = string(mapping.source_file);
[~, sourceStem] = fileparts(sourceFileName);
rowMask = strcmpi(mappingNames, sourceFileName) | ...
    strcmpi(mappingNames, sourceStem);
selected = mapping(rowMask, :);
labels = cell(1, numel(presentVariables));
for k = 1:numel(presentVariables)
    variableMask = strcmpi(string(selected.source_variable), presentVariables{k});
    if nnz(variableMask) ~= 1
        error('converter:dac:IsolationChannelMappingMatch', ...
            '显式映射必须为%s中的%s提供唯一接口。', ...
            sourceFileName, presentVariables{k});
    end
    labels{k} = upper(strtrim(char(string(selected.channel_label(variableMask)))));
end
end

function [sampleRateHz, tstartS] = localTimebase(sourceData, sourcePath)
if isfield(sourceData, 'Tinterval') && ~isempty(sourceData.Tinterval)
    sampleRateHz = 1 / double(sourceData.Tinterval(1));
elseif isfield(sourceData, 'fs') && ~isempty(sourceData.fs)
    sampleRateHz = double(sourceData.fs(1));
else
    error('converter:dac:IsolationTimebaseMissing', ...
        'MAT文件缺少Tinterval或fs：%s', sourcePath);
end
if ~isfinite(sampleRateHz) || sampleRateHz <= 0
    error('converter:dac:IsolationTimebaseInvalid', ...
        'MAT文件采样率无效：%s', sourcePath);
end
if isfield(sourceData, 'Tstart') && ~isempty(sourceData.Tstart)
    tstartS = double(sourceData.Tstart(1));
else
    tstartS = NaN;
end
end

function localValidateUniqueLabels(entries)
labels = upper(string({entries.channelLabel}));
if numel(unique(labels)) ~= numel(labels)
    error('converter:dac:IsolationDuplicateChannel', ...
        '切分映射包含重复接口；请检查文件选择或显式映射。');
end
for k = 1:numel(labels)
    if isempty(regexp(char(labels(k)), '^JG\d+$', 'once'))
        error('converter:dac:IsolationChannelLabel', ...
            '接口名必须采用JG加数字的格式：%s', labels(k));
    end
end
end

function runFolder = localCreateRunFolder(outputFolder)
outputFolder = char(outputFolder);
if ~isfolder(outputFolder), mkdir(outputFolder); end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
baseName = ['run_' stamp '_channel_split'];
runFolder = fullfile(outputFolder, baseName);
suffix = 1;
while isfolder(runFolder)
    runFolder = fullfile(outputFolder, sprintf('%s_%02d', baseName, suffix));
    suffix = suffix + 1;
end
[created, message] = mkdir(runFolder);
if ~created
    error('converter:dac:IsolationOutputFolder', ...
        '无法创建切分结果目录：%s (%s)', runFolder, message);
end
end

function rows = localWriteChannels(entries, runFolder)
emptyRow = struct('source_file', "", 'source_variable', "", ...
    'channel_label', "", 'output_file', "", 'sample_count', NaN, ...
    'sample_rate_hz', NaN, 'tstart_s', NaN, 'source_sha256', "", ...
    'output_sha256', "");
rowStructs = repmat(emptyRow, numel(entries), 1);
for k = 1:numel(entries)
    entry = entries(k);
    safeSourceName = regexprep(entry.sourceName, '[^A-Za-z0-9_.-]', '_');
    outputName = sprintf('%s__%s__%s.mat', upper(entry.channelLabel), ...
        safeSourceName, upper(entry.sourceVariable));
    outputPath = fullfile(runFolder, outputName);
    if isfile(outputPath)
        error('converter:dac:IsolationSplitCollision', ...
            '切分输出文件已存在：%s', outputPath);
    end
    sourceData = load(entry.sourceFile);
    outputData = localMetadata(sourceData);
    outputData.A = entry.waveform;
    outputData.SourceFile = entry.sourceFile;
    outputData.SourceVariable = entry.sourceVariable;
    outputData.ChannelLabel = entry.channelLabel;
    outputData.SplitVersion = '0.2.0';
    save(outputPath, '-struct', 'outputData', '-v7');

    rowStructs(k).source_file = string(entry.sourceFile);
    rowStructs(k).source_variable = string(entry.sourceVariable);
    rowStructs(k).channel_label = string(entry.channelLabel);
    rowStructs(k).output_file = string(outputName);
    rowStructs(k).sample_count = entry.sampleCount;
    rowStructs(k).sample_rate_hz = entry.sampleRateHz;
    rowStructs(k).tstart_s = entry.tstartS;
    rowStructs(k).source_sha256 = string(entry.sourceSha256);
    rowStructs(k).output_sha256 = string(converter.runtime.sha256File(outputPath));
end
rows = struct2table(rowStructs);
end

function outputData = localMetadata(sourceData)
outputData = struct();
metadataNames = {'Tstart', 'Tinterval', 'fs', 'ExtraSamples', ...
    'RequestedLength', 'Length', 'Version'};
for k = 1:numel(metadataNames)
    if isfield(sourceData, metadataNames{k})
        outputData.(metadataNames{k}) = sourceData.(metadataNames{k});
    end
end
end

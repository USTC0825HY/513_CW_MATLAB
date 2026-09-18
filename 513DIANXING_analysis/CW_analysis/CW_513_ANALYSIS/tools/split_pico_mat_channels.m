function result = split_pico_mat_channels(dataFolder, selectedFiles, outputFolder, options)
%SPLIT_PICO_MAT_CHANNELS Split every waveform channel found in Pico MAT files.
%   R = SPLIT_PICO_MAT_CHANNELS() opens a multi-select MAT dialog.
%   R = SPLIT_PICO_MAT_CHANNELS(DATAFOLDER) auto-scans *.mat in DATAFOLDER.
%   R = SPLIT_PICO_MAT_CHANNELS(DATAFOLDER, FILES) processes listed files.
%   Only the no-argument form opens a dialog; both batch forms are fully
%   non-interactive. This is the generic tool: the channel count is
%   auto-detected from each file (every top-level numeric vector variable
%   that is not metadata counts as one channel), labels default to the
%   variable name with no naming scheme enforced, and no device folder is
%   assumed. Each waveform is written as its own single-channel MAT with
%   the data always stored as variable "A" plus the preserved Pico
%   metadata, so downstream Pico loaders can consume every output
%   uniformly.
%
%   OPTIONS (all optional):
%     channelMapping        table/struct with columns source_file,
%                           source_variable, channel_label; free-form
%                           labels rename the outputs. A mapping row may
%                           name the file with or without its extension;
%                           rows that match nothing raise a warning.
%     metadataVariables     cellstr of extra variable names to exclude from
%                           channel detection (never split as waveforms).
%     minimumWaveformSamples  minimum sample count for a channel (default 2).
%
%   Output goes to OUTPUTFOLDER, or DATAFOLDER\split by default, inside a
%   timestamped run_*_pico_split folder with channel_manifest.csv, a
%   result MAT, and SHA-256 hashes of every source and output file.
%   Source files are read only and never modified.

bootstrapRuntimeLocal();
if nargin < 1, dataFolder = []; end
if nargin < 2 || isempty(selectedFiles), selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4 || isempty(options), options = struct(); end
if ~isstruct(options) || ~isscalar(options)
    error('pico:split:InvalidOptions', 'options 必须是标量结构体。');
end
if isempty(dataFolder) && isempty(selectedFiles)
    [selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, ...
        selectedFiles, '选择需要切分的PICO MAT（可多选）');
    if isempty(selectedFiles)
        result = struct([]);
        return;
    end
elseif isempty(selectedFiles)
    selectedFiles = listMatFiles(dataFolder);
else
    [selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, ...
        selectedFiles, []);
end
if isempty(selectedFiles)
    error('pico:split:NoMatFiles', '数据目录中没有MAT文件：%s', dataFolder);
end
if isempty(outputFolder)
    outputFolder = fullfile(dataFolder, 'split');
end
if ~isfield(options, 'metadataVariables'), options.metadataVariables = {}; end
if ~isfield(options, 'minimumWaveformSamples')
    options.minimumWaveformSamples = 2;
end
if ~isfield(options, 'channelMapping'), options.channelMapping = []; end
options.mappingTable = normalizeMapping(options.channelMapping);

runFolder = createRunFolder(outputFolder);
entries = inspectSources(dataFolder, selectedFiles, options);
channelRows = writeChannels(entries, runFolder);
manifestPath = fullfile(runFolder, 'channel_manifest.csv');
converter.report.writeTable(channelRows, manifestPath);
result = struct('version', '1.0.0', 'dataFolder', dataFolder, ...
    'outputFolder', runFolder, 'channelManifestPath', manifestPath, ...
    'channelRows', channelRows);
save(fullfile(runFolder, 'channel_split_result.mat'), 'result');
fprintf('MAT通道切分完成：%s；共%d路（来自%d个文件）。\n', ...
    runFolder, height(channelRows), numel(selectedFiles));
end

function files = listMatFiles(dataFolder)
%LISTMATFILES Auto-scan the folder; no dialog is ever opened.
listing = dir(fullfile(char(dataFolder), '*.mat'));
files = sort({listing.name});
end

function mappingTable = normalizeMapping(channelMapping)
%NORMALIZEMAPPING Validate the optional renaming table once, up front.
mappingTable = [];
if isempty(channelMapping)
    return;
end
if isstruct(channelMapping), channelMapping = struct2table(channelMapping); end
if ~istable(channelMapping)
    error('pico:split:ChannelMappingType', ...
        'options.channelMapping必须是table或struct。');
end
required = {'source_file', 'source_variable', 'channel_label'};
if ~all(ismember(required, channelMapping.Properties.VariableNames))
    error('pico:split:ChannelMappingFields', ...
        'channelMapping必须包含source_file、source_variable、channel_label。');
end
mappingTable = channelMapping;
end

function entries = inspectSources(dataFolder, selectedFiles, options)
%INSPECTSOURCES Detect waveform channels and timebase in every source MAT.
emptyEntry = struct('sourceFile', '', 'sourceStem', '', 'sourceFullName', '', ...
    'sourceVariable', '', 'channelLabel', '', 'waveform', [], ...
    'sampleCount', NaN, 'sampleRateHz', NaN, 'tstartS', NaN, ...
    'timebaseSource', '', 'sourceSha256', '');
entries = repmat(emptyEntry, 0, 1);
for fileIndex = 1:numel(selectedFiles)
    sourcePath = converter.io.resolveInputPath(dataFolder, selectedFiles{fileIndex});
    sourceData = load(sourcePath);
    [~, sourceStem, sourceExtension] = fileparts(sourcePath);
    sourceFullName = [sourceStem, sourceExtension];
    variableNames = detectWaveformVariables(sourceData, options);
    if isempty(variableNames)
        error('pico:split:WaveformMissing', ...
            'MAT文件没有可识别的波形通道（数值向量变量）：%s', sourcePath);
    end
    [sampleRateHz, tstartS, timebaseSource] = resolveTimebase(sourceData, sourcePath);
    sourceHash = converter.runtime.sha256File(sourcePath);
    fprintf('%s：识别到 %d 路通道（%s）。\n', sourceFullName, ...
        numel(variableNames), strjoin(variableNames, ', '));
    for variableIndex = 1:numel(variableNames)
        waveform = sourceData.(variableNames{variableIndex});
        entry = emptyEntry;
        entry.sourceFile = sourcePath;
        entry.sourceStem = sourceStem;
        entry.sourceFullName = sourceFullName;
        entry.sourceVariable = variableNames{variableIndex};
        entry.channelLabel = resolveLabel(sourceFullName, ...
            variableNames{variableIndex}, options.mappingTable);
        entry.waveform = double(waveform(:));
        entry.sampleCount = numel(waveform);
        entry.sampleRateHz = sampleRateHz;
        entry.tstartS = tstartS;
        entry.timebaseSource = timebaseSource;
        entry.sourceSha256 = sourceHash;
        entries(end + 1, 1) = entry; %#ok<AGROW>
    end
end
warnUnusedMappingRows(options.mappingTable, entries);
end

function variableNames = detectWaveformVariables(sourceData, options)
%DETECTWAVEFORMVARIABLES Numeric non-metadata vectors are waveform channels.
metadataNames = {'Tstart', 'Tinterval', 'fs', 'ExtraSamples', ...
    'RequestedLength', 'Length', 'Version', 'NoOfCaptures', ...
    'SegmentTimes', 'Ttimes', 'SourceFile', 'SourceVariable', ...
    'ChannelLabel', 'SplitVersion', 'SplitToolVersion'};
excluded = [metadataNames, cellstr(options.metadataVariables)];
allNames = fieldnames(sourceData);
variableNames = {};
for nameIndex = 1:numel(allNames)
    name = allNames{nameIndex};
    if any(strcmpi(excluded, name))
        continue;
    end
    value = sourceData.(name);
    if ~isnumeric(value) && ~islogical(value)
        continue;
    end
    if ~isvector(value) || numel(value) < options.minimumWaveformSamples
        continue;
    end
    variableNames{end + 1, 1} = name; %#ok<AGROW>
end
variableNames = sortWaveformVariables(variableNames);
end

function sorted = sortWaveformVariables(variableNames)
%SORTWAVEFORMVARIABLES Pico channel letters first, then alphabetical.
preferredOrder = 'ABCDEFGH';
sorted = {};
for letterIndex = 1:numel(preferredOrder)
    letter = preferredOrder(letterIndex);
    if any(strcmp(variableNames, letter))
        sorted{end + 1, 1} = letter; %#ok<AGROW>
    end
end
remaining = setdiff(variableNames, sorted, 'stable');
sorted = [sorted; sort(remaining)];
end

function label = resolveLabel(sourceFullName, variableName, mappingTable)
%RESOLVELABEL Default label is the variable name; mapping may rename it.
%   A mapping row matches on the file name with or without extension and
%   on the variable name, both case-insensitive.
label = variableName;
if isempty(mappingTable)
    return;
end
[~, sourceStem] = fileparts(sourceFullName);
matchFile = strcmpi(string(mappingTable.source_file), string(sourceFullName)) | ...
    strcmpi(string(mappingTable.source_file), string(sourceStem));
matchVariable = strcmpi(string(mappingTable.source_variable), string(variableName));
rowIndex = find(matchFile & matchVariable);
if isempty(rowIndex)
    return;
end
if numel(rowIndex) > 1
    error('pico:split:ChannelMappingAmbiguous', ...
        'channelMapping为%s的%s提供了多个标签。', sourceFullName, variableName);
end
label = strtrim(char(string(mappingTable.channel_label(rowIndex))));
if isempty(label)
    error('pico:split:ChannelMappingEmpty', ...
        'channelMapping为%s的%s提供了空标签。', sourceFullName, variableName);
end
end

function warnUnusedMappingRows(mappingTable, entries)
%WARNUNUSEDMAPPINGROWS A mapping row that matched nothing is likely a typo.
if isempty(mappingTable)
    return;
end
sourceNames = string({entries.sourceFullName});
sourceStems = string({entries.sourceStem});
sourceVariables = string({entries.sourceVariable});
for rowIndex = 1:height(mappingTable)
    mapFile = string(mappingTable.source_file(rowIndex));
    mapVariable = string(mappingTable.source_variable(rowIndex));
    fileHit = any(strcmpi(sourceNames, mapFile) | strcmpi(sourceStems, mapFile));
    variableHit = any(strcmpi(sourceVariables, mapVariable));
    if fileHit && variableHit
        continue;
    end
    warning('pico:split:ChannelMappingUnused', ...
        'channelMapping第%d行（%s / %s）未匹配任何输入文件或变量。', ...
        rowIndex, mapFile, mapVariable);
end
end

function [sampleRateHz, tstartS, timebaseSource] = resolveTimebase(sourceData, sourcePath)
%RESOLVETIMEBASE Pico Tinterval first, then fs; missing yields NaN + warning.
if isfield(sourceData, 'Tinterval') && ~isempty(sourceData.Tinterval) && ...
        all(isfinite(double(sourceData.Tinterval(:)))) && ...
        all(double(sourceData.Tinterval(:)) > 0)
    sampleRateHz = 1 / double(sourceData.Tinterval(1));
    timebaseSource = 'Tinterval';
elseif isfield(sourceData, 'fs') && ~isempty(sourceData.fs) && ...
        isfinite(double(sourceData.fs(1))) && double(sourceData.fs(1)) > 0
    sampleRateHz = double(sourceData.fs(1));
    timebaseSource = 'fs';
else
    sampleRateHz = NaN;
    timebaseSource = 'missing';
    warning('pico:split:TimebaseMissing', ...
        'MAT文件缺少有效Tinterval/fs，采样率记为NaN：%s', sourcePath);
end
if isfield(sourceData, 'Tstart') && ~isempty(sourceData.Tstart)
    tstartS = double(sourceData.Tstart(1));
else
    tstartS = NaN;
end
end

function runFolder = createRunFolder(outputFolder)
%CREATERUNFOLDER Timestamped output folder with collision suffixes.
outputFolder = char(outputFolder);
if ~isfolder(outputFolder), mkdir(outputFolder); end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
baseName = ['run_' stamp '_pico_split'];
runFolder = fullfile(outputFolder, baseName);
suffix = 1;
while isfolder(runFolder)
    runFolder = fullfile(outputFolder, sprintf('%s_%02d', baseName, suffix));
    suffix = suffix + 1;
end
[created, message] = mkdir(runFolder);
if ~created
    error('pico:split:OutputFolder', ...
        '无法创建切分结果目录：%s (%s)', runFolder, message);
end
end

function rows = writeChannels(entries, runFolder)
%WRITECHANNELS One single-channel MAT per waveform; data always as "A".
emptyRow = struct('source_file', "", 'source_variable', "", ...
    'channel_label', "", 'output_file', "", 'sample_count', NaN, ...
    'sample_rate_hz', NaN, 'tstart_s', NaN, 'timebase_source', "", ...
    'source_sha256', "", 'output_sha256', "");
rowStructs = repmat(emptyRow, numel(entries), 1);
for k = 1:numel(entries)
    entry = entries(k);
    safeSourceName = regexprep(entry.sourceStem, '[^A-Za-z0-9_.-]', '_');
    safeLabel = regexprep(entry.channelLabel, '[^A-Za-z0-9_.-]', '_');
    if isempty(safeLabel)
        error('pico:split:LabelInvalid', ...
            '通道标签不含可用字符：%s', entry.channelLabel);
    end
    outputName = sprintf('%s__%s__%s.mat', safeLabel, safeSourceName, ...
        upper(regexprep(entry.sourceVariable, '[^A-Za-z0-9_.-]', '_')));
    outputPath = fullfile(runFolder, outputName);
    if isfile(outputPath)
        error('pico:split:OutputCollision', ...
            '切分输出文件已存在：%s', outputPath);
    end
    sourceData = load(entry.sourceFile);
    outputData = copyPicoMetadata(sourceData);
    outputData.A = entry.waveform;
    outputData.SourceFile = entry.sourceFile;
    outputData.SourceVariable = entry.sourceVariable;
    outputData.ChannelLabel = entry.channelLabel;
    outputData.SplitToolVersion = '1.0.0';
    save(outputPath, '-struct', 'outputData', '-v7');

    rowStructs(k).source_file = string(entry.sourceFile);
    rowStructs(k).source_variable = string(entry.sourceVariable);
    rowStructs(k).channel_label = string(entry.channelLabel);
    rowStructs(k).output_file = string(outputName);
    rowStructs(k).sample_count = entry.sampleCount;
    rowStructs(k).sample_rate_hz = entry.sampleRateHz;
    rowStructs(k).tstart_s = entry.tstartS;
    rowStructs(k).timebase_source = string(entry.timebaseSource);
    rowStructs(k).source_sha256 = string(entry.sourceSha256);
    rowStructs(k).output_sha256 = string( ...
        converter.runtime.sha256File(outputPath));
end
rows = struct2table(rowStructs);
end

function outputData = copyPicoMetadata(sourceData)
%COPYPICOMETADATA Preserve the PicoScope export metadata fields verbatim.
outputData = struct();
metadataNames = {'Tstart', 'Tinterval', 'fs', 'ExtraSamples', ...
    'RequestedLength', 'Length', 'Version', 'NoOfCaptures', ...
    'SegmentTimes', 'Ttimes'};
for k = 1:numel(metadataNames)
    if isfield(sourceData, metadataNames{k})
        outputData.(metadataNames{k}) = sourceData.(metadataNames{k});
    end
end
end

function bootstrapRuntimeLocal()
%BOOTSTRAPRUNTIMELOCAL Load the adjacent shared core or a packaged runtime.
toolsFolder = fileparts(mfilename('fullpath'));
analysisRoot = fileparts(toolsFolder);
packaged = fullfile(analysisRoot, 'internal');
shared = fullfile(analysisRoot, '_shared');
if isfolder(fullfile(packaged, '+converter'))
    addpath(packaged);
elseif isfolder(fullfile(shared, '+converter'))
    addpath(shared);
else
    error('pico:split:RuntimeMissing', '请保留tools旁的_shared目录。');
end
end

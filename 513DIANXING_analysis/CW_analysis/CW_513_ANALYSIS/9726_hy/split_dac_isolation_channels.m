function result = split_dac_isolation_channels(dataFolder, selectedFiles, outputFolder, options)
%SPLIT_DAC_ISOLATION_CHANNELS Split Pico MAT waveforms without drive analysis.
%   Maps filename JG labels to present A/B/C/D variables in order, saves
%   each waveform as A, and preserves acquisition metadata and source hashes.
%   No driven channel, folder naming, tone fit or reference plane is required.
%   OPTIONS.channelMapping optionally supplies source_file, source_variable,
%   channel_label. No isolation pair manifest is generated.
%   OPTIONS.codeFromPercent (struct with fullScaleCode, or a scalar) enables
%   percent-named uniform multi-channel captures: a "-<n>%" token in the
%   source file name is converted to raw_code = round(n/100*fullScaleCode)
%   and injected into the output name as CODE_<HEX>, so converter.dac.runScale
%   can parse the code axis without renaming files by hand.  The conversion
%   percent, rule, hex token and raw code are recorded in channel_manifest.csv.

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
codeFromPercent = localCodePercentRule(options);
channelEntries = localInspectSources(dataFolder, selectedFiles, options, ...
    codeFromPercent);
localValidateUniqueLabels(channelEntries);
if isempty(outputFolder), outputFolder = fullfile(dataFolder, 'split'); end
runFolder = localCreateRunFolder(outputFolder);
channelRows = localWriteChannels(channelEntries, runFolder);
channelManifestPath = fullfile(runFolder, 'channel_manifest.csv');
converter.report.writeTable(channelRows, channelManifestPath);
result = struct('version', '0.3.0', 'dataFolder', dataFolder, ...
    'outputFolder', runFolder, 'channelManifestPath', channelManifestPath, ...
    'channelRows', channelRows, ...
    'codeFromPercentRule', codeFromPercent);
save(fullfile(runFolder, 'channel_split_result.mat'), 'result');
fprintf('MAT通道切分完成：%s；共%d路。\n', runFolder, height(channelRows));
end

function rule = localCodePercentRule(options)
%CODEPERCENTRULE Optional percent-to-code naming for uniform captures.
rule = [];
if ~isfield(options, 'codeFromPercent') || isempty(options.codeFromPercent)
    return;
end
value = options.codeFromPercent;
if isstruct(value)
    if ~isfield(value, 'fullScaleCode')
        error('converter:dac:IsolationPercentRule', ...
            'options.codeFromPercent必须提供fullScaleCode字段。');
    end
    fullScaleCode = value.fullScaleCode;
else
    fullScaleCode = value;
end
validateattributes(fullScaleCode, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, 'split_dac_isolation_channels', ...
    'codeFromPercent.fullScaleCode');
rule = struct('fullScaleCode', double(fullScaleCode), ...
    'ruleText', sprintf('round(percent/100*%d) full-scale percent', ...
    fullScaleCode));
end

function [codePercent, codeRule, codeHex, codeRaw] = localPercentCode( ...
    sourceName, rule, sourcePath)
codePercent = NaN; codeRule = ''; codeHex = ''; codeRaw = NaN;
if isempty(rule), return; end
token = regexp(sourceName, '(?i)-(\d+)%', 'tokens', 'once');
if isempty(token)
    error('converter:dac:IsolationPercentMissing', ...
        'codeFromPercent要求文件名包含-<数字>%%幅值标记：%s', sourcePath);
end
codePercent = str2double(token{1});
codeRaw = round(codePercent / 100 * rule.fullScaleCode);
if ~isfinite(codeRaw) || codeRaw < 1 || codeRaw > 65535
    error('converter:dac:IsolationPercentCodeInvalid', ...
        '百分比%g按规则%s换算出码值%g，超出16位无符号范围：%s', ...
        codePercent, rule.ruleText, codeRaw, sourcePath);
end
codeHex = upper(dec2hex(codeRaw));
codeRule = rule.ruleText;
end

function entries = localInspectSources(dataFolder, selectedFiles, options, ...
    codeFromPercent)
emptyEntry = struct('sourceFile', '', 'sourceName', '', ...
    'sourceVariable', '', 'channelLabel', '', 'waveform', [], ...
    'sampleCount', NaN, 'sampleRateHz', NaN, 'tstartS', NaN, ...
    'sourceSha256', '', 'codePercent', NaN, 'codeRule', '', ...
    'codeHex', '', 'codeRaw', NaN);
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
    [codePercent, codeRule, codeHex, codeRaw] = localPercentCode( ...
        sourceName, codeFromPercent, sourcePath);
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
        entry.codePercent = codePercent;
        entry.codeRule = codeRule;
        entry.codeHex = codeHex;
        entry.codeRaw = codeRaw;
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
% Labels must be unique within each source file; repeated label sets across
% files are legitimate for same-channel captures at multiple steps.
sourceFiles = unique(string({entries.sourceFile}), 'stable');
for s = 1:numel(sourceFiles)
    mask = string({entries.sourceFile}) == sourceFiles(s);
    labels = upper(string({entries(mask).channelLabel}));
    if numel(unique(labels)) ~= numel(labels)
        error('converter:dac:IsolationDuplicateChannel', ...
            '同一文件的切分映射包含重复接口：%s', char(sourceFiles(s)));
    end
end
for k = 1:numel(entries)
    if isempty(regexp(upper(char(string(entries(k).channelLabel))), ...
            '^JG\d+$', 'once'))
        error('converter:dac:IsolationChannelLabel', ...
            '接口名必须采用JG加数字的格式：%s', entries(k).channelLabel);
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
    'output_sha256', "", 'code_percent', NaN, 'code_rule', "", ...
    'code_hex', "", 'raw_code', NaN);
rowStructs = repmat(emptyRow, numel(entries), 1);
for k = 1:numel(entries)
    entry = entries(k);
    safeSourceName = regexprep(entry.sourceName, '[^A-Za-z0-9_.-]', '_');
    if isempty(entry.codeHex)
        outputName = sprintf('%s__%s__%s.mat', upper(entry.channelLabel), ...
            safeSourceName, upper(entry.sourceVariable));
    else
        outputName = sprintf('%s__CODE_%s__%s__%s.mat', ...
            upper(entry.channelLabel), entry.codeHex, safeSourceName, ...
            upper(entry.sourceVariable));
    end
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
    outputData.SplitVersion = '0.3.0';
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
    rowStructs(k).code_percent = entry.codePercent;
    rowStructs(k).code_rule = string(entry.codeRule);
    rowStructs(k).code_hex = string(entry.codeHex);
    rowStructs(k).raw_code = entry.codeRaw;
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

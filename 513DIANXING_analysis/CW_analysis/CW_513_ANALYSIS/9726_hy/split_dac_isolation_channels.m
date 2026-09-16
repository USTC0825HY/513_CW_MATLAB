function result = split_dac_isolation_channels(dataFolder, selectedFiles, outputFolder, options)
%SPLIT_DAC_ISOLATION_CHANNELS Split PicoScope channels for DAC isolation.
%   RESULT = SPLIT_DAC_ISOLATION_CHANNELS(DATAFOLDER, SELECTEDFILES, ...
%   OUTPUTFOLDER, OPTIONS) maps A/B/C/D to the JG labels in each source
%   filename, saves one derived MAT per interface with waveform variable A,
%   estimates the driven tone, and writes channel/pair manifests.
%
%   The parent folder supplies the default driven interface and nominal
%   frequency, for example JG18-1M. Raw MAT files are never modified.
%
%   OPTIONS may contain drivenLabel, nominalFrequencyHz, referencePlane,
%   minimumDriveFitR2, frequencySearchFraction, and channelMapping. An
%   explicit channelMapping is a table/struct with source_file,
%   source_variable, and channel_label fields.
%
%   See also DAC_ISOLATION_ANALYSIS.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4 || isempty(options), options = struct(); end

defaultFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'DA9726', '05_Isolation');
if isempty(dataFolder), dataFolder = defaultFolder; end
[selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, ...
    selectedFiles, '选择需要切分的PICO隔离度MAT');
if isempty(selectedFiles)
    result = struct([]);
    return;
end

config = da9726Config('isolation');
options = localOptions(options, config);
[drivenLabel, nominalFrequencyHz] = localFolderConditions( ...
    dataFolder, options);
channelEntries = localInspectSources(dataFolder, selectedFiles, options);
localValidateUniqueLabels(channelEntries);

drivenIndex = find(strcmpi({channelEntries.channelLabel}, drivenLabel));
if numel(drivenIndex) ~= 1
    error('converter:dac:IsolationDrivenChannel', ...
        '驱动接口%s在切分映射中必须且只能出现一次。', drivenLabel);
end
drivenEntry = channelEntries(drivenIndex);
toneEstimate = converter.dac.estimateToneFrequency( ...
    drivenEntry.waveform, drivenEntry.sampleRateHz, nominalFrequencyHz, ...
    options.frequencySearchFraction);
measuredFrequencyHz = toneEstimate.frequencyHz;
driveFit = toneEstimate.fit;
driveFitReady = isfinite(driveFit.rSquared) && ...
    driveFit.rSquared >= options.minimumDriveFitR2;

if isempty(outputFolder), outputFolder = fullfile(dataFolder, 'split'); end
runFolder = localCreateRunFolder(outputFolder);
channelRows = localWriteChannels(channelEntries, runFolder);
channelManifestPath = fullfile(runFolder, 'channel_manifest.csv');
writetable(channelRows, channelManifestPath);

[pairRows, readinessNote] = localPairRows(channelRows, drivenLabel, ...
    nominalFrequencyHz, measuredFrequencyHz, driveFit, ...
    options, driveFitReady);
pairTemplatePath = fullfile(runFolder, 'pair_manifest_template.csv');
writetable(pairRows, pairTemplatePath);
analysisReady = driveFitReady && strlength(string(options.referencePlane)) > 0;
if analysisReady
    pairManifestPath = pairTemplatePath;
else
    pairManifestPath = '';
end

result = struct('version', '0.1.0', 'dataFolder', dataFolder, ...
    'outputFolder', runFolder, 'drivenLabel', drivenLabel, ...
    'nominalFrequencyHz', nominalFrequencyHz, ...
    'measuredFrequencyHz', measuredFrequencyHz, ...
    'frequencyOffsetHz', measuredFrequencyHz - nominalFrequencyHz, ...
    'driveFit', driveFit, 'channelManifestPath', channelManifestPath, ...
    'pairManifestTemplatePath', pairTemplatePath, ...
    'pairManifestPath', pairManifestPath, 'analysisReady', analysisReady, ...
    'readinessNote', readinessNote, 'channelRows', channelRows, ...
    'pairRows', pairRows);
save(fullfile(runFolder, 'channel_split_result.mat'), 'result');

fprintf('DA9726隔离度通道切分完成：%s\n', runFolder);
fprintf('驱动接口：%s；名义频率：%.9g Hz；实测频率：%.9g Hz；R^2：%.6f\n', ...
    drivenLabel, nominalFrequencyHz, measuredFrequencyHz, driveFit.rSquared);
if analysisReady
    fprintf('配对清单可用于隔离度分析：%s\n', pairManifestPath);
else
    fprintf('配对清单暂不可直接分析：%s\n', readinessNote);
end
end

function options = localOptions(options, config)
defaults = struct('drivenLabel', '', 'nominalFrequencyHz', NaN, ...
    'referencePlane', '', 'minimumDriveFitR2', config.minimumFitR2, ...
    'frequencySearchFraction', 0.01, 'channelMapping', []);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options, names{k}) || isempty(options.(names{k}))
        options.(names{k}) = defaults.(names{k});
    end
end
drivenLabel = string(options.drivenLabel);
referencePlane = string(options.referencePlane);
if ~isscalar(drivenLabel) || ismissing(drivenLabel)
    error('converter:dac:IsolationDrivenLabel', ...
        'options.drivenLabel必须是单个文本值。');
end
if ~isscalar(referencePlane) || ismissing(referencePlane)
    error('converter:dac:IsolationReferencePlane', ...
        'options.referencePlane必须是单个文本值。');
end
options.drivenLabel = char(strtrim(drivenLabel));
options.referencePlane = char(strtrim(referencePlane));
if ~isscalar(options.minimumDriveFitR2) || ...
        ~isfinite(options.minimumDriveFitR2) || ...
        options.minimumDriveFitR2 < 0 || options.minimumDriveFitR2 > 1
    error('converter:dac:IsolationFitThreshold', ...
        'minimumDriveFitR2必须是0到1之间的标量。');
end
if ~isscalar(options.frequencySearchFraction) || ...
        ~isfinite(options.frequencySearchFraction) || ...
        options.frequencySearchFraction <= 0 || ...
        options.frequencySearchFraction >= 0.5
    error('converter:dac:IsolationFrequencySearch', ...
        'frequencySearchFraction必须是0到0.5之间的标量。');
end
end

function [drivenLabel, nominalFrequencyHz] = localFolderConditions(dataFolder, options)
[~, folderName] = fileparts(char(dataFolder));
folderTokens = regexp(folderName, ...
    '(?i)^(JG\d+)[-_](\d+(?:\.\d+)?)([KMG]?)', 'tokens', 'once');

drivenLabel = upper(strtrim(char(options.drivenLabel)));
if isempty(drivenLabel)
    if isempty(folderTokens)
        error('converter:dac:IsolationFolderName', ...
            '目录名无法解析驱动接口；请设置options.drivenLabel。');
    end
    drivenLabel = upper(folderTokens{1});
end
if isempty(regexp(drivenLabel, '^JG\d+$', 'once'))
    error('converter:dac:IsolationDrivenLabel', ...
        '驱动接口必须采用JG加数字的格式：%s', drivenLabel);
end

nominalFrequencyHz = double(options.nominalFrequencyHz);
if ~isfinite(nominalFrequencyHz)
    if isempty(folderTokens)
        error('converter:dac:IsolationFolderFrequency', ...
            '目录名无法解析名义频率；请设置options.nominalFrequencyHz。');
    end
    nominalFrequencyHz = str2double(folderTokens{2}) * ...
        localFrequencyMultiplier(folderTokens{3});
end
if ~isscalar(nominalFrequencyHz) || ~isfinite(nominalFrequencyHz) || ...
        nominalFrequencyHz <= 0
    error('converter:dac:IsolationNominalFrequency', ...
        '名义频率必须是正的有限标量。');
end
end

function multiplier = localFrequencyMultiplier(prefix)
switch upper(char(prefix))
    case ''
        multiplier = 1;
    case 'K'
        multiplier = 1e3;
    case 'M'
        multiplier = 1e6;
    case 'G'
        multiplier = 1e9;
    otherwise
        error('converter:dac:IsolationFrequencyPrefix', ...
            '不支持的频率前缀：%s', char(prefix));
end
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
    outputData.SplitVersion = '0.1.0';
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

function [pairs, readinessNote] = localPairRows(channelRows, drivenLabel, ...
        nominalFrequencyHz, measuredFrequencyHz, driveFit, options, driveFitReady)
drivenMask = strcmpi(string(channelRows.channel_label), drivenLabel);
drivenRow = channelRows(drivenMask, :);
victimRows = channelRows(~drivenMask, :);
pairCount = height(victimRows);
if pairCount < 1
    error('converter:dac:IsolationVictimMissing', ...
        '至少需要一个与驱动接口不同的受扰通道。');
end
emptyPair = struct('driven_file', "", 'victim_file', "", ...
    'driven_variable', "A", 'victim_variable', "A", ...
    'frequency_hz', NaN, 'driven_label', "", 'victim_label', "", ...
    'reference_plane', "", 'nominal_frequency_hz', NaN, ...
    'frequency_offset_hz', NaN, 'driven_fit_r2', NaN, ...
    'driven_vpp_v', NaN, 'analysis_ready', false, 'readiness_note', "");
pairStructs = repmat(emptyPair, pairCount, 1);

notes = strings(0, 1);
if ~driveFitReady
    notes(end + 1) = sprintf('驱动拟合R^2 %.6f低于阈值%.6f', ...
        driveFit.rSquared, options.minimumDriveFitR2);
end
if strlength(string(options.referencePlane)) == 0
    notes(end + 1) = "待填写共同参考面和负载";
end
if isempty(notes), readinessNote = "可用于隔离度分析";
else, readinessNote = join(notes, '；'); end
ready = isempty(notes);

for k = 1:pairCount
    pairStructs(k).driven_file = string(drivenRow.output_file);
    pairStructs(k).victim_file = string(victimRows.output_file(k));
    pairStructs(k).frequency_hz = measuredFrequencyHz;
    pairStructs(k).driven_label = string(drivenLabel);
    pairStructs(k).victim_label = string(victimRows.channel_label(k));
    pairStructs(k).reference_plane = string(options.referencePlane);
    pairStructs(k).nominal_frequency_hz = nominalFrequencyHz;
    pairStructs(k).frequency_offset_hz = measuredFrequencyHz - nominalFrequencyHz;
    pairStructs(k).driven_fit_r2 = driveFit.rSquared;
    pairStructs(k).driven_vpp_v = driveFit.vppV;
    pairStructs(k).analysis_ready = ready;
    pairStructs(k).readiness_note = readinessNote;
end
pairs = struct2table(pairStructs);
end

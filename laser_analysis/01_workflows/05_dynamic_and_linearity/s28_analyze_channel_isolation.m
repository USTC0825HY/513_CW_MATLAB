function result = s28_analyze_channel_isolation(cfg)
%S28_ANALYZE_CHANNEL_ISOLATION DA compatibility adapter.
%   For DA captures CFG must provide dataFolder, pairManifest and optional
%   outputFolder/deviceId.  ADC isolation remains available through the
%   corresponding device entry in CW_513_ANALYSIS.

if nargin < 1 || ~isstruct(cfg)
    error('cw513:IsolationConfigRequired', '请提供隔离度配置结构体。');
end
workflowFolder = fileparts(mfilename('fullpath'));
laserAnalysisFolder = fileparts(fileparts(workflowFolder));
cwRoot = fullfile(fileparts(laserAnalysisFolder), '513DIANXING_analysis', ...
    'CW_analysis', 'CW_513_ANALYSIS');
if ~isfolder(cwRoot)
    error('cw513:LibraryMissing', ...
        '需要先添加 CW_513_ANALYSIS 分析库路径：%s', cwRoot);
end
addpath(fullfile(cwRoot, '_shared'));
deviceId = localField(cfg, 'deviceId', 'DA9726');
if strncmpi(char(deviceId), 'DA766', 5) || strcmpi(char(deviceId), '766')
    addpath(fullfile(cwRoot, '766_hy'));
else
    addpath(fullfile(cwRoot, '9726_hy'));
end
if isfield(cfg, 'pairManifest')
    pairManifest = cfg.pairManifest;
elseif isfield(cfg, 'manifestFile') && isfile(cfg.manifestFile)
    pairManifest = localLegacyManifest(readtable(cfg.manifestFile));
else
    error('cw513:IsolationManifestRequired', ...
        'DA隔离度必须明确提供 pairManifest 或 manifestFile。');
end
if ~isfield(cfg, 'dataFolder')
    cfg.dataFolder = localManifestFolder(pairManifest);
end
outputFolder = localField(cfg, 'outputFolder', localField(cfg, 'outputDir', ''));
result = dac_isolation_analysis(cfg.dataFolder, pairManifest, outputFolder, cfg);
result.details = result.summary;
end

function value = localField(structure, name, defaultValue)
if isfield(structure, name) && ~isempty(structure.(name))
    value = structure.(name);
else
    value = defaultValue;
end
end

function pairs = localLegacyManifest(manifest)
required = {'source_file', 'aggressor_channel', 'victim_channel', ...
    'stimulus_frequency_hz'};
for k = 1:numel(required)
    if ~ismember(required{k}, manifest.Properties.VariableNames)
        error('cw513:IsolationManifestRequired', ...
            '旧隔离清单缺少字段：%s', required{k});
    end
end
pairs = struct([]);
if ismember('case_id', manifest.Properties.VariableNames)
    keys = unique(manifest(:, {'case_id', 'aggressor_channel', ...
        'victim_channel'}), 'rows', 'stable');
else
    keys = table(1, manifest.aggressor_channel(1), ...
        manifest.victim_channel(1), 'VariableNames', ...
        {'case_id', 'aggressor_channel', 'victim_channel'});
end
for k = 1:height(keys)
    if ismember('case_id', manifest.Properties.VariableNames)
        groupMask = string(manifest.case_id) == string(keys.case_id(k)) & ...
            string(manifest.aggressor_channel) == string(keys.aggressor_channel(k)) & ...
            string(manifest.victim_channel) == string(keys.victim_channel(k));
    else
        groupMask = true(height(manifest), 1);
    end
    group = manifest(groupMask, :);
    if ismember('channel', group.Properties.VariableNames)
        driveMask = string(group.channel) == string(keys.aggressor_channel(k));
        victimMask = string(group.channel) == string(keys.victim_channel(k));
    else
        driveMask = true(height(group), 1); victimMask = driveMask;
        victimMask(1:min(1, height(group))) = false;
    end
    if nnz(driveMask) ~= 1 || nnz(victimMask) ~= 1
        continue;
    end
    driveRow = group(find(driveMask, 1), :);
    victimRow = group(find(victimMask, 1), :);
    row = struct();
    row.driven_file = char(string(driveRow.source_file));
    row.victim_file = char(string(victimRow.source_file));
    row.driven_variable = 'A'; row.victim_variable = 'A';
    row.frequency_hz = group.stimulus_frequency_hz(1);
    row.driven_label = char(string(keys.aggressor_channel(k)));
    row.victim_label = char(string(keys.victim_channel(k)));
    pairs = [pairs; row]; %#ok<AGROW>
end
end

function folder = localManifestFolder(pairs)
if isempty(pairs)
    folder = pwd;
    return;
end
folder = fileparts(char(pairs(1).driven_file));
if isempty(folder), folder = pwd; end
end

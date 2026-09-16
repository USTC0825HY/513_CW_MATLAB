function [config, cancelled] = prepareDacIsolation(config, dataFolder, pairs, outputFolder, overrides, defaultFolder)
%PREPAREDACISOLATION Select isolation captures or validate an explicit manifest.
config = converter.runtime.mergeConfig(config, overrides);
if isempty(dataFolder), dataFolder = config.dataFolder; end
if isempty(dataFolder), dataFolder = defaultFolder; end
if isempty(outputFolder), outputFolder = config.outputFolder; end
if isempty(pairs) && isfield(config, 'pairManifest'), pairs = config.pairManifest; end
cancelled = false;

if isempty(pairs)
    if localLogicalOption(config, 'simpleIsolationSelection', false)
        % Interactive isolation uses calibrated Pico voltage directly.
        % Unknown loading remains metadata and disables formal judgment.
        config.hardwareGain = 1;
        if localLogicalOption(config, 'autoDetectDrive', false)
            [selectedFiles, dataFolder] = converter.io.selectMatFiles( ...
                dataFolder, config.inputFiles, '选择全部单通道隔离度MAT');
            if isempty(selectedFiles), cancelled = true; return; end
            selectedPaths = localPaths(dataFolder, selectedFiles);
            [pairs, selectionDetails] = localAutomaticPairs(config, selectedPaths);
        else
            [drivenName, drivenFolder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
                '选择驱动输出MAT');
            if isequal(drivenName, 0), cancelled = true; return; end
            drivenPath = fullfile(drivenFolder, drivenName);
            [victimNames, victimFolder] = uigetfile(fullfile(drivenFolder, '*.mat'), ...
                '选择全部受干扰MAT', 'MultiSelect', 'on');
            if isequal(victimNames, 0), cancelled = true; return; end
            victimNames = cellstr(string(victimNames));
            victimPaths = cellfun(@(name) fullfile(victimFolder, name), ...
                victimNames, 'UniformOutput', false);
            dataFolder = drivenFolder;
            [pairs, selectionDetails] = localManualPairs(config, drivenPath, victimPaths);
        end
        config.isolationSelection = selectionDetails;
    else
        [pairs, dataFolder, config, cancelled] = localLegacySelection( ...
            config, dataFolder);
        if cancelled, return; end
    end
elseif ischar(pairs) || isstring(pairs)
    manifestPath = converter.io.resolveInputPath(dataFolder, pairs);
    if ~isfile(manifestPath)
        error('converter:io:InputFileNotFound', '配对清单不存在：%s', manifestPath);
    end
    pairs = table2struct(readtable(manifestPath));
elseif istable(pairs)
    pairs = table2struct(pairs);
end

required = {'driven_file','victim_file','driven_variable','victim_variable', ...
    'frequency_hz','driven_label','victim_label'};
if ~isstruct(pairs) || isempty(pairs) || ~all(isfield(pairs, required))
    error('converter:dac:IsolationManifestMissing', '隔离度清单缺少必需字段或为空。');
end
validateattributes(config.hardwareGain, {'numeric'}, ...
    {'scalar','real','finite','positive'});
for k = 1:numel(pairs)
    for j = [1:4 6:7]
        value = string(pairs(k).(required{j}));
        if ~isscalar(value) || ismissing(value) || strlength(strtrim(value)) == 0
            error('converter:dac:IsolationManifestMissing', ...
                '配对第%d行 %s 不能为空。', k, required{j});
        end
    end
    validateattributes(pairs(k).frequency_hz, {'numeric'}, ...
        {'scalar','real','finite','positive'});
    if isfield(pairs, 'reference_plane') && ...
            strlength(strtrim(string(pairs(k).reference_plane))) > 0
        reference = pairs(k).reference_plane;
    elseif isfield(overrides, 'referencePlane') && ...
            strlength(strtrim(string(overrides.referencePlane))) > 0
        reference = overrides.referencePlane;
    else
        error('converter:dac:ReferenceRequired', ...
            '请在配对 reference_plane 或第四参数 referencePlane 中明确共同参考面和负载。');
    end
    pairs(k).reference_plane = char(reference);
    pairs(k).driven_file = converter.io.resolveInputPath(dataFolder, pairs(k).driven_file);
    pairs(k).victim_file = converter.io.resolveInputPath(dataFolder, pairs(k).victim_file);
    converter.io.selectMatFiles(dataFolder, {pairs(k).driven_file}, '参考');
    converter.io.selectMatFiles(dataFolder, {pairs(k).victim_file}, '受扰');
    if strcmpi(pairs(k).driven_file, pairs(k).victim_file) && ...
            strcmpi(pairs(k).driven_variable, pairs(k).victim_variable)
        error('converter:dac:IdenticalPair', ...
            '参考与受扰不能是同一文件的同一波形变量。');
    end
end
config.dataFolder = char(dataFolder);
config.pairManifest = pairs;
config.outputFolder = converter.io.resolveOutputBase(dataFolder, outputFolder);
end

function [pairs, dataFolder, config, cancelled] = localLegacySelection(config, dataFolder)
cancelled = false;
[name, folder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
    '选择驱动输出的参考 MAT（一次一对）');
if isequal(name, 0), pairs = struct([]); cancelled = true; return; end
drivenPath = fullfile(folder, name);
dataFolder = folder;
[name, folder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
    '选择同一驱动条件的受扰 MAT');
if isequal(name, 0), pairs = struct([]); cancelled = true; return; end
victimPath = fullfile(folder, name);
values = inputdlg({'驱动接口','受扰接口','参考 MAT 波形变量', ...
    '受扰 MAT 波形变量','已确认驱动频率 / Hz','共同参考面和负载', ...
    '共同线性电压增益（未放大或已补偿填1）'}, ...
    '明确本次隔离度条件', 1, {'','','A','A','','','1'});
if isempty(values), pairs = struct([]); cancelled = true; return; end
pairs = struct('driven_file', drivenPath, 'victim_file', victimPath, ...
    'driven_label', values{1}, 'victim_label', values{2}, ...
    'driven_variable', values{3}, 'victim_variable', values{4}, ...
    'frequency_hz', str2double(values{5}), 'reference_plane', values{6});
config.referencePlane = values{6};
config.hardwareGain = str2double(values{7});
end

function [pairs, details] = localManualPairs(config, drivenPath, victimPaths)
allPaths = [{drivenPath}, victimPaths(:).'];
localValidateUniquePaths(allPaths);
descriptors = localDescriptors(allPaths, config.hardwareGain);
localValidateUniqueLabels(descriptors);
driven = descriptors(1);
tone = converter.dac.estimateToneFrequency( ...
    driven.capture.voltage, driven.capture.sampleRateHz);
localValidateDrivenFit(tone.fit, config.minimumFitR2);
nominalFrequencyHz = localNominalFrequency(driven.filePath);
pairs = localBuildPairs(driven, descriptors(2:end), tone.frequencyHz, ...
    nominalFrequencyHz, config.measurementCondition, tone.fit);
details = struct('mode', 'select_drive_then_victims', ...
    'drivenFile', driven.filePath, 'drivenLabel', driven.label, ...
    'victimCount', numel(victimPaths), ...
    'measuredFrequencyHz', tone.frequencyHz, ...
    'nominalFrequencyHz', nominalFrequencyHz, ...
    'driveFitR2', tone.fit.rSquared, 'driveVppV', tone.fit.vppV, ...
    'measurementCondition', config.measurementCondition);
fprintf('驱动接口：%s；受扰通道数：%d；实测频率：%.9g Hz；驱动R^2：%.6f\n', ...
    driven.label, numel(victimPaths), tone.frequencyHz, tone.fit.rSquared);
end

function [pairs, details] = localAutomaticPairs(config, selectedPaths)
if numel(selectedPaths) < 2
    error('converter:dac:IsolationVictimMissing', ...
        '自动识别至少需要两个单通道MAT。');
end
localValidateUniquePaths(selectedPaths);
descriptors = localDescriptors(selectedPaths, config.hardwareGain);
localValidateUniqueLabels(descriptors);

candidateVpp = NaN(numel(descriptors), 1);
candidateTones = cell(numel(descriptors), 1);
for k = 1:numel(descriptors)
    candidateTones{k} = converter.dac.estimateToneFrequency( ...
        descriptors(k).capture.voltage, descriptors(k).capture.sampleRateHz);
    candidateVpp(k) = candidateTones{k}.fit.vppV;
end
[~, candidateIndex] = max(candidateVpp);
commonFrequencyHz = candidateTones{candidateIndex}.frequencyHz;

commonFits = cell(numel(descriptors), 1);
commonVpp = NaN(numel(descriptors), 1);
for k = 1:numel(descriptors)
    commonFits{k} = converter.dac.fitTone(descriptors(k).capture.voltage, ...
        descriptors(k).capture.sampleRateHz, commonFrequencyHz);
    commonVpp(k) = commonFits{k}.vppV;
end
[sortedVpp, order] = sort(commonVpp, 'descend');
drivenIndex = order(1);
separationDb = 20 * log10(sortedVpp(1) / max(sortedVpp(2), realmin));
if separationDb < config.autoDriveMinimumSeparationDb
    error('converter:dac:IsolationDriveConfidence', ...
        ['自动识别的最大/次大同频幅值仅相差%.3f dB，小于%.3f dB。' ...
        '请改用先选驱动、再多选受扰。'], ...
        separationDb, config.autoDriveMinimumSeparationDb);
end
driveFit = commonFits{drivenIndex};
localValidateDrivenFit(driveFit, config.minimumFitR2);
driven = descriptors(drivenIndex);
victims = descriptors(setdiff(1:numel(descriptors), drivenIndex, 'stable'));
nominalFrequencyHz = localNominalFrequency(driven.filePath);
pairs = localBuildPairs(driven, victims, commonFrequencyHz, ...
    nominalFrequencyHz, config.measurementCondition, driveFit);
details = struct('mode', 'auto_detect', 'drivenFile', driven.filePath, ...
    'drivenLabel', driven.label, 'victimCount', numel(victims), ...
    'measuredFrequencyHz', commonFrequencyHz, ...
    'nominalFrequencyHz', nominalFrequencyHz, ...
    'driveFitR2', driveFit.rSquared, 'driveVppV', driveFit.vppV, ...
    'driveSeparationDb', separationDb, ...
    'measurementCondition', config.measurementCondition);
fprintf(['自动识别驱动接口：%s；同频最大/次大幅值差：%.3f dB；' ...
    '实测频率：%.9g Hz\n'], driven.label, separationDb, commonFrequencyHz);
end

function descriptors = localDescriptors(filePaths, hardwareGain)
emptyValue = struct('filePath', '', 'label', '', 'variableName', '', ...
    'capture', struct());
descriptors = repmat(emptyValue, numel(filePaths), 1);
for k = 1:numel(filePaths)
    filePath = char(java.io.File(char(filePaths{k})).getCanonicalPath());
    variables = who('-file', filePath);
    candidates = {'A', 'B', 'C', 'D'};
    present = candidates(ismember(candidates, variables));
    if numel(present) ~= 1
        error('converter:dac:IsolationNeedsSplit', ...
            ['隔离度交互模式要求每份MAT只含一路A/B/C/D波形：%s。' ...
            '请先运行split_dac_isolation_channels。'], filePath);
    end
    capture = converter.io.loadPicoMat(filePath, present{1}, hardwareGain, true);
    label = localChannelLabel(filePath, variables);
    descriptors(k) = struct('filePath', filePath, 'label', label, ...
        'variableName', present{1}, 'capture', capture);
end
end

function label = localChannelLabel(filePath, variables)
label = '';
if ismember('ChannelLabel', variables)
    metadata = load(filePath, 'ChannelLabel');
    value = string(metadata.ChannelLabel);
    if isscalar(value) && ~ismissing(value)
        label = upper(strtrim(char(value)));
    end
end
if isempty(label)
    [~, stem] = fileparts(filePath);
    token = regexp(stem, '(?i)^JG\d+', 'match', 'once');
    if ~isempty(token), label = upper(token); end
end
if isempty(label)
    error('converter:dac:IsolationChannelLabelMissing', ...
        '无法从MAT的ChannelLabel或文件名前缀识别接口：%s', filePath);
end
end

function pairs = localBuildPairs(driven, victims, frequencyHz, ...
        nominalFrequencyHz, referencePlane, driveFit)
if isempty(victims)
    error('converter:dac:IsolationVictimMissing', '至少需要一个受干扰MAT。');
end
if ~isfinite(nominalFrequencyHz), nominalFrequencyHz = frequencyHz; end
emptyPair = struct('driven_file', '', 'victim_file', '', ...
    'driven_variable', '', 'victim_variable', '', ...
    'frequency_hz', NaN, 'driven_label', '', 'victim_label', '', ...
    'reference_plane', '', 'nominal_frequency_hz', NaN, ...
    'frequency_offset_hz', NaN, 'driven_fit_r2', NaN, ...
    'driven_vpp_v', NaN);
pairs = repmat(emptyPair, numel(victims), 1);
for k = 1:numel(victims)
    pairs(k).driven_file = driven.filePath;
    pairs(k).victim_file = victims(k).filePath;
    pairs(k).driven_variable = driven.variableName;
    pairs(k).victim_variable = victims(k).variableName;
    pairs(k).frequency_hz = frequencyHz;
    pairs(k).driven_label = driven.label;
    pairs(k).victim_label = victims(k).label;
    pairs(k).reference_plane = referencePlane;
    pairs(k).nominal_frequency_hz = nominalFrequencyHz;
    pairs(k).frequency_offset_hz = frequencyHz - nominalFrequencyHz;
    pairs(k).driven_fit_r2 = driveFit.rSquared;
    pairs(k).driven_vpp_v = driveFit.vppV;
end
end

function nominalFrequencyHz = localNominalFrequency(filePath)
nominalFrequencyHz = NaN;
folder = fileparts(filePath);
for depth = 1:6
    [parent, folderName] = fileparts(folder);
    tokens = regexp(folderName, ...
        '(?i)^JG\d+[-_](\d+(?:\.\d+)?)([KMG]?)', 'tokens', 'once');
    if ~isempty(tokens)
        nominalFrequencyHz = str2double(tokens{1}) * ...
            localFrequencyMultiplier(tokens{2});
        return;
    end
    if strcmp(parent, folder), return; end
    folder = parent;
end
end

function multiplier = localFrequencyMultiplier(prefix)
switch upper(char(prefix))
    case '', multiplier = 1;
    case 'K', multiplier = 1e3;
    case 'M', multiplier = 1e6;
    case 'G', multiplier = 1e9;
    otherwise, multiplier = NaN;
end
end

function localValidateDrivenFit(fit, minimumFitR2)
if ~isfinite(fit.rSquared) || fit.rSquared < minimumFitR2
    error('converter:dac:IsolationDrivenFit', ...
        '驱动路拟合R^2为%.6f，低于阈值%.6f；请检查驱动MAT。', ...
        fit.rSquared, minimumFitR2);
end
end

function localValidateUniquePaths(filePaths)
canonical = strings(numel(filePaths), 1);
for k = 1:numel(filePaths)
    canonical(k) = string(java.io.File(char(filePaths{k})).getCanonicalPath());
end
if numel(unique(lower(canonical))) ~= numel(canonical)
    error('converter:dac:IsolationDuplicateFile', ...
        '驱动MAT和受干扰MAT不能重复选择。');
end
end

function localValidateUniqueLabels(descriptors)
labels = upper(string({descriptors.label}));
if numel(unique(labels)) ~= numel(labels)
    error('converter:dac:IsolationDuplicateLabel', ...
        '所选MAT包含重复接口标签，请检查切分文件。');
end
end

function paths = localPaths(dataFolder, files)
paths = cell(size(files));
for k = 1:numel(files)
    paths{k} = converter.io.resolveInputPath(dataFolder, files{k});
end
end

function value = localLogicalOption(config, fieldName, defaultValue)
if isfield(config, fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
if ~islogical(value) || ~isscalar(value)
    error('converter:dac:IsolationLogicalOption', ...
        '%s必须是单个logical值。', fieldName);
end
end

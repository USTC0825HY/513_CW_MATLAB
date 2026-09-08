function [config, cancelled] = prepareDacIsolation(config, dataFolder, pairs, outputFolder, overrides, defaultFolder)
%PREPAREDACISOLATION Select one explicit pair, or validate a supplied pair list.
config = converter.runtime.mergeConfig(config, overrides);
if isempty(dataFolder), dataFolder = config.dataFolder; end
if isempty(dataFolder), dataFolder = defaultFolder; end
if isempty(outputFolder), outputFolder = config.outputFolder; end
if isempty(pairs) && isfield(config, 'pairManifest'), pairs = config.pairManifest; end
cancelled = false;
if isempty(pairs)
    [name, folder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
        '选择驱动输出的参考 MAT（一次一对）');
    if isequal(name, 0), cancelled = true; return; end
    drivenPath = fullfile(folder, name);
    dataFolder = folder;
    [name, folder] = uigetfile(fullfile(dataFolder, '*.mat'), '选择同一驱动条件的受扰 MAT');
    if isequal(name, 0), cancelled = true; return; end
    victimPath = fullfile(folder, name);
    values = inputdlg({'驱动接口','受扰接口','参考 MAT 波形变量', ...
        '受扰 MAT 波形变量','已确认驱动频率 / Hz','共同参考面和负载', ...
        '共同线性电压增益（未放大或已补偿填1）'}, ...
        '明确本次隔离度条件', 1, {'','','A','A','','','1'});
    if isempty(values), cancelled = true; return; end
    pairs = struct('driven_file', drivenPath, 'victim_file', victimPath, ...
        'driven_label', values{1}, 'victim_label', values{2}, ...
        'driven_variable', values{3}, 'victim_variable', values{4}, ...
        'frequency_hz', str2double(values{5}), 'reference_plane', values{6});
    config.referencePlane = values{6};
    config.hardwareGain = str2double(values{7});
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
validateattributes(config.hardwareGain, {'numeric'}, {'scalar','real','finite','positive'});
for k = 1:numel(pairs)
    for j = [1:4 6:7]
        value = string(pairs(k).(required{j}));
        if ~isscalar(value) || ismissing(value) || strlength(strtrim(value)) == 0
            error('converter:dac:IsolationManifestMissing', '配对第%d行 %s 不能为空。', k, required{j});
        end
    end
    validateattributes(pairs(k).frequency_hz, {'numeric'}, {'scalar','real','finite','positive'});
    if isfield(pairs, 'reference_plane') && strlength(strtrim(string(pairs(k).reference_plane))) > 0
        reference = pairs(k).reference_plane;
    elseif isfield(overrides, 'referencePlane') && strlength(strtrim(string(overrides.referencePlane))) > 0
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
        error('converter:dac:IdenticalPair', '参考与受扰不能是同一文件的同一波形变量。');
    end
end
config.dataFolder = char(dataFolder);
config.pairManifest = pairs;
config.outputFolder = converter.io.resolveOutputBase(dataFolder, outputFolder);
end

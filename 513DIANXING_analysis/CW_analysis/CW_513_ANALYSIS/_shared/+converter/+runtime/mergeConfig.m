function config = mergeConfig(config, override)
%MERGECONFIG Apply an explicit caller override to a device configuration.
%   Unknown fields are retained as traceability metadata; the device entry
%   remains responsible for defining all algorithmic defaults.
if nargin < 2 || isempty(override)
    return;
end
if ~isstruct(override) || ~isscalar(override)
    error('converter:runtime:InvalidOverride', '配置覆盖必须是标量结构体。');
end
names = fieldnames(override);
for k = 1:numel(names)
    name = names{k};
    target = name;
    if strcmpi(name, 'dataDir'), target = 'dataFolder'; end
    if strcmpi(name, 'outputDir'), target = 'outputFolder'; end
    if strcmpi(name, 'inputFileNames'), target = 'inputFiles'; end
    if strcmpi(name, 'variables'), target = 'dataVariables'; end
    config.(target) = override.(name);
end
end

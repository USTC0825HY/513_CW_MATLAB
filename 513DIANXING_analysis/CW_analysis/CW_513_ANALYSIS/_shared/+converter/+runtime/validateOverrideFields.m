function validateOverrideFields(defaults, override, extraNames)
%VALIDATEOVERRIDEFIELDS Reject misspelled parameters before file selection.
% With EXTRANAMES, restrict options to defaults and explicitly accepted names.
if isempty(override), return; end
if ~isstruct(override) || ~isscalar(override)
    error('converter:runtime:InvalidOverride', '配置覆盖必须是标量结构体。');
end
if nargin < 3
    extraNames = converter.runtime.knownConfigFields();
end
allowed = unique([fieldnames(defaults); extraNames(:); {'metadata'}]);
aliases = {'dataDir','outputDir','inputFileNames','variables'};
targets = {'dataFolder','outputFolder','inputFiles','dataVariables'};
names = fieldnames(override);
for k = 1:numel(names)
    name = names{k};
    index = find(strcmpi(name, aliases), 1);
    if ~isempty(index), name = targets{index}; end
    if ~ismember(name, allowed)
        distances = cellfun(@(candidate) editDistance(lower(name), lower(candidate)), allowed);
        [~, closest] = min(distances);
        error('converter:runtime:UnknownConfigField', ...
            '未知配置字段 %s。是否要设置 %s？自定义说明请放入metadata。', names{k}, allowed{closest});
    end
end
end

function distance = editDistance(left, right)
previous = 0:numel(right);
for i = 1:numel(left)
    current = zeros(1, numel(right)+1); current(1) = i;
    for j = 1:numel(right)
        current(j+1) = min([current(j)+1, previous(j+1)+1, ...
            previous(j)+(left(i) ~= right(j))]);
    end
    previous = current;
end
distance = previous(end);
end

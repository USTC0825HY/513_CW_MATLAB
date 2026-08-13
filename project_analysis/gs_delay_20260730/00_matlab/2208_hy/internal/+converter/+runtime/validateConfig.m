function validateConfig(config, requiredFields)
%VALIDATECONFIG Validate a complete device-specific configuration.

if ~isstruct(config) || ~isscalar(config)
    error('converter:runtime:InvalidConfig', '器件配置必须是标量结构体。');
end
for fieldIndex = 1:numel(requiredFields)
    fieldName = requiredFields{fieldIndex};
    if ~isfield(config, fieldName) || isempty(config.(fieldName))
        error('converter:runtime:MissingConfig', ...
            '器件配置缺少必填字段：%s', fieldName);
    end
end
end


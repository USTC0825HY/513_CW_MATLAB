function textValue = valueToText(value)
%VALUETOTEXT Serialize configuration values for an auditable parameter CSV.
if ischar(value)
    textValue = value;
elseif isstring(value)
    textValue = char(strjoin(value(:).', ', '));
elseif isnumeric(value)
    textValue = mat2str(value);
elseif islogical(value)
    textValue = mat2str(value);
elseif iscell(value)
    parts = cellfun(@converter.runtime.valueToText, value, ...
        'UniformOutput', false);
    textValue = ['{' strjoin(parts, ', ') '}'];
elseif istable(value)
    textValue = sprintf('[table %dx%d]', height(value), width(value));
elseif isstruct(value)
    textValue = sprintf('[struct %dx%d]', size(value, 1), size(value, 2));
else
    textValue = ['[' class(value) ']'];
end
end

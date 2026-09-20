function value = refreshResultPaths(value, runFolder)
%REFRESHRESULTPATHS Update stored output paths after evidence is organized.
if istable(value)
    names = value.Properties.VariableNames;
    for k = 1:numel(names)
        value.(names{k}) = converter.runtime.refreshResultPaths(value.(names{k}), runFolder);
    end
elseif isstruct(value)
    names = fieldnames(value);
    for i = 1:numel(value)
        for k = 1:numel(names)
            value(i).(names{k}) = converter.runtime.refreshResultPaths(value(i).(names{k}), runFolder);
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        value{k} = converter.runtime.refreshResultPaths(value{k}, runFolder);
    end
elseif isstring(value)
    for k = 1:numel(value)
        if ~ismissing(value(k))
            value(k) = string(resolve(char(value(k)), runFolder));
        end
    end
elseif ischar(value) && isrow(value)
    value = resolve(value, runFolder);
end
end

function value = resolve(value, runFolder)
[parent, name, extension] = fileparts(value);
if strcmpi(strrep(parent, '\', '/'), strrep(runFolder, '\', '/'))
    moved = fullfile(runFolder, 'evidence', [name extension]);
    if isfile(moved), value = moved; end
end
end

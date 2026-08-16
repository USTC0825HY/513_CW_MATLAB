function writeTable(dataTable, filePath)
%WRITETABLE Write a table with a simple MATLAB R2018 fallback.

try
    writetable(dataTable, filePath);
    return;
catch writeError
    fileId = fopen(filePath, 'w');
    if fileId < 0
        rethrow(writeError);
    end
end
cleanupObject = onCleanup(@() fclose(fileId));
for columnIndex = 1:width(dataTable)
    if columnIndex > 1
        fprintf(fileId, ',');
    end
    fprintf(fileId, '%s', dataTable.Properties.VariableNames{columnIndex});
end
fprintf(fileId, '\n');
for rowIndex = 1:height(dataTable)
    for columnIndex = 1:width(dataTable)
        if columnIndex > 1
            fprintf(fileId, ',');
        end
        value = dataTable{rowIndex, columnIndex};
        if iscell(value)
            value = value{1};
        end
        writeCsvValue(fileId, value);
    end
    fprintf(fileId, '\n');
end
end

function writeCsvValue(fileId, value)
if ischar(value) || isstring(value)
    textValue = char(string(value));
    fprintf(fileId, '"%s"', strrep(textValue, '"', '""'));
elseif islogical(value)
    fprintf(fileId, '%d', value);
elseif isnumeric(value)
    fprintf(fileId, '%.12g', value);
else
    fprintf(fileId, '"%s"', char(string(value)));
end
end

function writeTable(dataTable, filePath)
%WRITETABLE Write a table with a simple MATLAB R2018 fallback.

try
    writetable(dataTable, filePath);
    if localContainsText(dataTable)
        localPrependUtf8Bom(filePath);
    end
    return;
catch writeError
    fileId = fopen(filePath, 'w', 'n', 'UTF-8');
    if fileId < 0
        rethrow(writeError);
    end
end
cleanupObject = onCleanup(@() fclose(fileId));
if localContainsText(dataTable)
    fwrite(fileId, uint8([239, 187, 191]), 'uint8');
end
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

function yes = localContainsText(dataTable)
yes = false;
for columnIndex = 1:width(dataTable)
    value = dataTable.(dataTable.Properties.VariableNames{columnIndex});
    if ischar(value) || isstring(value) || iscell(value) || iscategorical(value)
        yes = true;
        return;
    end
end
end

function localPrependUtf8Bom(filePath)
fileId = fopen(filePath, 'rb');
if fileId < 0
    error('converter:report:CsvReadFailed', '无法读取刚生成的CSV：%s', filePath);
end
cleanupRead = onCleanup(@() fclose(fileId));
bytes = fread(fileId, Inf, '*uint8');
if numel(bytes) >= 3 && isequal(bytes(1:3).', uint8([239, 187, 191]))
    return;
end
clear cleanupRead;

fileId = fopen(filePath, 'wb');
if fileId < 0
    error('converter:report:CsvWriteFailed', '无法写入UTF-8 CSV：%s', filePath);
end
cleanupWrite = onCleanup(@() fclose(fileId));
fwrite(fileId, uint8([239, 187, 191]), 'uint8');
fwrite(fileId, bytes, 'uint8');
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

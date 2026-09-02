function adcCode = readAdcCsv(filePath, config)
%READADCCSV Read and normalize one ADC-code column from an ILA CSV file.

requiredFields = {'adcDataColumn', 'adcBits', 'adcCodeFormat'};
converter.runtime.validateConfig(config, requiredFields);
numericData = readNumericCsv(filePath, config.adcDataColumn);
if isempty(numericData)
    error('converter:io:NoNumericData', 'CSV 中没有数值数据：%s', filePath);
end

dataColumn = config.adcDataColumn;
if dataColumn == 0
    dataColumn = size(numericData, 2);
end
if dataColumn < 1 || dataColumn > size(numericData, 2)
    error('converter:io:ColumnOutOfRange', ...
        'ADC 数据列 %d 超出 CSV 列范围：%s', dataColumn, filePath);
end

adcCode = double(numericData(:, dataColumn));
adcCode = adcCode(isfinite(adcCode));
if isempty(adcCode)
    error('converter:io:NoAdcSamples', 'ADC 数据列没有有限数值：%s', filePath);
end

fullScalePeak = 2^(config.adcBits - 1);
% Some Vivado exports store the ADC word as an unprefixed hexadecimal
% token (for example, ``f31f``) rather than a signed decimal value.  The
% text reader below returns those words as unsigned integers; normalize
% them to the configured signed two's-complement range before analysis.
if strcmpi(config.adcCodeFormat, 'signed')
    adcCode(adcCode >= fullScalePeak) = ...
        adcCode(adcCode >= fullScalePeak) - 2 * fullScalePeak;
end
if strcmpi(config.adcCodeFormat, 'unsigned')
    adcCode = adcCode - fullScalePeak;
elseif ~strcmpi(config.adcCodeFormat, 'signed')
    error('converter:io:InvalidCodeFormat', ...
        'adcCodeFormat 只能是 signed 或 unsigned。');
end
if any(adcCode < -fullScalePeak | adcCode > fullScalePeak - 1)
    warning('converter:io:CodeOutOfRange', ...
        '文件 %s 的码值超出 %d 位 ADC 范围。', filePath, config.adcBits);
end
end

function numericData = readNumericCsv(filePath, dataColumn)
fileInfo = dir(filePath);
if isempty(fileInfo)
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
if fileInfo.bytes == 0
    error('converter:io:NoNumericData', 'CSV 文件为空：%s', filePath);
end
headerRowCount = countCsvHeaderRows(filePath);
try
    numericData = dlmread(filePath, ',', headerRowCount, 0); %#ok<DLMRD>
catch readError
    % dlmread cannot consume hexadecimal ADC words.  Fall back to a small,
    % dependency-free CSV parser which accepts decimal and hexadecimal
    % fields while preserving the original column layout.
    try
        numericData = readTextNumericCsv(filePath, headerRowCount, dataColumn);
    catch fallbackError
        error('converter:io:NonNumericData', ...
            'CSV 数值区包含文字或列数不一致：%s\n%s\n%s', ...
            filePath, readError.message, fallbackError.message);
    end
end
end

function headerRowCount = countCsvHeaderRows(filePath)
fileId = fopen(filePath, 'r');
if fileId < 0
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
cleanupObject = onCleanup(@() fclose(fileId));
if isempty(cleanupObject)
    error('converter:io:CleanupInitFailed', '无法建立 CSV 文件清理器。');
end
headerRowCount = 0;
while true
    currentLine = fgetl(fileId);
    if ~ischar(currentLine)
        break;
    end
    fields = strsplit(strtrim(currentLine), ',');
    if isNumericCsvLine(fields)
        break;
    end
    headerRowCount = headerRowCount + 1;
end
end

function numericData = readTextNumericCsv(filePath, headerRowCount, dataColumn)
% Use textscan so the 131072-sample capture is parsed in compiled chunks
% instead of invoking strsplit/regexp once per field.
fileId = fopen(filePath, 'r');
if fileId < 0
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
cleanupObject = onCleanup(@() fclose(fileId));
if isempty(cleanupObject)
    error('converter:io:CleanupInitFailed', '无法建立 CSV 文件清理器。');
end
for rowIndex = 1:headerRowCount
    if ~ischar(fgetl(fileId))
        error('converter:io:NoNumericData', 'CSV 文件没有数值数据：%s', filePath);
    end
end
firstDataLine = fgetl(fileId);
if ~ischar(firstDataLine)
    numericData = zeros(0, 0);
    return;
end
firstFields = strsplit(strtrim(firstDataLine), ',');
columnCount = numel(firstFields);
frewind(fileId);
formatSpec = repmat('%s', 1, columnCount);
tokens = textscan(fileId, formatSpec, 'Delimiter', ',', ...
    'HeaderLines', headerRowCount, 'ReturnOnError', false, ...
    'CollectOutput', false);
rowCount = numel(tokens{1});
if rowCount == 0
    numericData = zeros(0, columnCount);
    return;
end
numericData = NaN(rowCount, columnCount);
if dataColumn == 0
    dataColumn = columnCount;
end
for columnIndex = 1:columnCount
    columnTokens = tokens{columnIndex};
    % When the selected ADC column caused dlmread to fail, interpret the
    % entire selected column as hexadecimal words.  This matters for tokens
    % containing only digits (e.g. ``8000``), which are valid hex but would
    % otherwise be mistaken for decimal 8000.
    if columnIndex == dataColumn
        try
            values = hex2dec(columnTokens);
        catch
            values = str2double(columnTokens);
        end
    else
        values = str2double(columnTokens);
    end
    hexIndices = find(isnan(values));
    if ~isempty(hexIndices)
        try
            values(hexIndices) = hex2dec(columnTokens(hexIndices));
        catch
            error('converter:io:NonNumericData', ...
                'CSV 数值区包含无法解析的十六进制字段。');
        end
    end
    numericData(:, columnIndex) = values;
end
end

function tf = isNumericCsvLine(fields)
tf = true;
for fieldIndex = 1:numel(fields)
    token = strtrim(fields{fieldIndex});
    if isempty(token)
        tf = false;
        return;
    end
    value = str2double(token);
    if isnan(value) && isempty(regexp(token, '^[0-9A-Fa-f]+$', 'once'))
        tf = false;
        return;
    end
end
end

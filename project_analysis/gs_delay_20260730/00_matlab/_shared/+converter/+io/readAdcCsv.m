function adcCode = readAdcCsv(filePath, config)
%READADCCSV Read and normalize one ADC-code column from an ILA CSV file.

requiredFields = {'adcDataColumn', 'adcBits', 'adcCodeFormat'};
converter.runtime.validateConfig(config, requiredFields);
numericData = readNumericCsv(filePath);
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

function numericData = readNumericCsv(filePath)
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
    error('converter:io:NonNumericData', ...
        'CSV 数值区包含文字或列数不一致：%s\n%s', ...
        filePath, readError.message);
end
end

function headerRowCount = countCsvHeaderRows(filePath)
fileId = fopen(filePath, 'r');
if fileId < 0
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
cleanupObject = onCleanup(@() fclose(fileId));
headerRowCount = 0;
while true
    currentLine = fgetl(fileId);
    if ~ischar(currentLine)
        break;
    end
    fields = strsplit(strtrim(currentLine), ',');
    values = cellfun(@str2double, fields);
    if all(~isnan(values))
        break;
    end
    headerRowCount = headerRowCount + 1;
end
end

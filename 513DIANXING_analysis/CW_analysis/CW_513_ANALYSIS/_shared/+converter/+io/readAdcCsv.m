function [adcCode, metadata] = readAdcCsv(filePath, config)
%READADCCSV Read ADC words with explicit radix; never discard bad samples.
% INPUTRADIX: auto/hex/decimal. ALLOWRADIXPROMPT: interactive entries only.
converter.runtime.validateConfig(config, {'adcDataColumn','adcBits','adcCodeFormat'});
validateattributes(config.adcBits, {'numeric'}, {'scalar','integer','>=',1,'<=',32});
[headerRows, fields, headers] = inspectHeader(filePath);
columnCount = numel(fields);
column = config.adcDataColumn;
if column == 0, column = columnCount; end
if ~isscalar(column) || column ~= fix(column) || column < 1 || column > columnCount
    error('converter:io:ColumnOutOfRange', 'ADC数据列超出CSV列范围：%s', filePath);
end
filterValid = isfield(config,'filterValidStrobe') && config.filterValidStrobe;
keepColumns = column;
if filterValid
    if ~isfield(config,'validDataColumn') || ~isscalar(config.validDataColumn) || ...
            config.validDataColumn ~= fix(config.validDataColumn) || ...
            config.validDataColumn < 1 || config.validDataColumn > columnCount
        error('converter:io:ValidColumnOutOfRange','有效标志列超出CSV列范围。');
    end
    keepColumns = unique([column config.validDataColumn]);
end
% Keep selective-column textscan and vectorized conversion from the
% existing performance fix; unrelated bus columns are not converted.
format = repmat({'%*s'},1,columnCount);
format(keepColumns) = {'%s'};
fid = fopen(filePath,'r');
if fid < 0, error('converter:io:CannotOpenCsv','无法打开CSV：%s',filePath); end
cleanup = onCleanup(@() fclose(fid));
tokens = textscan(fid,[format{:}],'Delimiter',',','HeaderLines',headerRows, ...
    'ReturnOnError',false,'Whitespace',' \b\t','EndOfLine','\n','CollectOutput',false);
adcTokens = strtrim(tokens{find(keepColumns == column,1)});
if isempty(adcTokens), error('converter:io:NoNumericData','CSV没有数据行：%s',filePath); end
[radix,source] = converter.io.resolveAdcInputRadix(adcTokens,headers,column,config,filePath);
adcCode = parseTokens(adcTokens,radix,filePath);
sourceCount = numel(adcCode);
peak = 2^(config.adcBits-1);
if strcmpi(config.adcCodeFormat,'signed')
    if strcmp(radix,'hex')
        conversionRule = 'raw >= 2^(bits-1): code = raw - 2^bits; otherwise code = raw';
        if any(adcCode < 0 | adcCode >= 2*peak), rangeError(filePath); end
        adcCode(adcCode >= peak) = adcCode(adcCode >= peak)-2*peak;
    elseif any(adcCode < -peak | adcCode >= peak)
        rangeError(filePath);
    else
        conversionRule = 'signed decimal code retained without remapping';
    end
elseif strcmpi(config.adcCodeFormat,'unsigned')
    conversionRule = 'analysis code = unsigned raw - 2^(bits-1)';
    if any(adcCode < 0 | adcCode >= 2*peak), rangeError(filePath); end
    adcCode = adcCode-peak;
else
    error('converter:io:InvalidCodeFormat','adcCodeFormat只能是signed或unsigned。');
end
if filterValid
    valid = parseTokens(strtrim(tokens{find(keepColumns == config.validDataColumn,1)}), ...
        'decimal',filePath);
    if numel(valid) ~= sourceCount || any(valid ~= 0 & valid ~= 1)
        error('converter:io:InvalidValidStrobe','有效标志列必须逐行对应且仅包含0/1。');
    end
    adcCode = adcCode(valid == 1);
    if isempty(adcCode), error('converter:io:NoValidStrobeSamples','有效标志列没有为1的数据行。'); end
end
metadata = struct('filePath',char(filePath),'inputRadix',radix, ...
    'inputRadixSource',source,'adcDataColumn',column,'adcBits',config.adcBits, ...
    'conversionRule',conversionRule, ...
    'adcCodeFormat',config.adcCodeFormat,'sourceSampleCount',sourceCount, ...
    'retainedSampleCount',numel(adcCode));
end

function values = parseTokens(tokens,radix,filePath)
if any(cellfun('isempty',tokens))
    error('converter:io:NonNumericData','CSV所选列存在缺失值：%s',filePath);
end
joined = strjoin(tokens,' ');
if strcmp(radix,'hex')
    pattern = '^(?:(?:0[xX])?[0-9A-Fa-f]+)(?: (?:0[xX])?[0-9A-Fa-f]+)*$';
    if isempty(regexp(joined,pattern,'once'))
        error('converter:io:NonNumericData','CSV所选列不是合法十六进制整数：%s',filePath);
    end
    values = hex2dec(regexprep(tokens,'^0[xX]',''));
else
    number = '[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?';
    if isempty(regexp(joined,['^' number '(?: ' number ')*$'],'once'))
        error('converter:io:NonNumericData','CSV所选列不是有限十进制数：%s',filePath);
    end
    values = sscanf(joined,'%f');
end
if numel(values) ~= numel(tokens) || any(~isfinite(values) | values ~= fix(values))
    error('converter:io:NonNumericData','ADC码必须是有限整数，不能丢弃非法样点：%s',filePath);
end
values = double(values(:));
end

function rangeError(filePath)
error('converter:io:CodeOutOfRange','ADC码超出所配置位宽/码制范围：%s',filePath);
end

function [count,fields,headers] = inspectHeader(filePath)
fid = fopen(filePath,'r');
if fid < 0, error('converter:io:CannotOpenCsv','无法打开CSV：%s',filePath); end
cleanup = onCleanup(@() fclose(fid));
count = 0; headers = {}; hasColumnHeader = false;
while true
    line = fgetl(fid);
    if ~ischar(line), error('converter:io:NoNumericData','CSV为空或没有数据区：%s',filePath); end
    candidate = strtrim(strsplit(line,',','CollapseDelimiters',false));
    % Vivado first column is the sample index. A malformed selected ADC
    % token in that first data row must not be skipped as another header.
    firstNumeric = ~isempty(regexp(candidate{1}, ...
        '^(?:[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|0[xX][0-9a-fA-F]+|[0-9a-fA-F]+)$','once'));
    declaration = ~isempty(regexpi(line, ...
        'radix|^\s*(?:hex(?:adecimal)?|decimal|signed|unsigned)(?:\s*,|\s*$)','once'));
    if firstNumeric && ~declaration
        fields = candidate; return;
    end
    if ~isempty(strtrim(line)) && ~declaration
        if hasColumnHeader
            fields = candidate; return;
        end
        hasColumnHeader = true;
    end
    headers{end+1} = line; %#ok<AGROW>
    count = count+1;
end
end

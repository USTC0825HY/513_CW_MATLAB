function [radix,source] = resolveAdcInputRadix(tokens,headers,column,config,filePath)
%RESOLVEADCINPUTRADIX Resolve representation without guessing numeric tokens.
radix = 'auto';
if isfield(config,'inputRadix') && ~isempty(config.inputRadix)
    radix = lower(char(config.inputRadix));
end
if ~ismember(radix,{'auto','hex','decimal'})
    error('converter:io:InvalidInputRadix','inputRadix只能是auto、hex或decimal。');
end
source = 'explicit_config';
if ~strcmp(radix,'auto'), return; end
if isfield(config,'inputRadixByFile') && ~isempty(config.inputRadixByFile)
    sourcePath = char(java.io.File(char(filePath)).getCanonicalPath());
    for k = 1:numel(config.inputRadixByFile)
        item = config.inputRadixByFile(k);
        mappedPath = char(java.io.File(char(item.filePath)).getCanonicalPath());
        if strcmpi(sourcePath,mappedPath)
            radix = item.inputRadix; source = item.inputRadixSource; return;
        end
    end
end
declared = {};
for k = 1:numel(headers)
    line = headers{k};
    match = regexpi(line,'(?:inputRadix|radix)\s*[:=]\s*(hexadecimal|hex|decimal)','tokens');
    for n = 1:numel(match), declared{end+1} = match{n}{1}; end %#ok<AGROW>
    fields = strtrim(strsplit(line,',','CollapseDelimiters',false));
    if column <= numel(fields)
        token = lower(fields{column});
        if ismember(token,{'hex','hexadecimal','decimal','signed decimal','unsigned decimal'})
            if contains(token,'decimal'), token = 'decimal'; else, token = 'hex'; end
            declared{end+1} = token; %#ok<AGROW>
        end
    end
end
declared = regexprep(lower(string(declared)),'^hexadecimal$','hex');
if numel(unique(declared)) > 1
    error('converter:io:ConflictingInputRadix','CSV进制声明相互冲突：%s',filePath);
elseif ~isempty(declared)
    radix = char(declared(1)); source = 'csv_declaration'; return;
end
joined = strjoin(tokens,' ');
candidate = '(?:[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|(?:0[xX])?[0-9A-Fa-f]+)';
if any(cellfun('isempty',tokens)) || ...
        isempty(regexp(joined,['^' candidate '(?: ' candidate ')*$'],'once'))
    error('converter:io:NonNumericData','CSV所选列存在缺失或非法数值：%s',filePath);
end
if ~isempty(regexp(joined,'(?:^| )0[xX]','once'))
    radix = 'hex'; source = '0x_prefix'; return;
end
decimal = '[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?';
if ~isempty(regexp(joined,'(?:^| )-','once')) && ...
        ~isempty(regexp(joined,['^' decimal '(?: ' decimal ')*$'],'once'))
    radix = 'decimal'; source = 'signed_decimal_tokens'; return;
end
if isfield(config,'allowRadixPrompt') && config.allowRadixPrompt
    [choice,ok] = listdlg('PromptString', ...
        {sprintf('文件：%s；ADC第%d列',filePath,column), ...
        '请按ILA导出设置选择进制；不能根据无前缀码值猜测。'}, ...
        'SelectionMode','single','ListString',{'十进制 decimal','十六进制 hex'});
    if ~ok, error('converter:io:InputRadixCancelled','已取消进制选择。'); end
    options = {'decimal','hex'}; radix = options{choice}; source = 'user_selection';
else
    error('converter:io:AmbiguousInputRadix', ...
        ['CSV未声明进制，不能猜测：%s。请显式设置inputRadix=''hex''' ...
        '或inputRadix=''decimal''（按实际导出设置）。'],filePath);
end
end

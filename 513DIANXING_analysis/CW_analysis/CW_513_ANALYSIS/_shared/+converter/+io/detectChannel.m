function channelName = detectChannel(filePath, fileName, dataFolder, config)
%DETECTCHANNEL Detect an ADC channel from name, header, then directory.

channelName = converter.io.extractChannel(fileName, config);
fileId = fopen(filePath, 'r');
if fileId < 0
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
cleanup = onCleanup(@() fclose(fileId));
header = '';
if isfield(config, 'headerModulePattern')
    % Match the configured ADC data column, not the first matching module
    % anywhere in a multi-channel Vivado header.  This is essential for an
    % AD677 capture containing adc1_data in column 4 and adc2_data in 12.
    for lineIndex = 1:50
        line = fgetl(fileId);
        if ~ischar(line), break; end
        fields = strtrim(strsplit(line, ',', 'CollapseDelimiters', false));
        if isfield(config, 'adcDataColumn') && ~isempty(config.adcDataColumn)
            column = config.adcDataColumn;
            if column == 0, column = numel(fields); end
            if column >= 1 && column <= numel(fields)
                candidate = fields{column};
            else
                candidate = '';
            end
        else
            candidate = line;
        end
        if ~isempty(regexp(candidate, config.headerModulePattern, 'once'))
            header = candidate;
            break;
        end
    end
end
if ~isempty(header) && isfield(config, 'headerModulePattern')
    token = regexp(header, config.headerModulePattern, 'tokens', 'once');
    if ~isempty(token)
        moduleIndex = str2double(token{1});
        if isfinite(moduleIndex) && moduleIndex >= 0
            mapIndex = moduleIndex + 1;
            if isfield(config, 'moduleChannelMap') && ...
                    mapIndex <= numel(config.moduleChannelMap)
                mappedName = config.moduleChannelMap{mapIndex};
                if ~isempty(mappedName)
                    channelName = char(mappedName);
                    return;
                end
            end
            if moduleIndex <= 3
                channelName = sprintf('X%dG', mapIndex);
                return;
            end
        end
    end
end
if isempty(channelName)
    channelName = converter.io.extractChannel(dataFolder, config);
end
end


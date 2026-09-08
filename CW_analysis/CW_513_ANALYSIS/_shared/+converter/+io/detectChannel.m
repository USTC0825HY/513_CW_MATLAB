function channelName = detectChannel(filePath, fileName, dataFolder, config)
%DETECTCHANNEL Detect an ADC channel from name, header, then directory.

channelName = converter.io.extractChannel(fileName, config);
fileId = fopen(filePath, 'r');
if fileId < 0
    error('converter:io:CannotOpenCsv', '无法打开 CSV：%s', filePath);
end
header = fgetl(fileId);
fclose(fileId);
if ischar(header) && isfield(config, 'headerModulePattern')
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


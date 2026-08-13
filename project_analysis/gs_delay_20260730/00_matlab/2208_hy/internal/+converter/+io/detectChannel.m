function channelName = detectChannel(filePath, fileName, dataFolder, config)
%DETECTCHANNEL Detect an ADC channel from name, header, then directory.

channelName = converter.io.extractChannel(fileName);
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
        if isfinite(moduleIndex) && moduleIndex >= 0 && moduleIndex <= 7
            adcIndex = moduleIndex + 1;
            knownAdc = [1 2 3 5 6];
            knownJg = [15 17 19 22 24];
            mappingIndex = find(knownAdc == adcIndex, 1);
            if isempty(mappingIndex)
                channelName = sprintf('ADC%d', adcIndex);
            else
                channelName = sprintf('ADC%d_JG%d', ...
                    adcIndex, knownJg(mappingIndex));
            end
            return;
        end
    end
end
if isempty(channelName)
    channelName = converter.io.extractChannel(dataFolder);
end
end


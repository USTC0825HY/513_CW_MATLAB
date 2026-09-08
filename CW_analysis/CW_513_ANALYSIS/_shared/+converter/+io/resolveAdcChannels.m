function channels = resolveAdcChannels(config, dataFolder, files, interactive)
%RESOLVEADCCHANNELS Use declared channels or acquisition headers, never filenames.
if nargin < 4, interactive = false; end
channels = strings(numel(files), 1);
if isfield(config, 'inputChannels') && ~isempty(config.inputChannels)
    channels = string(config.inputChannels(:));
    if numel(channels) ~= numel(files)
        error('converter:io:ChannelCountMismatch', 'inputChannels 须与所选文件逐一对应。');
    end
end
for k = 1:numel(files)
    filePath = converter.io.resolveInputPath(dataFolder, files{k});
    headerChannel = converter.io.detectChannel(filePath, '', '', config);
    if strlength(channels(k)) > 0 && ~isempty(headerChannel) && channels(k) ~= string(headerChannel)
        error('converter:io:ChannelConflict', '声明通道与 CSV 表头冲突：%s', files{k});
    end
    if strlength(channels(k)) == 0 && ~isempty(headerChannel)
        channels(k) = string(headerChannel);
    end
    if strlength(channels(k)) == 0 && interactive
        if isfield(config, 'jgChannelNames')
            allowed = config.jgChannelNames;
        else
            allowed = {'X1G','X2G','X3G','X4G'};
        end
        [index, accepted] = listdlg('ListString', allowed, ...
            'SelectionMode', 'single', 'PromptString', ['确认采集接口：' files{k}]);
        if ~accepted, channels = strings(0,1); return; end
        channels(k) = string(allowed{index});
    end
    if ismissing(channels(k)) || strlength(channels(k)) == 0
        error('converter:io:ChannelRequired', ...
            '表头不能确认采集通道，请按文件顺序提供 inputChannels：%s', files{k});
    end
end
end

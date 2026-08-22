function channelName = extractChannel(textValue, config)
%EXTRACTCHANNEL Extract a configured ADC/JG or legacy X-channel name.
%   CONFIG is optional. AD2208 supplies a JG-to-channel map through its
%   fixed device configuration; callers without it retain legacy X1G...X4G
%   recognition for AD9245.

if nargin < 2 || isempty(config)
    config = struct();
end

textUpper = upper(char(textValue));
adcJgToken = regexp(textUpper, 'ADC([1-8])[_-]?JG([0-9]+)', ...
    'tokens', 'once');
if ~isempty(adcJgToken)
    channelName = sprintf('ADC%s_JG%s', adcJgToken{1}, adcJgToken{2});
    return;
end

jgToken = regexp(textUpper, 'JG([0-9]+)', 'tokens', 'once');
if ~isempty(jgToken) && isfield(config, 'jgChannelNumbers') && ...
        isfield(config, 'jgChannelNames')
    jgNumber = str2double(jgToken{1});
    mapIndex = find(config.jgChannelNumbers == jgNumber, 1);
    if ~isempty(mapIndex) && mapIndex <= numel(config.jgChannelNames)
        channelName = char(config.jgChannelNames{mapIndex});
        return;
    end
end

captureToken = regexp(textUpper, 'CAPTURE[_-]?X([1-4])G', ...
    'tokens', 'once');
if ~isempty(captureToken)
    channelName = ['X' captureToken{1} 'G'];
    return;
end
token = regexp(textUpper, 'X([1-4])G', 'tokens', 'once');
if isempty(token)
    channelName = '';
else
    channelName = ['X' token{1} 'G'];
end
end


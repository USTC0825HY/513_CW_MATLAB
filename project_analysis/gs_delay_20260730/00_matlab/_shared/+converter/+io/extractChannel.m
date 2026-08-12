function channelName = extractChannel(textValue)
%EXTRACTCHANNEL Extract X1G through X4G from a name or path.

textUpper = upper(char(textValue));
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


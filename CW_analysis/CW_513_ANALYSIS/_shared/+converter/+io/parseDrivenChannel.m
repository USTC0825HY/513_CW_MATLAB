function channelName = parseDrivenChannel(textValue)
%PARSEDRIVENCHANNEL Parse DRIVE_X1G through DRIVE_X4G from text.

token = regexp(upper(char(textValue)), ...
    'DRIVE[_-]?X([1-4])G', 'tokens', 'once');
if isempty(token)
    channelName = '';
else
    channelName = ['X' token{1} 'G'];
end
end


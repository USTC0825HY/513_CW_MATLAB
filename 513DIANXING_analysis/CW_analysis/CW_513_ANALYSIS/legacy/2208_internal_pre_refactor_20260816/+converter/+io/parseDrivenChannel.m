function channelName = parseDrivenChannel(textValue)
%PARSEDRIVENCHANNEL Parse a driven AD2208 ADC/JG channel from text.

textUpper = upper(char(textValue));
token = regexp(textUpper, ...
    'DRIVE[_-]?ADC([1-8])[_-]?JG([0-9]+)', 'tokens', 'once');
if ~isempty(token)
    channelName = sprintf('ADC%s_JG%s', token{1}, token{2});
    return;
end
token = regexp(textUpper, ...
    'DRIVE[_-]?X([1-4])G', 'tokens', 'once');
if isempty(token)
    channelName = '';
else
    channelName = ['X' token{1} 'G'];
end
end


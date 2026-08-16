function channelName = extractChannel(textValue)
%EXTRACTCHANNEL Extract an AD2208 ADC/JG channel or a legacy X channel.

textUpper = upper(char(textValue));
token = regexp(textUpper, 'ADC([1-8])[_-]?JG([0-9]+)', 'tokens', 'once');
if ~isempty(token)
    channelName = sprintf('ADC%s_JG%s', token{1}, token{2});
    return;
end
token = regexp(textUpper, 'JG([0-9]+)', 'tokens', 'once');
if ~isempty(token)
    jgNumber = str2double(token{1});
    knownAdc = [1 2 3 5 6];
    knownJg = [15 17 19 22 24];
    mappingIndex = find(knownJg == jgNumber, 1);
    if isempty(mappingIndex)
        channelName = ['JG' token{1}];
    else
        channelName = sprintf('ADC%d_JG%d', ...
            knownAdc(mappingIndex), jgNumber);
    end
    return;
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


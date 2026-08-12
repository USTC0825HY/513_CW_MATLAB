function frequencyHz = parseFrequencyHz(fileName)
%PARSEFREQUENCYHZ Parse an Hz, kHz, MHz, or GHz value from text.

token = regexp(char(fileName), ...
    '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz)', 'tokens', 'once');
if isempty(token)
    frequencyHz = NaN;
    return;
end
scales = struct('hz', 1, 'khz', 1e3, 'mhz', 1e6, 'ghz', 1e9);
frequencyHz = str2double(token{1}) * scales.(lower(token{2}));
end


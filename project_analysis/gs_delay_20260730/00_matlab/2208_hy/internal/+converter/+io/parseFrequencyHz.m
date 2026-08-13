function frequencyHz = parseFrequencyHz(fileName)
%PARSEFREQUENCYHZ Parse Hz/kHz/MHz/GHz and compact M/K/G test labels.

token = regexp(char(fileName), ...
    '(?i)(\d+(?:\.\d+)?)\s*(GHz|MHz|kHz|Hz|G|M|K)(?![A-Za-z])', ...
    'tokens', 'once');
if isempty(token)
    frequencyHz = NaN;
    return;
end
scales = struct('hz', 1, 'khz', 1e3, 'mhz', 1e6, ...
    'ghz', 1e9, 'g', 1e9, 'm', 1e6, 'k', 1e3);
frequencyHz = str2double(token{1}) * scales.(lower(token{2}));
end


function powerDbm = parsePowerDbm(fileName)
%PARSEPOWERDBM Parse a signed dBm value from text.

token = regexp(char(fileName), ...
    '(?i)(-?\d+(?:\.\d+)?)\s*dBm', 'tokens', 'once');
if isempty(token)
    powerDbm = NaN;
else
    powerDbm = str2double(token{1});
end
end


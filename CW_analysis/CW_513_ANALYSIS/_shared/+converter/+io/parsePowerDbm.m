function powerDbm = parsePowerDbm(fileName)
%PARSEPOWERDBM Parse a signed dBm setpoint from a CSV file name.
%   Supports conventional names such as "-10dBm.csv" and the AD2208
%   acquisition convention "JG15-15M-N10db.csv", where the N prefix
%   denotes a negative dB value. The dB token is required so a tone name
%   such as "15M" is never interpreted as an input-power setpoint.

token = regexp(char(fileName), ...
    '(?i)(?:^|[_\-\s])([Nn+\-]?\d+(?:\.\d+)?)\s*dB(?:m)?(?=$|[^A-Za-z])', ...
    'tokens');
if isempty(token)
    powerDbm = NaN;
else
    valueText = token{end}{1};
    if startsWith(lower(valueText), 'n')
        powerDbm = -str2double(valueText(2:end));
    else
        powerDbm = str2double(valueText);
    end
end
end


function powerDbm = parsePowerDbm(fileName)
%PARSEPOWERDBM Parse AD2208 compact power labels such as 0db and N10db.

token = regexp(char(fileName), ...
    '(?i)(N)?(\d+(?:\.\d+)?)\s*dB(?:m)?(?![A-Za-z])', ...
    'tokens', 'once');
if isempty(token)
    powerDbm = NaN;
else
    signValue = 1;
    if strcmpi(token{1}, 'N')
        signValue = -1;
    end
    powerDbm = signValue * str2double(token{2});
end
end


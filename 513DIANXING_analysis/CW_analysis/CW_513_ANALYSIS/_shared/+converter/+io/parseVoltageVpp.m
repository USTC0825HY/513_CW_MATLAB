function voltageVpp = parseVoltageVpp(fileName)
%PARSEVOLTAGEVPP Parse a Vpp setpoint from a CSV file name.
%   Recognises names such as "ad9245_X1G_1kHz_1.5Vpp_sweep_...csv" and
%   rejects tone names like "15M" because the Vpp unit token is required.

token = regexp(char(fileName), ...
    '(?i)(?:^|[_\-\s])(\d+(?:\.\d+)?)\s*Vpp(?=$|[^A-Za-z])', 'tokens', 'once');
if isempty(token)
    voltageVpp = NaN;
else
    voltageVpp = str2double(token{1});
end
end

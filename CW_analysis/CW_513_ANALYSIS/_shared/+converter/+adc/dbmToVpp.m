function vpp = dbmToVpp(inputPowerDbm, referenceImpedanceOhm)
%DBMTOVPP Convert a 50-ohm (or explicit R) sine setpoint from dBm to Vpp.

if nargin < 2 || isempty(referenceImpedanceOhm)
    referenceImpedanceOhm = 50;
end
if any(~isfinite(referenceImpedanceOhm(:))) || ...
        any(referenceImpedanceOhm(:) <= 0)
    error('converter:adc:InvalidReferenceImpedance', ...
        '参考阻抗必须为正的有限数值。');
end
vpp = 2 * sqrt(2 * referenceImpedanceOhm .* ...
    1e-3 .* 10.^(inputPowerDbm ./ 10));
end

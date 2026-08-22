function inputPowerDbm = vppToDbm(vpp, referenceImpedanceOhm)
%VPPTODBM Convert a sine Vpp value to dBm at an explicit resistance.

if nargin < 2 || isempty(referenceImpedanceOhm)
    referenceImpedanceOhm = 50;
end
if any(~isfinite(referenceImpedanceOhm(:))) || ...
        any(referenceImpedanceOhm(:) <= 0)
    error('converter:adc:InvalidReferenceImpedance', ...
        '参考阻抗必须为正的有限数值。');
end
if any(vpp(:) <= 0 | ~isfinite(vpp(:)))
    error('converter:adc:InvalidVpp', ...
        'Vpp必须为正的有限数值。');
end
inputPowerDbm = 10 * log10((vpp ./ (2 * sqrt(2))).^2 ./ ...
    (referenceImpedanceOhm .* 1e-3));
end

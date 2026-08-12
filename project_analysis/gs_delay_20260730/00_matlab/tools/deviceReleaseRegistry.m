function spec = deviceReleaseRegistry(deviceName)
%DEVICERELEASEREGISTRY Return release metadata for a device directory.

deviceName = upper(strtrim(char(deviceName)));
switch deviceName
    case {'AD9245', '9245_HY'}
        spec = struct('deviceId', 'AD9245', 'folderName', '9245_hy', ...
            'version', '1.0.0', 'releaseReady', true, ...
            'entryFiles', {{'adc_sfdr_analysis.m', ...
            'adc_bandwidth_analysis.m', 'adc_isolation_analysis.m', ...
            'adc_power_scale_analysis.m', 'adc_inl_dnl_analysis.m'}});
    case {'AD2208', '2208_HY'}
        spec = pendingSpec('AD2208', '2208_hy');
    case {'AD766', '766_HY'}
        spec = pendingSpec('AD766', '766_hy');
    case {'AD9726', '9726_HY'}
        spec = pendingSpec('AD9726', '9726_hy');
    otherwise
        error('converter:build:UnknownDevice', '未知器件：%s。', deviceName);
end
end

function spec = pendingSpec(deviceId, folderName)
spec = struct('deviceId', deviceId, 'folderName', folderName, ...
    'version', '', 'releaseReady', false, 'entryFiles', {{}});
end

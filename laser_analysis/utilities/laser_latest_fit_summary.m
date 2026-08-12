function calibration = laser_latest_fit_summary(deviceType, interfaceName)
%LASER_LATEST_FIT_SUMMARY Load the newest reviewed Vpp-Codepp fit summary.
% Historical peak-fit rows in aggregate workbooks are deliberately ignored.

paths = laser_test_paths();
deviceType = upper(string(deviceType));
interfaceName = upper(string(interfaceName));

switch deviceType
    case "AD"
        resultDir = fullfile(paths.digitalLockDataRoot, ...
            '20260716_AD2208_scale', char(interfaceName), ...
            'multi_sine_ad_calibrate');
    case "DA"
        resultDir = fullfile(paths.dac9726DataRoot, ...
            '20260707_dac_scale', char(interfaceName), ...
            'dac_sine_scale_result');
    otherwise
        error('deviceType must be AD or DA.');
end

files = dir(fullfile(resultDir, '*_vpp_fit_summary_*.csv'));
if isempty(files)
    error('No Vpp-Codepp fit summary found for %s/%s under %s.', ...
        deviceType, interfaceName, resultDir);
end
[~, newestIndex] = max([files.datenum]);
summaryPath = fullfile(files(newestIndex).folder, files(newestIndex).name);
summary = readtable(summaryPath, 'TextType', 'string');
if height(summary) ~= 1 || ~ismember('slope_vpp_per_code', summary.Properties.VariableNames)
    error('Invalid fit summary schema: %s', summaryPath);
end

calibration = struct();
calibration.deviceType = deviceType;
calibration.interfaceName = interfaceName;
calibration.summaryPath = string(summaryPath);
calibration.measurementsPath = localMeasurementsPath(summaryPath);
calibration.slopeVPerCode = summary.slope_vpp_per_code(1);
calibration.interceptV = localNumeric(summary, 'intercept_vpp');
calibration.r2 = localNumeric(summary, 'r2');
calibration.referencePlane = localString(summary, 'target_reference_plane', ...
    localString(summary, 'data_dir', "not_recorded"));
calibration.method = localString(summary, 'code_vpp_method', ...
    localString(summary, 'output_vpp_method', "not_recorded"));
calibration.modifiedTime = datetime(files(newestIndex).datenum, ...
    'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss');
end

function value = localNumeric(tableValue, variableName)
if ismember(variableName, tableValue.Properties.VariableNames)
    value = tableValue.(variableName)(1);
else
    value = NaN;
end
end

function value = localString(tableValue, variableName, fallback)
if ismember(variableName, tableValue.Properties.VariableNames)
    value = string(tableValue.(variableName)(1));
else
    value = string(fallback);
end
end

function pathValue = localMeasurementsPath(summaryPath)
% AD and DA scripts use the same fit-summary/measurements filename pairing.
candidate = strrep(summaryPath, '_vpp_fit_summary_', '_vpp_measurements_');
if exist(candidate, 'file')
    pathValue = string(candidate);
else
    pathValue = "";
end
end

function paths = laser_test_paths()
%LASER_TEST_PATHS Stable roots for Laser electrical-test analysis.
% Environment variables override local defaults:
%   LASER_TEST_CODE_ROOT, LASER_TEST_DATA_ROOT,
%   LASER_TEST_REPORT_ROOT, LASER_TEST_REQUIREMENT_ROOT.

paths = struct();
defaultCodeRoot = fileparts(fileparts(mfilename('fullpath')));
paths.codeRoot = localEnvOrDefault('LASER_TEST_CODE_ROOT', ...
    defaultCodeRoot);
paths.dataRoot = localEnvOrDefault('LASER_TEST_DATA_ROOT', ...
    'F:\01_data_laser\DATA');
paths.reportRoot = localEnvOrDefault('LASER_TEST_REPORT_ROOT', ...
    'F:\01_Laser\202607');
paths.referenceRoot = localEnvOrDefault('LASER_TEST_REQUIREMENT_ROOT', ...
    'F:\01_Laser\202607_上海_电2\测试参考文件_20260630');

paths.formalReportRoot = fullfile(paths.reportRoot, '01_正式报告');
paths.processReportRoot = fullfile(paths.reportRoot, '02_过程报告');
paths.digitalLockDataRoot = fullfile(paths.dataRoot, 'SZSD_AD2208');
paths.dac9726DataRoot = fullfile(paths.dataRoot, 'SZSD_DAC9726');
paths.delayDriverDataRoot = fullfile(paths.dataRoot, 'DA766');
paths.rfReferenceDataRoot = fullfile(paths.dataRoot, ...
    '20260709_SZSD_射频参考');
paths.digitalLockFormalReport = fullfile(paths.formalReportRoot, ...
    '02_SZSD_数字锁定板', '数字锁定板测试报告.docx');
paths.currentRequirement = fullfile(paths.referenceRoot, ...
    '超稳激光电控箱第2套电性件性能测试项.docx');
paths.calibrationWorkbook = ...
    'F:\01_data_laser\DATA\AD_DA_calibration_table.xlsx';
end

function value = localEnvOrDefault(name, defaultValue)
raw = strtrim(getenv(name));
if isempty(raw)
    value = defaultValue;
else
    value = raw;
end
end

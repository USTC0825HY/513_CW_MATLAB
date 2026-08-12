% s21_calibrate_ad9245_x4g_scale
% Compatibility entry for AD9245 X4G Vpp-Codepp calibration.

clear;
clc;
cfg = laser_analysis.ad9245_calibration_config("X4G");
temporaryOutputDir = getenv('LASER_ANALYSIS_OUTPUT_DIR');
if ~isempty(temporaryOutputDir)
    cfg.outputDir = temporaryOutputDir;
end
result = laser_analysis.run_ad9245_scale_calibration(cfg);

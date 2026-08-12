% s19_calibrate_ad9245_x3g_scale
% Compatibility entry for AD9245 X3G Vpp-Codepp calibration.

clear;
clc;
cfg = laser_analysis.ad9245_calibration_config("X3G");
temporaryOutputDir = getenv('LASER_ANALYSIS_OUTPUT_DIR');
if ~isempty(temporaryOutputDir)
    cfg.outputDir = temporaryOutputDir;
end
result = laser_analysis.run_ad9245_scale_calibration(cfg);

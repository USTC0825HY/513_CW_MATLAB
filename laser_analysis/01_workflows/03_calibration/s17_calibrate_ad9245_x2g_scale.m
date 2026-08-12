% s17_calibrate_ad9245_x2g_scale
% Compatibility entry for AD9245 X2G Vpp-Codepp calibration.
% Original implementation: archive/20260723_pre_refactor.

clear;
clc;
cfg = laser_analysis.ad9245_calibration_config("X2G");
temporaryOutputDir = getenv('LASER_ANALYSIS_OUTPUT_DIR');
if ~isempty(temporaryOutputDir)
    cfg.outputDir = temporaryOutputDir;
end
result = laser_analysis.run_ad9245_scale_calibration(cfg);

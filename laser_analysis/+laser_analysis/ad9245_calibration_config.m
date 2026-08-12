function cfg = ad9245_calibration_config(channel)
%AD9245_CALIBRATION_CONFIG Return the reviewed AD9245 scale configuration.
%   CFG = laser_analysis.ad9245_calibration_config(CHANNEL) accepts
%   X1G, X2G, X3G, or X4G.  Callers may override any field, especially
%   cfg.outputDir, before passing CFG to run_ad9245_scale_calibration.

arguments
    channel (1, 1) string
end

channel = upper(strtrim(channel));
dataColumns = struct('X1G', 6, 'X2G', 8, 'X3G', 10, 'X4G', 4);
validColumns = struct('X1G', 7, 'X2G', 9, 'X3G', 11, 'X4G', 5);
if ~isfield(dataColumns, char(channel))
    error('laser_analysis:UnknownChannel', ...
        'Unsupported AD9245 channel "%s". Use X1G, X2G, X3G, or X4G.', channel);
end

paths = laser_test_paths();
dataRoot = fullfile(paths.dataRoot, 'YCQD_AD_9245', 'scale');
cfg = struct;
cfg.channel = channel;
cfg.dataDir = fullfile(dataRoot, char(channel));
cfg.outputDir = fullfile(cfg.dataDir, sprintf('AD9245_%s_scale_result', channel));
cfg.filePattern = '*Vpp.csv';
cfg.scriptVersion = '2026-07-23-refactor-r1';
cfg.sampleIndexColumn = 1;
cfg.dataColumn = dataColumns.(char(channel));
cfg.validColumn = validColumns.(char(channel));
cfg.validValue = 1;
cfg.adcBits = 14;
cfg.nearRailMarginCode = 256;
cfg.minimumSineFitR2 = 0.99;
cfg.theoreticalAdcPinScaleUvPerCode = 2 / 2^cfg.adcBits * 1e6;
cfg.referencePlane = ...
    "signal-generator setting parsed from filename; termination/load not recorded";
cfg.sourceLevelDefinition = "Vpp parsed from filename";
cfg.plotDpi = 300;
end

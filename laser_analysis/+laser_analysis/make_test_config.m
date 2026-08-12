function cfg = make_test_config(board, profile, testId)
%MAKE_TEST_CONFIG Create an explicit configuration for s26-s35.
%   CFG = laser_analysis.make_test_config(BOARD, PROFILE, TESTID) returns
%   paths, requirement provenance, and conservative analysis defaults.
%   CFG.manifestFile and CFG.outputDir must be reviewed before execution.
%
%   GS configurations are created with formalEnabled=false until their
%   channel and connector mapping is reviewed.

arguments
    board (1, 1) string
    profile (1, 1) string
    testId (1, 1) string
end

requirements = laser_analysis.requirement_profile(board, profile);
paths = laser_test_paths();
cfg = struct;
cfg.board = lower(strtrim(board));
cfg.profile = upper(strtrim(profile));
cfg.testId = lower(strtrim(testId));
cfg.scriptVersion = "2026-07-26-cw-offline-r1";
cfg.manifestFile = "";
cfg.outputDir = fullfile(paths.dataRoot, 'analysis_reports', ...
    char(cfg.board), char(cfg.profile), char(cfg.testId));
cfg.timestampedOutput = true;
cfg.showFigures = false;
cfg.plotDpi = 180;
cfg.formalEnabled = cfg.profile == "CW";
cfg.requirements = requirements;
cfg.requireReferencePlane = true;
cfg.minimumSamples = 32;
cfg.maximumSamples = inf;
cfg.welchOverlapRatio = 0.5;
cfg.sfdrGuardBins = 3;
cfg.responseReferenceHz = NaN;
cfg.clipRailMarginCode = 4;
cfg.compressionThresholdDb = 1;
cfg.minimumCodeCoverage = 0.90;
cfg.minimumExpectedCountsPerCode = 20;
cfg.delayResolutionFraction = 0.1;
cfg.targetOffsetsHz = [1, 100e3];
cfg.integratedNoiseBandHz = [1e3, 100e3];
cfg.allanTargetTauS = [1, 10000];
end

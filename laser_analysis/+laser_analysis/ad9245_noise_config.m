function cfg = ad9245_noise_config(channel, variant)
%AD9245_NOISE_CONFIG Return an AD9245-DAC G100 noise-analysis configuration.
%   CFG = laser_analysis.ad9245_noise_config(CHANNEL, VARIANT) supports
%   X1G/current, X2G/current, X3G/current, X4G/current, and X4G/legacy.
%   The legacy X4G variant preserves the record-limited s22 evidence label.

arguments
    channel (1, 1) string
    variant (1, 1) string = "current"
end

channel = upper(strtrim(channel));
variant = lower(strtrim(variant));
paths = laser_test_paths();
dataRoot = paths.dataRoot;
adcRoot = fullfile(dataRoot, 'YCQD_AD_9245');
dacRoot = fullfile(dataRoot, 'SZSD_DAC9726', '20260707_dac_scale');

cfg = struct;
cfg.channel = channel;
cfg.variant = variant;
cfg.fpgaGain = 100;
cfg.fpgaGainEvidence = ...
    "test directory and condition label; active RTL transfer not independently verified";
cfg.requirementBandEndHz = 30e3;
cfg.extendedAnalysisEndHz = 50e3;
cfg.asdLimitAt1HzUvPerSqrtHz = 10;
cfg.requirementTestCondition = "ADC input DC-30 kHz; 30 kHz first-order LPF; CW";
cfg.welchWindowSeconds = 10;
cfg.overlapRatio = 0.5;
cfg.windowSensitivitySeconds = [2; 5; 10; 20];
cfg.lowFrequencyExportEndHz = 100;
cfg.spurMinimumFrequencyHz = 0.1;
cfg.spurMinimumSeparationHz = 1;
cfg.spurCount = 20;
cfg.plotDpi = 220;
cfg.useMatLength = true;
cfg.requirementSource = paths.currentRequirement;

switch channel
    case "X1G"
        requireCurrent(variant, channel);
        cfg.dacChannel = "JG11";
        cfg.dataDir = fullfile(adcRoot, 'X1G_JG11_G100');
        cfg.inputMat = fullfile(cfg.dataDir, 'X1G_100KS_s_20S.mat');
        cfg.auxiliaryEvidence = fullfile(cfg.dataDir, 'X1G_100KS_s_20S.png');
        cfg.auxiliaryEvidenceRole = ...
            "same-run screenshot; labelled mV; numerically consistent with MAT";
        cfg.adcCalibrationCsv = fullfile(adcRoot, 'scale', 'X1G', ...
            'AD9245_X1G_scale_result', 'AD9245_X1G_scale_fit_summary.csv');
        cfg.dacCalibrationCsv = fullfile(dacRoot, 'JG11', ...
            'dac_sine_scale_result', ...
            'JG11_dac_vpp_code_vpp_scale_vpp_fit_summary_20260716_214031.csv');
        cfg.scriptVersion = '2026-07-23-refactor-x1g-r1';
    case "X2G"
        requireCurrent(variant, channel);
        cfg.dacChannel = "JG3";
        cfg.dataDir = fullfile(adcRoot, 'X2G_JG3_G100');
        cfg.inputMat = fullfile(cfg.dataDir, 'X2G_100KS_s_20s.mat');
        cfg.auxiliaryEvidence = fullfile(cfg.dataDir, 'X2G_100KS_s.png');
        cfg.auxiliaryEvidenceRole = "same-run PicoScope screenshot";
        cfg.adcCalibrationCsv = fullfile(adcRoot, 'scale', 'X2G', ...
            'AD9245_X2G_scale_result', 'AD9245_X2G_scale_fit_summary.csv');
        cfg.dacCalibrationCsv = fullfile(dacRoot, 'JG3', ...
            'dac_sine_scale_result', ...
            'JG3_dac_vpp_code_vpp_scale_vpp_fit_summary_20260708_164012.csv');
        cfg.scriptVersion = '2026-07-23-refactor-x2g-r1';
    case "X3G"
        requireCurrent(variant, channel);
        cfg.dacChannel = "JG2";
        cfg.dataDir = fullfile(adcRoot, 'X3G_JG2_G100');
        cfg.inputMat = fullfile(cfg.dataDir, 'X3G_100KS_s_20S.mat');
        cfg.auxiliaryEvidence = fullfile(adcRoot, ...
            'X2G_JG3_G100', 'X2G_100KS_s.png');
        cfg.auxiliaryEvidenceRole = ...
            "same-format X2G screenshot; X3G MAT voltage unit remains limited evidence";
        cfg.adcCalibrationCsv = fullfile(adcRoot, 'scale', 'X3G', ...
            'AD9245_X3G_scale_result', 'AD9245_X3G_scale_fit_summary.csv');
        cfg.dacCalibrationCsv = fullfile(dacRoot, 'JG2', ...
            'dac_sine_scale_result', ...
            'JG2_dac_vpp_code_vpp_scale_vpp_fit_summary_20260708_164451.csv');
        cfg.scriptVersion = '2026-07-23-refactor-x3g-r1';
    case "X4G"
        if ~ismember(variant, ["current", "legacy"])
            error('laser_analysis:UnknownVariant', ...
                'X4G variant must be "current" or "legacy".');
        end
        cfg.dacChannel = "JG32";
        cfg.dataDir = fullfile(adcRoot, 'X4G_JG32_G100');
        cfg.inputMat = fullfile(cfg.dataDir, 'X4G_100KS_s_20S.mat');
        cfg.auxiliaryEvidence = fullfile(cfg.dataDir, 'X4G_100KS_s_20S.png');
        cfg.adcCalibrationCsv = fullfile(adcRoot, 'scale', 'X4G', ...
            'AD9245_X4G_scale_result', 'AD9245_X4G_scale_fit_summary.csv');
        cfg.dacCalibrationCsv = fullfile(dacRoot, 'JG32', ...
            'dac_sine_scale_result', ...
            'JG32_dac_vpp_code_vpp_scale_vpp_fit_summary_20260708_164614.csv');
        if variant == "legacy"
            cfg.auxiliaryEvidenceRole = ...
                "same-run screenshot conflicts with short MAT Length; MAT metadata governs";
            cfg.scriptVersion = '2026-07-23-refactor-x4g-legacy-r1';
        else
            cfg.auxiliaryEvidenceRole = ...
                "companion screenshot predates updated MAT; identity and unit not independently verified";
            cfg.scriptVersion = '2026-07-23-refactor-x4g-current-r1';
        end
    otherwise
        error('laser_analysis:UnknownChannel', ...
            'Unsupported AD9245 channel "%s".', channel);
end

cfg.caseName = sprintf('AD9245_%s_%s_G100', cfg.channel, cfg.dacChannel);
cfg.outputDir = fullfile(cfg.dataDir, ...
    sprintf('AD9245_%s_%s_G100_PSD_ASD_result', cfg.channel, cfg.dacChannel));
end

function requireCurrent(variant, channel)
if variant ~= "current"
    error('laser_analysis:UnknownVariant', ...
        '%s supports only the "current" variant.', channel);
end
end

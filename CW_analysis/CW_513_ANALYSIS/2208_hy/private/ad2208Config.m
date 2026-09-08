function config = ad2208Config(analysisId)
%AD2208CONFIG Return the fixed configuration for YB2208/AD2208 analysis.

config = struct();
config.deviceId = 'AD2208';
config.analysisId = lower(char(analysisId));
config.version = '1.4.0';
config.releaseReady = true;
config.adcBits = 16;
config.adcFullScalePeakCode = 2^(config.adcBits - 1);
config.adcCodeFormat = 'signed';
config.adcDataColumn = 4;
config.headerModulePattern = '(?i)yb2208_test_module\[(\d+)\]';
% Hardware module index is zero based in the Vivado ILA CSV header.
% Keep this device-specific map in the AD2208 configuration so the shared
% I/O layer does not reinterpret AD9245 X1G...X4G channels.
config.moduleChannelMap = {'ADC1_JG15', 'ADC2_JG17', 'ADC3_JG19', ...
    'ADC4', 'ADC5_JG22', 'ADC6_JG24', 'ADC7', 'ADC8'};
config.jgChannelNumbers = [15, 17, 19, 22, 24];
config.jgChannelNames = {'ADC1_JG15', 'ADC2_JG17', 'ADC3_JG19', ...
    'ADC5_JG22', 'ADC6_JG24'};
config.fitCycles = 20;
config.minimumFitSamples = 1024;
config.saveFigures = true;
config.showFigures = false;
config.sampleRate = 100e6;

switch config.analysisId
    case 'sfdr'
        config.nfft = 128 * 1024;
        config.dcSpan = 16;
        config.signalSpan = 16;
        config.harmonicSpan = 8;
        config.maxHarmonicOrder = 8;
    case 'bandwidth'
        config.minimumFitR2 = 0.99;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = false;
        config.bandwidthFrequencySource = 'file';
        config.clippingMarginCode = 1;
        config.bandwidthAnnotationFrequencyHz = 30e6;
        config.stopbandStartFrequencyHz = 70e6;
        config.minimumStopbandAttenuationDb = 40;
    case 'isolation'
        config.isolationFrequencyHz = 1e6;
        config.frequencyMismatchTolerance = 0.02;
        config.drivenChannel = 'ADC2_JG17';
        config.minimumIsolationDb = 40;
    case 'power_scale'
        config.version = '1.4.1';
        config.testFrequencyHz = 1e6;
        config.frequencyMismatchTolerance = 0.02;
        % The sweep files cover -10 to +8 dBm.  The shared calibration
        % routine automatically reduces the upper bound to the last
        % contiguous non-clipped point when this option is enabled.
        config.powerRangeDbm = [-10, 8];
        config.autoSelectPowerRangeFromUnclipped = true;
        config.powerScalePlotMode = 'inverse';
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.criticalInputThresholdFraction = 0.99;
        config.plateauChangeThreshold = 0.01;
        config.minimumSineFitR2 = 0.98;
        config.excludeFrequencyMismatchFromPowerScale = true;
        config.referenceImpedanceOhm = 50;
        % Filename dBm values are converted to Vpp at the explicit 50-ohm
        % reference. The formal fit is CodePp -> Vpp; dBm is traceability.
        config.powerSetpointSource = 'dBm value parsed from AD2208 CSV filename';
    case 'inl_dnl'
        config.marginCode = 1000;
        config.minimumFitR2 = 0.999;
        config.frequencyRefinementCycles = 200;
        config.frequencyRefinementMinimumSamples = 20000;
        config.minimumValidCaptureFraction = 1.0;
        config.glitchSigmaMultiplier = 10;
        config.glitchMinimumThresholdCode = 128;
        config.maximumGlitchFraction = 0;
        config.clippingMarginCode = 1;
        % Each CSV is an independently triggered ILA record. Do not infer
        % sample-to-sample phase continuity from file-name order.
        config.recordsAreSampleContiguous = false;
    case 'input_noise'
        config.version = '1.5.0';
        config.sampleRate = 100e6;
        config.noiseBandHz = [10e6, 25e6];
        config.noiseLimitNvPerSqrtHz = 300;
        % User-fixed settings for 131072-sample ILA captures: one full
        % record, no segment averaging; frequency-bin spacing 762.939 Hz.
        config.welchSegmentCount = 1;
        config.welchOverlapRatio = 0;
        config.welchNfft = 131072;
        config.inputTermination = '50 ohm to ground; see YB2208 test instruction T07R001';
        config.referencePlane = 'AD2208 external board input';
        config.formalConditionSource = 'YB2208_test_instruction_hy T07R001';
        config.calibrationSource = 'CW_513_ANALYSIS_AD2208_AD9245_刻度参数_20260822.xlsx';
    otherwise
        error('ad2208:UnknownAnalysis', ...
            '不支持的 AD2208 分析类型：%s。', analysisId);
end
end

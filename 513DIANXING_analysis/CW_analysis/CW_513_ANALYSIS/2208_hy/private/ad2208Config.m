function config = ad2208Config(analysisId)
%AD2208CONFIG Return the fixed configuration for YB2208/AD2208 analysis.

config = struct();
config.deviceId = 'AD2208';
config.analysisId = lower(char(analysisId));
config.version = '1.3.0';
config.releaseReady = true;
config.adcBits = 16;
config.adcFullScalePeakCode = 2^(config.adcBits - 1);
config.adcCodeFormat = 'signed';
config.adcDataColumn = 4;
config.headerModulePattern = '(?i)yb2208_test_module\[(\d+)\]';
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
        config.drivenChannel = 'ADC1_JG15';
        config.minimumIsolationDb = 40;
    case 'power_scale'
        config.testFrequencyHz = 15e6;
        config.frequencyMismatchTolerance = 0.02;
        config.powerRangeDbm = [-10, 6];
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.plateauChangeThreshold = 0.01;
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
    otherwise
        error('ad2208:UnknownAnalysis', ...
            '不支持的 AD2208 分析类型：%s。', analysisId);
end
end

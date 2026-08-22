function config = ad9245Config(analysisId)
%AD9245CONFIG Return the fixed configuration for an AD9245 analysis.

config = struct();
config.deviceId = 'AD9245';
config.analysisId = lower(analysisId);
config.version = '1.0.0';
config.releaseReady = true;
config.adcBits = 14;
config.adcFullScalePeakCode = 2^(config.adcBits - 1);
config.adcCodeFormat = 'signed';
config.adcDataColumn = 0;
config.headerModulePattern = '(?i)ad9245_test_module\[(\d+)\]';
config.fitCycles = 20;
config.minimumFitSamples = 1024;
config.saveFigures = true;
config.showFigures = false;

switch config.analysisId
    case 'sfdr'
        config.sampleRate = 20e6;
        config.nfft = 128 * 1024;
        config.dcSpan = 16;
        config.signalSpan = 16;
        config.harmonicSpan = 8;
        config.maxHarmonicOrder = 8;
    case 'bandwidth'
        config.sampleRate = 20e6;
        config.minimumFitR2 = 0.99;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = false;
        config.bandwidthFrequencySource = 'file';
        config.clippingMarginCode = 1;
    case 'isolation'
        config.sampleRate = 20e6;
        config.isolationFrequencyHz = 1e6;
        config.frequencyMismatchTolerance = 0.02;
        config.drivenChannel = 'X3G';
        config.minimumIsolationDb = 40;
    case 'power_scale'
        config.sampleRate = 20e6;
        config.testFrequencyHz = 1e6;
        config.frequencyMismatchTolerance = 0.02;
        config.powerRangeDbm = [-10, 6];
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.plateauChangeThreshold = 0.01;
        config.referenceImpedanceOhm = 50;
        % Filename dBm values are converted to Vpp at 50 ohm before the
        % formal CodePp -> Vpp fit. dBm remains traceability metadata.
        config.powerSetpointSource = 'dBm value parsed from AD9245 CSV filename';
    case 'inl_dnl'
        config.sampleRate = 20e6;
        config.marginCode = 1000;
        config.minimumFitR2 = 0.99;
    otherwise
        error('ad9245:UnknownAnalysis', ...
            '不支持的 AD9245 分析类型：%s。', analysisId);
end
end

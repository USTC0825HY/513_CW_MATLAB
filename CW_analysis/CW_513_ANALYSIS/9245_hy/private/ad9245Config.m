function config = ad9245Config(analysisId)
%AD9245CONFIG Return the fixed configuration for an AD9245 analysis.

config = struct();
config.deviceId = 'AD9245';
config.analysisId = lower(analysisId);
config.version = '1.1.0';
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

% AD9245 conversion clock is externally injected at 20 MHz, but these CSV
% records are exported by the ILA clocked from clk_25m_cp.  Frequency- and
% time-domain analysis must therefore use the ILA record interval (40 ns),
% rather than the ADC conversion-clock period (50 ns).
ilaCaptureSampleRateHz = 25e6;
config.adcConversionClockHz = 20e6;
config.ilaCaptureClock = 'clk_25m_cp';
config.ilaCaptureSampleRateHz = ilaCaptureSampleRateHz;
config.sampleRateSource = 'AD9245 ILA capture clock clk_25m_cp';

switch config.analysisId
    case 'sfdr'
        config.sampleRate = ilaCaptureSampleRateHz;
        config.nfft = 128 * 1024;
        config.dcSpan = 16;
        config.signalSpan = 16;
        config.harmonicSpan = 8;
        config.maxHarmonicOrder = 8;
    case 'bandwidth'
        config.sampleRate = ilaCaptureSampleRateHz;
        config.minimumFitR2 = 0.99;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = false;
        config.bandwidthFrequencySource = 'file';
        config.clippingMarginCode = 1;
    case 'isolation'
        config.sampleRate = ilaCaptureSampleRateHz;
        % The current AD9245 isolation captures are the 10 kHz / -6 dB
        % records under 04_Isolation.  The driven channel is supplied per
        % acquisition by adc_isolation_analysis run options.
        config.isolationFrequencyHz = 10e3;
        config.frequencyMismatchTolerance = 0.02;
        config.drivenChannel = 'X3G';
        config.minimumIsolationDb = 40;
    case 'power_scale'
        config.version = '1.2.0';
        config.sampleRate = ilaCaptureSampleRateHz;
        % The current AD9245 power-scale captures are 1 kHz sweeps.
        config.testFrequencyHz = 1e3;
        config.frequencyMismatchTolerance = 0.02;
        config.powerRangeDbm = [-10, 6];
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.criticalInputThresholdFraction = 0.99;
        config.plateauChangeThreshold = 0.01;
        config.referenceImpedanceOhm = 50;
        % Filename dBm values are converted to Vpp at 50 ohm before the
        % formal CodePp -> Vpp fit. dBm remains traceability metadata.
        config.powerSetpointSource = 'dBm value parsed from AD9245 CSV filename';
    case 'inl_dnl'
        config.version = '1.1.0';
        config.sampleRate = ilaCaptureSampleRateHz;
        config.marginCode = 1000;
        config.minimumFitR2 = 0.99;
        config.frequencyRefinementCycles = 200;
        config.frequencyRefinementMinimumSamples = 20000;
        config.minimumValidCaptureFraction = 1.0;
        config.glitchSigmaMultiplier = 10;
        config.glitchMinimumThresholdCode = 128;
        config.maximumGlitchFraction = 0;
        config.clippingMarginCode = 1;
        config.recordsAreSampleContiguous = false;
    otherwise
        error('ad9245:UnknownAnalysis', ...
            '不支持的 AD9245 分析类型：%s。', analysisId);
end
end

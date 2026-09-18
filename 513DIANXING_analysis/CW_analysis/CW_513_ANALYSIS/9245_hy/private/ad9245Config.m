function config = ad9245Config(analysisId)
%AD9245CONFIG Return the fixed configuration for an AD9245 analysis.

config = struct();
config.deviceId = 'AD9245';
config.reportCalibration = converter.calibration.reportCalibration('AD9245');
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
ilaCaptureSampleRateHz = 20e6;
config.adcConversionClockHz = 20e6;
config.ilaCaptureClock = 'clk_25m_cp';
config.ilaCaptureSampleRateHz = ilaCaptureSampleRateHz;
config.sampleRateSource = 'AD9245 ILA capture clock clk_25m_cp';

switch config.analysisId
    case 'sfdr'
        config.version = '1.2.0';
        config.sampleRate = ilaCaptureSampleRateHz;
        % Legacy 25 MHz ILA captures observe the 20 MHz ADC register with
        % held codes. Keep one fixed-phase ILA row out of every five. The
        % resulting sequence advances by four ADC conversions per point
        % and is uniformly interpreted at 5 MHz.
        config.sfdrSampleStride = 5;
        config.sfdrAnalysisSampleRateHz = ...
            ilaCaptureSampleRateHz / config.sfdrSampleStride;
        config.sfdrSamplingMode = 'legacy_25mhz_ila_keep_one_of_five';
        config.sfdrResultUse = '旧25 MHz ILA数据抽样估算';
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
        config.version = '1.3.0';
        config.sampleRate = ilaCaptureSampleRateHz;
        % The 20260917 AD9245 power sweeps are 1 kHz Vpp-labelled sweeps
        % (0.1--2.1 Vpp at the generator, High-Z, 0 V offset); older
        % dBm-labelled sweeps keep the legacy path. The shared kernel now
        % parses either filename unit.
        config.testFrequencyHz = 1e3;
        config.frequencyMismatchTolerance = 0.02;
        config.powerRangeDbm = [-10, 6];
        config.powerRangeVpp = [0.1, 2.1];
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.criticalInputThresholdFraction = 0.99;
        config.plateauChangeThreshold = 0.01;
        config.referenceImpedanceOhm = 50;
        % Filename Vpp/dBm values feed the CodePp -> Vpp fit directly;
        % dBm metadata is derived at the 50 ohm reference impedance.
        config.powerSetpointSource = 'Vpp or dBm value parsed from AD9245 CSV filename';
    case 'inl_dnl'
        config.version = '1.1.0';
        config.sampleRate = ilaCaptureSampleRateHz;
        config.marginCode = 0;
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

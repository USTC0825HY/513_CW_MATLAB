function config = ad677Config(analysisId)
%AD677CONFIG Return evidence-based AD677 acquisition configuration.

config = struct();
config.deviceId = 'AD677';
config.analysisId = lower(char(analysisId));
config.version = '0.1.0';
config.releaseReady = true;
config.formalEnabled = false;
config.metadata = struct('formalStatusReason', ...
    '板端/ADC引脚参考面、终端负载和指标限值尚未确认');
config.sampleRate = 100e6;
config.sampleRateDefinition = ...
    'Vivado ILA capture clock; ADC code is held between adc_data_vld pulses';
config.adcBits = 16;
config.adcFullScalePeakCode = 2^(config.adcBits - 1);
config.adcCodeFormat = 'signed';
config.inputRadix = 'auto';
config.adcCodingDefinition = '16-bit signed codes; explicit decimal values or hexadecimal two''s-complement words';
config.adcDataColumn = 4;
config.validDataColumn = 5;
config.headerModulePattern = '(?i)(?:u_ad677_|adc)(\d+)(?:/adc_data|_data)';
config.moduleChannelMap = {'', '677_1', '677_2'};
config.channelNames = {'677_1', '677_2'};
config.fitCycles = 20;
config.minimumFitSamples = 1024;
config.saveFigures = true;
config.showFigures = false;
config.referencePlane = ...
    'SDG6032X-E generator displayed Vpp in High-Z output mode; board/ADC-pin Vpp unverified';
config.loadDefinition = ...
    'Generator output configured LOAD=HZ; actual board termination not recorded';
config.referenceImpedanceOhm = NaN;

switch config.analysisId
    case 'bandwidth'
        config.version = '0.2.0';
        % The ILA captures at 100 MHz but the AD677 word only updates on the
        % adc_data_vld strobe (every 1200 ILA cycles on the 20260917
        % captures, i.e. 83.333 kS/s uniform). Bandwidth reads filter the
        % held rows (filterValidStrobe) and the effective sample rate is
        % derived per run from the measured strobe spacing; a finite
        % sampleRate override via runOptions skips the derivation.
        config.ilaClockHz = 100e6;
        config.sampleRate = NaN;
        config.sampleRateDefinition = ['ILA 100 MHz capture clock divided ' ...
            'by the measured adc_data_vld strobe period (1200 on 20260917 ' ...
            'captures = 83.333 kS/s effective data rate)'];
        config.filterValidStrobe = true;
        % A record must span at least this many input cycles for the fitted
        % No cycle-coverage or frequency-mismatch filtering: all sweep
        % points are processed and reported as measured.  The shared
        % kernel's R2 check (minimumFitR2 = 0.90) still guards against
        % grossly bad fits without discarding genuine stopband data.
        config.minimumRecordCycles = 0;
        config.minimumFitR2 = 0.90;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = false;
        config.bandwidthFrequencySource = 'file';
        config.fitFrequencySource = 'file';
        config.clippingMarginCode = round(0.02 * config.adcFullScalePeakCode);
        config.metadata.frequencyCoverageHz = [100, 30e3]; % Descriptive, not a filter.
        config.metadata.bandwidthLimitHz = NaN;
    case 'power_scale'
        config.version = '0.2.0';
        config.testFrequencyHz = 1e3;
        config.frequencyMismatchTolerance = 0.02;
        config.powerRangeVpp = [0.25, 2.5];
        config.powerRangeDbm = [NaN, NaN];
        config.powerSetpointUnit = 'Vpp';
        config.clippingThreshold = 0.98;
        config.clippingFractionLimit = 0.01;
        config.criticalInputThresholdFraction = 0.99;
        config.plateauChangeThreshold = 0.01;
        config.minimumSineFitR2 = 0.95;
        config.excludeFrequencyMismatchFromPowerScale = true;
        config.powerSetpointSource = ...
            'run_manifest amplitude/source readback, validated against filename Vpp';
        config.metadata.scaleRequirement = 'not supplied';
    case 'input_noise'
        config.version = '0.4.0';
        config.referencePlane = ...
            'AD677 external board input; physical board/ADC-pin plane unverified';
        config.sampleRate = 100e6;
        config.noiseBandHz = [1, 10e3];
        % Requirement line drawn on the input-equivalent ASD figure:
        % <=1 uV/sqrtHz over 1 Hz--10 kHz (user-fixed AD677 noise limit).
        config.noiseLimitNvPerSqrtHz = 1000;
        config.welchSegmentCount = 1;
        config.welchOverlapRatio = 0;
        config.welchNfft = 131072;
        config.samplesIncludeHold = true;
        config.inputTermination = 'not confirmed';
        config.formalConditionSource = 'User reference line: 1 uV/sqrtHz; formal measurement conditions unconfirmed';
    case 'pico_noise'
        config = struct('analysisId', 'ad677_pico_noise_1hz', 'version', '1.0.0', ...
            'baselineMode', 'none', 'fpgaGain', 128, ...
            'asdCheckHz', 1, ...
            'referencePlane', 'AD677 external board input; physical board/ADC-pin plane unverified', 'plotDpi', 180, 'waveVariable', '', ...
            'welch', struct('targetResolutionHz',0.2,'overlapRatio',0.5,'windowType','hann'), ...
            'plotLimitUvPerSqrtHz', 1, ...
            'formalEnabled', false);
    otherwise
        error('ad677:UnknownAnalysis', ...
            '不支持的 AD677 分析类型：%s。', analysisId);
end
end

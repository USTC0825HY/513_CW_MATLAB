function config = ad677Config(analysisId)
%AD677CONFIG Return evidence-based AD677 acquisition configuration.

config = struct();
config.deviceId = 'AD677';
config.analysisId = lower(char(analysisId));
config.version = '0.1.0';
config.releaseReady = true;
config.formalEnabled = false;
config.formalStatus = '暂不能判定';
config.formalStatusReason = ...
    '板端/ADC引脚参考面、终端负载和指标限值尚未确认';
config.sampleRate = 100e6;
config.sampleRateDefinition = ...
    'Vivado ILA capture clock; ADC code is held between adc_data_vld pulses';
config.adcBits = 16;
config.adcFullScalePeakCode = 2^(config.adcBits - 1);
config.adcCodeFormat = 'signed';
config.adcCodingDefinition = '16-bit signed two''s-complement decimal export';
config.adcDataColumn = 4;
config.validDataColumn = 5;
config.headerModulePattern = '(?i)u_ad677_(\d+)/adc_data';
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
        % The 100 MHz ILA records a zero-order-held ADC word. The expected
        % high-frequency stair-step residual lowers sine-fit R2 near the
        % observed roll-off; 0.90 retains the resolved 12--16 kHz points
        % while excluding the visibly under-resolved 20/30 kHz captures.
        config.minimumFitR2 = 0.90;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = false;
        config.bandwidthFrequencySource = 'file';
        config.fitFrequencySource = 'file';
        config.clippingMarginCode = round(0.02 * config.adcFullScalePeakCode);
        config.frequencyCoverageHz = [100, 30e3];
        config.bandwidthLimitHz = NaN;
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
        config.scaleRequirement = 'not supplied';
    otherwise
        error('ad677:UnknownAnalysis', ...
            '不支持的 AD677 分析类型：%s。', analysisId);
end
end

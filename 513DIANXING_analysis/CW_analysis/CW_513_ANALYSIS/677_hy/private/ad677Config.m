function config = ad677Config(analysisId)
%AD677CONFIG Return evidence-based AD677 acquisition configuration.

config = struct();
config.deviceId = 'AD677';
config.analysisId = lower(char(analysisId));
if ~strcmp(config.analysisId, 'input_noise')
    config.reportCalibration = converter.calibration.reportCalibration('AD677');
end
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
        % amplitude to be phase-robust: 100 Hz--1 kHz captures hold only
        % 0.13--1.31 cycles of ~109 valid samples, and a partial-arc fit
        % returns a wrong CodePp with an excellent R2.
        config.minimumRecordCycles = 2;
        % R2 relaxes only for the AD677's real distortion/noise, which grows
        % toward 30 kHz (measured 0.94 at 30 kHz); 0.90 keeps the resolved
        % 20/22/24 kHz points that bracket the -3 dB crossing.
        config.minimumFitR2 = 0.90;
        config.referencePointCount = 3;
        config.frequencyMismatchTolerance = 0.02;
        config.rejectFrequencyMismatch = true;
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
    case 'input_noise'
        config.version = '0.3.0';
        config.referencePlane = ...
            'AD677 external board input; physical board/ADC-pin plane unverified';
        config.sampleRate = 100e6;
        config.noiseBandHz = [1, 10e3];
        config.noiseLimitNvPerSqrtHz = NaN;
        config.welchSegmentCount = 1;
        config.welchOverlapRatio = 0;
        config.welchNfft = 131072;
        config.samplesIncludeHold = true;
        config.inputTermination = 'not confirmed';
        config.formalConditionSource = 'No approved AD677 noise limit supplied';
        config.noiseCalibration = localNoiseCalibration();
        config.noiseCalibrationSource = ...
            'Fixed in 677_hy/private/ad677Config.m; noise uses slope only';
        config.picoFpgaGain = 128;
        config.picoAsdCheckHz = 1;
        config.picoWelch = struct('targetResolutionHz', 0.2, ...
            'overlapRatio', 0.5, 'windowType', 'hann');
        config.picoDacCalibration = struct( ...
            'device', 'DA9726', 'channel', 'DAC1_JG18', ...
            'slopeVPerCode', 1.01451391294771e-4, ...
            'unit', 'V/code', 'configurationStatus', 'fixed', ...
            'source', ['Fixed DA9726 JG18 calibration; ' ...
                'no DAC result CSV lookup']);
    otherwise
        error('ad677:UnknownAnalysis', ...
            '不支持的 AD677 分析类型：%s。', analysisId);
end
end

function rows = localNoiseCalibration()
% Noise conversion removes the mean, so amplitude-fit intercepts are unused.
template = struct('device', 'AD677', 'channel', '', ...
    'slopeVPerCode', NaN, 'interceptV', NaN, 'fitR2', NaN, ...
    'calibrationFrequencyHz', NaN, 'pointCount', NaN, ...
    'unit', 'V/code', 'configurationStatus', 'fixed', ...
    'sourceDocument', 'User-fixed AD677 noise calibration', ...
    'sourceSection', '677_hy/private/ad677Config.m', ...
    'definition', 'InputNoiseV=(Code-mean(Code))*slopeVPerCode');
rows = repmat(template, 2, 1);
rows(1).channel = '677_1';
rows(1).slopeVPerCode = 1.536050e-4;
rows(2).channel = '677_2';
rows(2).slopeVPerCode = 1.695154e-4;
end

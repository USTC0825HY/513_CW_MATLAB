function config = da9726Config(analysisId)
%DA9726CONFIG Fixed DA9726 CW_513_ANALYSIS configuration.
config = struct();
config.deviceId = 'DA9726';
% Keep the published calibration row as traceability metadata.  The noise
% entry does not consume it; scale fitting uses the selected MAT captures.
config.reportCalibration = converter.calibration.reportCalibration('DA9726');
config.analysisId = lower(char(analysisId));
config.version = '0.1.0';
config.releaseReady = true;
config.dataFolder = '';
config.outputFolder = '';
config.filePattern = '*.mat';
config.inputFiles = {};
config.dataVariables = {};
config.hardwareGain = 100;
config.removeMean = true;
config.sampleRate = 250e3;
config.dacBits = 16;
config.dacCodeBits = config.dacBits;
% Generic defaults used by analyses that do not consume DAC code labels.
config.codeNameFormat = 'signed_decimal';
config.codeVppDefinition = 'twice_abs_signed_code';
config.toneFrequencyHz = 1e3;
config.minimumFitR2 = 0.98;
config.minimumCodeVpp = 512;
config.maximumCodeVpp = 0.90 * 2^config.dacBits;
config.targetResolutionHz = 0.2;
config.overlapRatio = 0.5;
config.windowType = 'hann';
config.minimumAsdSegmentCount = 4;
config.maximumAsdBinRelativeError = 0.25;
config.asdCheckHz = 1;
config.asdLimit_uVPerSqrtHz = 75;
config.integratedBandHz = [1e3, 100e3];
config.integratedLimit_uVrms = 120;
config.asdOnly = false;
config.minimumIsolationDb = 40;
config.formalEnabled = false;
config.formalLimitation = '采集负载/参考面条件未完整记录';
config.referencePlane = 'DA9726 connector output';
config.calibrationSource = ...
    'PicoScope MAT voltage divided by the configured hardwareGain';
config.requirementAsdId = 'DL-CW-DAC-ASD-1HZ';
config.requirementIntegratedId = '';
config.requirementSourceDocument = '待随测试批次固化';
config.requirementSourceSha256 = '';
switch config.analysisId
    case 'scale'
        % The current DAC1_JG18 campaign stores unsigned 16-bit codes as
        % hexadecimal CODE/COADE tokens and drives a 1.001 MHz sine.  These
        % values reproduce the audited 2026-08-20 scale run; each MAT still
        % supplies its actual sample rate through Tinterval.
        config.version = '0.1.1';
        config.sampleRate = 39062499.4784597;
        config.sampleRateSource = ...
            'PicoScope MAT Tinterval; configured value from DAC1_JG18 2026-08-20 campaign';
        config.codeNameFormat = 'hex_unsigned';
        config.codeVppDefinition = 'raw_unsigned_code';
        config.codeConversionRule = ...
            'CODE/COADE token is unsigned 16-bit hexadecimal; signed form is traceability only';
        config.toneFrequencyHz = 1001000;
    case 'noise'
        % Each PicoScope MAT supplies its own Tinterval (or fs).  The
        % generic sampleRate field is retained only for compatibility and
        % must not be read as the measured rate of a particular file.
        config.sampleRateSource = ...
            '每个PicoScope MAT优先读取Tinterval，缺失时读取fs';
    case 'isolation'
        config.version = '0.2.0';
        config.hardwareGain = 1;
        config.measurementCondition = ...
            'PicoScope输入端直接测量；无外部放大；输入阻抗和探头倍率未记录';
        config.referencePlane = config.measurementCondition;
        config.simpleIsolationSelection = true;
        config.autoDetectDrive = false;
        config.autoDriveMinimumSeparationDb = 10;
        config.frequencySearchFraction = 0.01;
        config.formalEnabled = false;
        config.formalLimitation = 'PicoScope输入阻抗和探头倍率未记录';
    otherwise
        error('cw513:UnknownAnalysis', '不支持的DA9726分析类型：%s', analysisId);
end
end

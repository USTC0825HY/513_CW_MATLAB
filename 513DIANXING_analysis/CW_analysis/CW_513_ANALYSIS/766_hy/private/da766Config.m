function config = da766Config(analysisId)
%DA766CONFIG Fixed DA766 CW_513_ANALYSIS configuration.
config = struct();
config.deviceId = 'DA766';
config.analysisId = lower(char(analysisId));
config.version = '0.1.0';
config.releaseReady = true;
config.dataFolder = '';
config.outputFolder = '';
config.filePattern = '*.mat';
config.inputFiles = {};
config.dataVariables = {};
config.hardwareGain = 1;
config.removeMean = true;
config.sampleRate = 250e3; % Compatibility reference only; MAT supplies the measured rate.
config.sampleRateSource = 'MAT Tinterval/fs; configured rate is compatibility metadata only';
config.dacBits = 16;
config.dacCodeBits = config.dacBits;
config.formalEnabled = false;
config.formalLimitation = 'DA766需求版本存在冲突，采集条件需复核';
config.referencePlane = 'DA766 output; acquisition condition to be verified';
config.calibrationSource = ...
    'PicoScope MAT voltage divided by the configured hardwareGain';
switch config.analysisId
    case 'scale'
        config.codeNameFormat = 'signed_decimal';
        config.codeVppDefinition = 'twice_abs_signed_code';
        config.toneFrequencyHz = 1e3;
        config.minimumFitR2 = 0.98;
        config.minimumCodeVpp = 512;
        config.maximumCodeVpp = 0.90 * 2^config.dacBits;
    case 'noise'
        config.hardwareGain = 100;
        % Frequency-bin spacing; segment count and actual bin coverage are
        % checked separately. This does not guarantee statistical precision.
        config.targetResolutionHz = 0.2;
        config.overlapRatio = 0.5;
        config.windowType = 'hann';
        config.minimumAsdSegmentCount = 4;
        config.maximumAsdBinRelativeError = 0.25;
        config.asdCheckHz = 1;
        config.asdLimit_uVPerSqrtHz = 12;
        config.integratedBandHz = [1e3, 100e3];
        config.integratedLimit_uVrms = 1000;
        config.asdOnly = false;
        config.requirementAsdId = 'DA766-ASD-1HZ-待复核';
        config.requirementIntegratedId = 'DA766-INTEGRATED-1K-100K-待复核';
        config.requirementSourceDocument = '需求版本冲突，待复核';
        config.requirementSourceSha256 = '';
    case 'isolation'
        config.minimumFitR2 = 0.98;
        config.minimumIsolationDb = 40;
    case 'scale_hex'
        config = da766Config('scale');
        config.version = '0.1.1';
        config.codeNameFormat = 'hex_unsigned';
        config.codeVppDefinition = 'twice_abs_signed_code';
        config.codeConversionRule = 'raw 16-bit hex >= 0x8000: signed = raw - 0x10000; otherwise signed = raw';
        config.toneFrequencyHz = 1525;
        config.maximumCodeVpp = 2^16;
        config.referencePlane = 'DA766 output; actual PicoScope channel recorded per measurement; termination not recorded';
        config.calibrationSource = 'PicoScope MAT waveform/Tinterval; hex code token interpreted as unsigned 16-bit';
    otherwise
        error('cw513:UnknownAnalysis', '不支持的DA766分析类型：%s', analysisId);
end
end

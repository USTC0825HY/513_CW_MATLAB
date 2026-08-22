function config = da9726Config(analysisId)
%DA9726CONFIG Fixed DA9726 CW_513_ANALYSIS configuration.
config = struct();
config.deviceId = 'DA9726';
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
config.sampleRate = 250e3;
config.dacBits = 16;
config.dacCodeBits = config.dacBits;
% Default legacy-compatible interpretation.  Captures whose file names are
% hexadecimal unsigned DAC setpoints may override these two fields at run
% time without changing the default behavior for decimal signed captures.
config.codeNameFormat = 'signed_decimal';
config.codeVppDefinition = 'twice_abs_signed_code';
config.adcBits = config.dacBits;
config.adcCodeFormat = 'voltage';
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
config.asdOnly = true;
config.minimumIsolationDb = 40;
config.formalEnabled = false;
config.formalLimitation = '采集负载/参考面条件未完整记录';
config.referencePlane = 'DA9726 connector output';
config.calibrationSource = 'PicoScope MAT voltage; hardwareGain=1';
config.requirementAsdId = 'DL-CW-DAC-ASD-1HZ';
config.requirementIntegratedId = '';
config.requirementSourceDocument = '待随测试批次固化';
config.requirementSourceSha256 = '';
if ~ismember(config.analysisId, {'scale','noise','isolation'})
    error('cw513:UnknownAnalysis', '不支持的DA9726分析类型：%s', analysisId);
end
end

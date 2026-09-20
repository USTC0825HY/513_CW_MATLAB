function [results, details] = calculateIsolation(adcCodeList, channelNames, ...
        drivenChannel, config)
%CALCULATEISOLATION Calculate same-frequency crosstalk isolation.

requiredFields = {'sampleRate', 'adcBits', 'isolationFrequencyHz', ...
    'frequencyMismatchTolerance', 'minimumIsolationDb', 'fitCycles', ...
    'minimumFitSamples'};
converter.runtime.validateConfig(config, requiredFields);
channelNames = string(channelNames(:));
drivenChannel = string(drivenChannel);
fileCount = numel(adcCodeList);
if numel(unique(channelNames)) ~= fileCount
    error('converter:adc:DuplicateChannels', ...
        '存在重复通道文件，请确保每个通道只选择一个 CSV。');
end
drivenMask = channelNames == drivenChannel;
if nnz(drivenMask) ~= 1
    error('converter:adc:DrivenChannelMissing', ...
        '必须且只能找到一个激励通道 %s。', char(drivenChannel));
end
quietMask = ~drivenMask;
if ~any(quietMask)
    error('converter:adc:QuietChannelMissing', '没有安静通道数据，无法计算隔离度。');
end

drivenIndex = find(drivenMask, 1);
drivenFrequencyHz = converter.adc.estimateFrequency( ...
    adcCodeList{drivenIndex}, config.sampleRate);
drivenFrequencyHz = converter.adc.refineSineFrequency( ...
    adcCodeList{drivenIndex}, drivenFrequencyHz, config.sampleRate, ...
    config.fitCycles, config.minimumFitSamples);
frequencyMismatchFlag = ...
    abs(drivenFrequencyHz - config.isolationFrequencyHz) / ...
    max(config.isolationFrequencyHz, eps) > config.frequencyMismatchTolerance;
codePp = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);
fitCondition = NaN(fileCount, 1);
fitConfig = config;
fitConfig.fitMode = 'known';
fitConfig.knownFrequencyHz = drivenFrequencyHz;
for fileIndex = 1:fileCount
    metrics = converter.adc.analyzeDynamicMetrics(adcCodeList{fileIndex}, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    fitCondition(fileIndex) = metrics.fit.designCondition;
end

drivenCodePp = codePp(drivenMask);
quietChannels = channelNames(quietMask);
quietCodePp = codePp(quietMask);
isolationDb = 20 * log10(drivenCodePp ./ quietCodePp);
thresholdMet = isolationDb >= config.minimumIsolationDb;
minimumDrivenFitR2 = 0.98;
if isfield(config, 'minimumDrivenFitR2')
    minimumDrivenFitR2 = config.minimumDrivenFitR2;
end
drivenCode = adcCodeList{drivenIndex};
fullScalePeakCode = 2^(config.adcBits - 1);
drivenClipping = any(drivenCode <= -fullScalePeakCode | ...
    drivenCode >= fullScalePeakCode - 1);
drivenValid = ~frequencyMismatchFlag && ~drivenClipping && ...
    fitR2(drivenMask) >= minimumDrivenFitR2 && ...
    fitCondition(drivenMask) < 1e8 && isfinite(drivenCodePp) && drivenCodePp > 0;
measurementValid = drivenValid & isfinite(isolationDb) & ...
    quietCodePp > 0 & fitCondition(quietMask) < 1e8;
referencePlane = "未提供";
if isfield(config, 'referencePlane') && ~isempty(config.referencePlane)
    referencePlane = string(config.referencePlane);
end
% Code ratios are not input-voltage isolation unless channel gains are
% independently shown to be equivalent. A recorded reference plane alone
% does not establish that equivalence.
referenceConfirmed = isfield(config, 'isolationReferenceConfirmed') && ...
    isequal(config.isolationReferenceConfirmed, true) && ...
    strlength(strtrim(referencePlane)) > 0 && referencePlane ~= "未提供";
formalEnabled = isfield(config, 'formalEnabled') && isequal(config.formalEnabled, true);
pass = thresholdMet & measurementValid & referenceConfirmed & formalEnabled;
quietCount = nnz(quietMask);
results = table( ...
    repmat(drivenChannel, quietCount, 1), quietChannels, ...
    repmat(config.isolationFrequencyHz, quietCount, 1), ...
    repmat(drivenFrequencyHz, quietCount, 1), ...
    repmat(drivenFrequencyHz - config.isolationFrequencyHz, quietCount, 1), ...
    repmat(100 * (drivenFrequencyHz - config.isolationFrequencyHz) / ...
    max(config.isolationFrequencyHz, eps), quietCount, 1), ...
    repmat(frequencyMismatchFlag, quietCount, 1), ...
    repmat(drivenCodePp, quietCount, 1), quietCodePp, isolationDb, ...
    fitR2(quietMask), fitResidualRmsCode(quietMask), pass, ...
    'VariableNames', {'DrivenChannel', 'QuietChannel', 'ExpectedFrequencyHz', ...
    'FrequencyHz', 'FrequencyErrorHz', 'FrequencyErrorPercent', ...
    'FrequencyMismatchFlag', 'DrivenCodePp', 'QuietCodePp', 'IsolationDb', ...
        'QuietFitR2', 'QuietResidualRmsCode', 'Pass'});
results.ThresholdMet = thresholdMet;
results.MeasurementValid = measurementValid;
results.DrivenFitR2 = repmat(fitR2(drivenMask), quietCount, 1);
results.DrivenClippingFlag = repmat(drivenClipping, quietCount, 1);
results.RatioBasis = repmat("ADC code amplitude ratio; channel gain not corrected", quietCount, 1);
results.ReferencePlane = repmat(referencePlane, quietCount, 1);
results.FormalConclusion = repmat("暂不能判定", quietCount, 1);
formalMask = measurementValid & referenceConfirmed & formalEnabled;
results.FormalConclusion(formalMask & thresholdMet) = "满足";
results.FormalConclusion(formalMask & ~thresholdMet) = "不满足";
details = struct('drivenFrequencyHz', drivenFrequencyHz, ...
    'minimumIsolationDb', config.minimumIsolationDb, ...
    'worstIsolationDb', min(isolationDb));
end


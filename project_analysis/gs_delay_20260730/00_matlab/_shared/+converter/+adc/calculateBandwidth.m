function [results, details] = calculateBandwidth(adcCodeList, fileNames, ...
        fileFrequencyHz, config)
%CALCULATEBANDWIDTH Calculate fitted amplitude response and -3 dB bandwidth.

requiredFields = {'sampleRate', 'adcBits', 'minimumFitR2', ...
    'referencePointCount', 'frequencyMismatchTolerance', 'fitCycles', ...
    'minimumFitSamples', 'clippingMarginCode'};
converter.runtime.validateConfig(config, requiredFields);
fileCount = numel(fileNames);
frequencyHz = NaN(fileCount, 1);
codePp = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);
frequencyMismatchFlag = false(fileCount, 1);
clippingFlag = false(fileCount, 1);
fullScalePeakCode = 2^(config.adcBits - 1);

for fileIndex = 1:fileCount
    adcCode = adcCodeList{fileIndex};
    frequencyHz(fileIndex) = converter.adc.estimateFrequency( ...
        adcCode, config.sampleRate);
    frequencyHz(fileIndex) = converter.adc.refineSineFrequency( ...
        adcCode, frequencyHz(fileIndex), config.sampleRate, ...
        config.fitCycles, config.minimumFitSamples);
    if isfinite(fileFrequencyHz(fileIndex))
        fftLength = min(128 * 1024, numel(adcCode));
        frequencyResolutionHz = config.sampleRate / fftLength;
        allowedFrequencyErrorHz = max( ...
            config.frequencyMismatchTolerance * fileFrequencyHz(fileIndex), ...
            2 * frequencyResolutionHz);
        frequencyMismatchFlag(fileIndex) = ...
            abs(frequencyHz(fileIndex) - fileFrequencyHz(fileIndex)) > ...
            allowedFrequencyErrorHz;
    end
    fitConfig = config;
    fitConfig.fitMode = 'known';
    fitConfig.knownFrequencyHz = frequencyHz(fileIndex);
    metrics = converter.adc.analyzeDynamicMetrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    clippingFlag(fileIndex) = ...
        min(adcCode) <= -fullScalePeakCode + config.clippingMarginCode || ...
        max(adcCode) >= fullScalePeakCode - 1 - config.clippingMarginCode;
end

[fileFrequencyHz, sortIndex] = sort(fileFrequencyHz(:));
frequencyHz = frequencyHz(sortIndex);
fileNames = fileNames(sortIndex);
codePp = codePp(sortIndex);
fitR2 = fitR2(sortIndex);
fitResidualRmsCode = fitResidualRmsCode(sortIndex);
frequencyMismatchFlag = frequencyMismatchFlag(sortIndex);
clippingFlag = clippingFlag(sortIndex);
validForBandwidth = isfinite(codePp) & codePp > 0 & ...
    isfinite(fitR2) & fitR2 >= config.minimumFitR2 & ...
    isfinite(frequencyHz) & isfinite(fileFrequencyHz) & ...
    fileFrequencyHz > 0 & ~clippingFlag;
if isfield(config, 'rejectFrequencyMismatch') && config.rejectFrequencyMismatch
    validForBandwidth = validForBandwidth & ~frequencyMismatchFlag;
end
if nnz(validForBandwidth) < 2
    error('converter:adc:InsufficientBandwidthPoints', ...
        '有效频率点少于 2 个，无法计算带宽。');
end

if isfield(config, 'bandwidthFrequencySource') && ...
        strcmpi(config.bandwidthFrequencySource, 'file')
    validFrequencyHz = fileFrequencyHz(validForBandwidth);
else
    validFrequencyHz = frequencyHz(validForBandwidth);
end
validCodePp = codePp(validForBandwidth);
if numel(validCodePp) < config.referencePointCount
    error('converter:adc:InsufficientReferencePoints', ...
        '有效频率点少于参考点数量 %d。', config.referencePointCount);
end
referenceValidIndices = 1:config.referencePointCount;
referenceCodePp = median(validCodePp(referenceValidIndices));
referencePoint = false(fileCount, 1);
validIndices = find(validForBandwidth);
referencePoint(validIndices(referenceValidIndices)) = true;
relativeDb = NaN(fileCount, 1);
relativeDb(validForBandwidth) = 20 * log10(validCodePp / referenceCodePp);
bandwidth3dBHz = converter.adc.findThreeDbCrossing( ...
    validFrequencyHz, relativeDb(validForBandwidth));
frequencyErrorHz = frequencyHz - fileFrequencyHz;
frequencyErrorPercent = 100 * frequencyErrorHz ./ fileFrequencyHz;

results = table(string(fileNames(:)), fileFrequencyHz, frequencyHz, ...
    frequencyErrorHz, frequencyErrorPercent, frequencyMismatchFlag, ...
    clippingFlag, codePp, relativeDb, fitR2, fitResidualRmsCode, ...
    validForBandwidth, referencePoint, repmat(bandwidth3dBHz, fileCount, 1), ...
    'VariableNames', {'FileName', 'FileFrequencyHz', 'FrequencyHz', ...
    'FrequencyErrorHz', 'FrequencyErrorPercent', 'FrequencyMismatchFlag', ...
    'ClippingFlag', 'CodePp', 'RelativeDb', 'FitR2', ...
    'FitResidualRmsCode', 'ValidForBandwidth', 'ReferencePoint', ...
    'Bandwidth3dBHz'});
details = struct('bandwidth3dBHz', bandwidth3dBHz, ...
    'referenceCodePp', referenceCodePp);
end


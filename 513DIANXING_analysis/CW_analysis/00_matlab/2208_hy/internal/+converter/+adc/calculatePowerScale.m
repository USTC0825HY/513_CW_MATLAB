function [results, details] = calculatePowerScale(adcCodeList, fileNames, ...
        inputPowerDbm, channelNames, config)
%CALCULATEPOWERSCALE Fit input dBm to ADC RMS dBFS response.

requiredFields = {'sampleRate', 'adcBits', 'testFrequencyHz', ...
    'frequencyMismatchTolerance', 'powerRangeDbm', 'clippingThreshold', ...
    'clippingFractionLimit', 'plateauChangeThreshold', 'fitCycles', ...
    'minimumFitSamples'};
converter.runtime.validateConfig(config, requiredFields);
fileCount = numel(fileNames);
channelNames = string(channelNames(:));
adcFullScalePeakCode = 2^(config.adcBits - 1);
codePp = NaN(fileCount, 1);
codeRms = NaN(fileCount, 1);
codeRmsDbfs = NaN(fileCount, 1);
peakCode = NaN(fileCount, 1);
valleyCode = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);
nearFullScaleFraction = NaN(fileCount, 1);
measuredFrequencyHz = NaN(fileCount, 1);
frequencyMismatchFlag = false(fileCount, 1);

for fileIndex = 1:fileCount
    adcCode = adcCodeList{fileIndex};
    measuredFrequencyHz(fileIndex) = converter.adc.estimateFrequency( ...
        adcCode, config.sampleRate);
    frequencyMismatchFlag(fileIndex) = ...
        abs(measuredFrequencyHz(fileIndex) - config.testFrequencyHz) / ...
        max(config.testFrequencyHz, eps) > config.frequencyMismatchTolerance;
    fitConfig = config;
    fitConfig.fitMode = 'known';
    fitConfig.knownFrequencyHz = measuredFrequencyHz(fileIndex);
    metrics = converter.adc.analyzeDynamicMetrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    codeRms(fileIndex) = codePp(fileIndex) / (2 * sqrt(2));
    codeRmsDbfs(fileIndex) = 20 * log10( ...
        codeRms(fileIndex) / adcFullScalePeakCode);
    peakCode(fileIndex) = metrics.fit.peakCode;
    valleyCode(fileIndex) = metrics.fit.valleyCode;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    nearFullScaleFraction(fileIndex) = mean( ...
        abs(adcCode) >= config.clippingThreshold * adcFullScalePeakCode);
end

[inputPowerDbm, sortIndex] = sort(inputPowerDbm(:));
fileNames = fileNames(sortIndex);
channelNames = channelNames(sortIndex);
codePp = codePp(sortIndex);
codeRms = codeRms(sortIndex);
codeRmsDbfs = codeRmsDbfs(sortIndex);
peakCode = peakCode(sortIndex);
valleyCode = valleyCode(sortIndex);
fitR2 = fitR2(sortIndex);
fitResidualRmsCode = fitResidualRmsCode(sortIndex);
nearFullScaleFraction = nearFullScaleFraction(sortIndex);
measuredFrequencyHz = measuredFrequencyHz(sortIndex);
frequencyMismatchFlag = frequencyMismatchFlag(sortIndex);

clippingFlag = nearFullScaleFraction > config.clippingFractionLimit;
plateauFlag = false(fileCount, 1);
for fileIndex = 2:fileCount
    relativeChange = abs(codePp(fileIndex) - codePp(fileIndex - 1)) / ...
        max(codePp(fileIndex - 1), eps);
    plateauFlag(fileIndex) = relativeChange <= config.plateauChangeThreshold;
end
inSpecifiedRange = inputPowerDbm >= config.powerRangeDbm(1) & ...
    inputPowerDbm <= config.powerRangeDbm(2);
calibrationIncluded = inSpecifiedRange & ~clippingFlag & ~plateauFlag;
if nnz(calibrationIncluded) < 2
    error('converter:adc:InsufficientCalibrationPoints', ...
        '正式范围内有效标定点少于 2 个。');
end

coefficient = polyfit(inputPowerDbm(calibrationIncluded), ...
    codeRmsDbfs(calibrationIncluded), 1);
predictedDbfs = polyval(coefficient, inputPowerDbm);
calibrationResidualDb = codeRmsDbfs - predictedDbfs;
measuredForFit = codeRmsDbfs(calibrationIncluded);
residualForFit = calibrationResidualDb(calibrationIncluded);
calibrationR2 = 1 - sum(residualForFit.^2) / ...
    max(sum((measuredForFit - mean(measuredForFit)).^2), eps);

uniqueChannels = unique(channelNames);
uniqueChannels(uniqueChannels == "") = [];
if isscalar(uniqueChannels)
    channelName = uniqueChannels(1);
else
    channelName = "Unknown";
    warning('converter:adc:AmbiguousChannel', ...
        '无法确定唯一 ADC 通道，输出通道标记为 Unknown。');
end

results = table( ...
    repmat(channelName, fileCount, 1), string(fileNames(:)), ...
    inputPowerDbm, repmat(config.testFrequencyHz, fileCount, 1), ...
    measuredFrequencyHz, measuredFrequencyHz - config.testFrequencyHz, ...
    100 * (measuredFrequencyHz - config.testFrequencyHz) / ...
    max(config.testFrequencyHz, eps), frequencyMismatchFlag, ...
    codePp, codeRms, codeRmsDbfs, peakCode, valleyCode, fitR2, ...
    fitResidualRmsCode, nearFullScaleFraction, clippingFlag, plateauFlag, ...
    inSpecifiedRange, calibrationIncluded, calibrationResidualDb, ...
    repmat(coefficient(1), fileCount, 1), ...
    repmat(coefficient(2), fileCount, 1), ...
    repmat(calibrationR2, fileCount, 1), ...
    'VariableNames', {'Channel', 'FileName', 'InputPowerDbm', ...
    'ExpectedFrequencyHz', 'FrequencyHz', 'FrequencyErrorHz', ...
    'FrequencyErrorPercent', 'FrequencyMismatchFlag', 'CodePp', ...
    'CodeRms', 'CodeRmsDbfs', 'PeakCode', 'ValleyCode', 'FitR2', ...
    'FitResidualRmsCode', 'NearFullScaleFraction', 'ClippingFlag', ...
    'PlateauFlag', 'InSpecifiedRange', 'CalibrationIncluded', ...
    'CalibrationResidualDb', 'CalibrationSlopeDbPerDbm', ...
    'CalibrationInterceptDb', 'CalibrationR2'});
details = struct('coefficient', coefficient, 'calibrationR2', calibrationR2, ...
    'channelName', channelName, 'adcFullScalePeakCode', adcFullScalePeakCode);
end


function [results, details] = calculateInlDnl(adcCodeList, fileNames, ...
        channelName, config)
%CALCULATEINLDNL Calculate multi-record sine-code-density DNL and INL.
%   Each record is fitted independently. The pooled theoretical histogram
%   is the sample-weighted mixture of accepted record-specific sine models.

requiredFields = {'sampleRate', 'adcBits', 'marginCode', 'minimumFitR2', ...
    'frequencyRefinementCycles', 'frequencyRefinementMinimumSamples', ...
    'minimumValidCaptureFraction', 'glitchSigmaMultiplier', ...
    'glitchMinimumThresholdCode', 'maximumGlitchFraction', ...
    'clippingMarginCode', 'recordsAreSampleContiguous'};
converter.runtime.validateConfig(config, requiredFields);
if isempty(adcCodeList)
    error('converter:adc:NoInlDnlData', '没有用于 INL/DNL 分析的数据。');
end
if numel(adcCodeList) ~= numel(fileNames)
    error('converter:adc:InlDnlFileCountMismatch', ...
        'ADC 数据记录数与文件名数量不一致。');
end

fullScalePeak = 2^(config.adcBits - 1);
codeMinFull = -fullScalePeak;
codeMaxFull = fullScalePeak - 1;
fileCount = numel(adcCodeList);
sampleCount = zeros(fileCount, 1);
coarseFrequencyHz = NaN(fileCount, 1);
frequencyLevelDb = NaN(fileCount, 1);
refinedFrequencyHz = NaN(fileCount, 1);
amplitudeCode = NaN(fileCount, 1);
offsetCode = NaN(fileCount, 1);
phaseRadians = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
residualRmsCode = NaN(fileCount, 1);
maximumAbsoluteResidualCode = NaN(fileCount, 1);
robustResidualSigmaCode = NaN(fileCount, 1);
glitchThresholdCode = NaN(fileCount, 1);
glitchCount = zeros(fileCount, 1);
glitchFraction = zeros(fileCount, 1);
clippedSampleCount = zeros(fileCount, 1);
maximumAbsoluteSecondDifferenceCode = NaN(fileCount, 1);
firstCode = NaN(fileCount, 1);
lastCode = NaN(fileCount, 1);
usedForInlDnl = false(fileCount, 1);
captureStatus = strings(fileCount, 1);

for fileIndex = 1:fileCount
    adcCode = finiteColumn(adcCodeList{fileIndex});
    if numel(adcCode) < 16
        error('converter:adc:InsufficientSamples', ...
            '文件 %s 的有效 ADC 数据点数不足。', fileNames{fileIndex});
    end
    sampleCount(fileIndex) = numel(adcCode);
    firstCode(fileIndex) = adcCode(1);
    lastCode(fileIndex) = adcCode(end);
    if numel(adcCode) >= 3
        maximumAbsoluteSecondDifferenceCode(fileIndex) = ...
            max(abs(diff(adcCode, 2)));
    end

    [coarseFrequencyHz(fileIndex), frequencyLevelDb(fileIndex)] = ...
        converter.adc.estimateFrequency(adcCode, config.sampleRate);
    refinedFrequencyHz(fileIndex) = converter.adc.refineSineFrequency( ...
        adcCode, coarseFrequencyHz(fileIndex), config.sampleRate, ...
        config.frequencyRefinementCycles, ...
        config.frequencyRefinementMinimumSamples);
    fit = converter.adc.fitSine( ...
        adcCode, refinedFrequencyHz(fileIndex), config.sampleRate);
    amplitudeCode(fileIndex) = fit.amplitudeCode;
    offsetCode(fileIndex) = fit.offsetCode;
    phaseRadians(fileIndex) = fit.phaseRadians;
    fitR2(fileIndex) = fit.r2;
    residualRmsCode(fileIndex) = fit.residualRmsCode;
    maximumAbsoluteResidualCode(fileIndex) = ...
        fit.maximumAbsoluteResidualCode;

    residualCode = fit.fitCode - fit.fittedCode;
    residualMedian = median(residualCode);
    robustResidualSigmaCode(fileIndex) = 1.4826 * ...
        median(abs(residualCode - residualMedian));
    glitchThresholdCode(fileIndex) = max( ...
        config.glitchMinimumThresholdCode, ...
        config.glitchSigmaMultiplier * ...
        max(robustResidualSigmaCode(fileIndex), eps));
    glitchCount(fileIndex) = sum( ...
        abs(residualCode - residualMedian) > glitchThresholdCode(fileIndex));
    glitchFraction(fileIndex) = glitchCount(fileIndex) / sampleCount(fileIndex);
    clippedSampleCount(fileIndex) = sum( ...
        adcCode <= codeMinFull + config.clippingMarginCode | ...
        adcCode >= codeMaxFull - config.clippingMarginCode);

    failureReasons = strings(3, 1);
    failureCount = 0;
    if ~isfinite(fitR2(fileIndex)) || fitR2(fileIndex) < config.minimumFitR2
        failureCount = failureCount + 1;
        failureReasons(failureCount) = "FitR2BelowMinimum";
    end
    if glitchFraction(fileIndex) > config.maximumGlitchFraction
        failureCount = failureCount + 1;
        failureReasons(failureCount) = "ResidualGlitchDetected";
    end
    if clippedSampleCount(fileIndex) > 0
        failureCount = failureCount + 1;
        failureReasons(failureCount) = "ClippingDetected";
    end
    usedForInlDnl(fileIndex) = failureCount == 0;
    if usedForInlDnl(fileIndex)
        captureStatus(fileIndex) = "OK";
    else
        captureStatus(fileIndex) = strjoin(failureReasons(1:failureCount), ";");
    end
end

validCaptureCount = sum(usedForInlDnl);
validCaptureFraction = validCaptureCount / fileCount;
if validCaptureCount > 0
    sharedFrequencyHz = median(refinedFrequencyHz(usedForInlDnl));
else
    sharedFrequencyHz = median(refinedFrequencyHz, 'omitnan');
end
frequencyDriftHz = refinedFrequencyHz - sharedFrequencyHz;
[boundaryPhaseErrorRadians, boundaryCodeJump] = boundaryDiagnostics( ...
    phaseRadians, firstCode, lastCode, sampleCount, sharedFrequencyHz, config);

captureTable = table(string(fileNames(:)), sampleCount, coarseFrequencyHz, ...
    refinedFrequencyHz, frequencyDriftHz, amplitudeCode, offsetCode, ...
    phaseRadians, fitR2, residualRmsCode, maximumAbsoluteResidualCode, ...
    robustResidualSigmaCode, glitchThresholdCode, glitchCount, ...
    glitchFraction, clippedSampleCount, ...
    maximumAbsoluteSecondDifferenceCode, boundaryPhaseErrorRadians, ...
    boundaryCodeJump, usedForInlDnl, captureStatus, ...
    'VariableNames', {'FileName','SampleCount','CoarseFrequencyHz', ...
    'RefinedFrequencyHz','FrequencyDriftHz','AmplitudeCode','OffsetCode', ...
    'PhaseRadians','FitR2','ResidualRmsCode','MaxAbsResidualCode', ...
    'RobustResidualSigmaCode','GlitchThresholdCode','GlitchCount', ...
    'GlitchFraction','ClippedSampleCount','MaxAbsSecondDifferenceCode', ...
    'BoundaryPhaseErrorRadians','BoundaryCodeJump','UsedForInlDnl','Status'});

totalSamples = sum(sampleCount);
validSamples = 0;
codeMin = NaN;
codeMax = NaN;
coverageRatio = NaN;
maxAbsDnl = NaN;
maxAbsInl = NaN;
maxAbsInlMid = NaN;
curveTable = emptyCurveTable();
statusText = "OK";

if validCaptureCount == 0 || ...
        validCaptureFraction < config.minimumValidCaptureFraction
    statusText = "CaptureQualityBelowMinimum";
else
    validAmplitude = amplitudeCode(usedForInlDnl);
    validOffset = offsetCode(usedForInlDnl);
    lowerCodeLimit = ceil(validOffset - validAmplitude + config.marginCode);
    upperCodeLimit = floor(validOffset + validAmplitude - config.marginCode);
    codeMin = max(codeMinFull, max(lowerCodeLimit));
    codeMax = min(codeMaxFull, min(upperCodeLimit));
    if codeMax <= codeMin
        error('converter:adc:InvalidInlDnlRange', ...
            '所有有效记录的公共正弦码值范围为空，请检查幅度、偏置或 marginCode。');
    end

    codeAxis = (codeMin:codeMax)';
    edges = (codeMin - 0.5):(codeMax + 0.5);
    measuredCounts = zeros(numel(codeAxis), 1);
    theoreticalCounts = zeros(numel(codeAxis), 1);
    for fileIndex = find(usedForInlDnl).'
        adcCode = finiteColumn(adcCodeList{fileIndex});
        adcCode = adcCode(adcCode >= codeMin & adcCode <= codeMax);
        recordValidSampleCount = numel(adcCode);
        validSamples = validSamples + recordValidSampleCount;
        measuredCounts = measuredCounts + histcounts(adcCode, edges)';

        recordProbability = sineCodeProbability( ...
            codeAxis, amplitudeCode(fileIndex), offsetCode(fileIndex));
        probabilitySum = sum(recordProbability);
        if probabilitySum <= 0
            error('converter:adc:InvalidTheoreticalProbability', ...
                '文件 %s 的理论正弦码概率无效。', fileNames{fileIndex});
        end
        theoreticalCounts = theoreticalCounts + recordValidSampleCount * ...
            recordProbability / probabilitySum;
    end
    if validSamples == 0 || sum(measuredCounts) == 0
        error('converter:adc:NoValidInlDnlCodes', ...
            '公共码值范围内没有有效样本，无法计算 INL/DNL。');
    end

    measuredProbability = measuredCounts / sum(measuredCounts);
    theoreticalProbability = theoreticalCounts / sum(theoreticalCounts);
    validProbability = theoreticalProbability > 1e-12;
    dnl = NaN(size(codeAxis));
    dnl(validProbability) = measuredProbability(validProbability) ./ ...
        theoreticalProbability(validProbability) - 1;
    dnlFinite = dnl(isfinite(dnl));
    if isempty(dnlFinite)
        error('converter:adc:NoFiniteDnl', '没有得到有限的 DNL 结果。');
    end
    dnlForCumulativeSum = dnl;
    dnlForCumulativeSum(~isfinite(dnlForCumulativeSum)) = 0;
    inlRaw = cumsum(dnlForCumulativeSum);
    baseline = polyfit(codeAxis, inlRaw, 1);
    inl = inlRaw - polyval(baseline, codeAxis);
    maxAbsDnl = max(abs(dnlFinite));
    maxAbsInl = max(abs(inl(isfinite(inl))));
    midMask = codeAxis > (-fullScalePeak / 2) & ...
        codeAxis < (fullScalePeak / 2) & isfinite(inl);
    if any(midMask)
        maxAbsInlMid = max(abs(inl(midMask)));
    end
    coverageRatio = sum(measuredCounts > 0) / numel(measuredCounts);
    curveTable = table(codeAxis, measuredCounts, theoreticalCounts, ...
        measuredProbability, theoreticalProbability, dnl, inl, ...
        'VariableNames', {'Code','MeasuredCount','TheoreticalCount', ...
        'MeasuredProbability','TheoreticalProbability','DNL_LSB','INL_LSB'});
end

[summaryAmplitudeCode, summaryOffsetCode, summaryFitR2, medianFitR2, ...
    summaryResidualRmsCode, summaryFrequencyLevelDb, frequencyStdHz] = ...
    summaryFitMetrics(usedForInlDnl, amplitudeCode, offsetCode, fitR2, ...
    residualRmsCode, frequencyLevelDb, refinedFrequencyHz);

calibrationReference = ...
    "ADC output code; no voltage calibration; full-chain sine-code-density";
formalConclusion = "暂不能判定";
inputSha256 = "See run_manifest.csv for one SHA-256 per input file";
results = table(string(channelName), config.sampleRate, ...
    calibrationReference, formalConclusion, inputSha256, fileCount, ...
    validCaptureCount, validCaptureFraction, totalSamples, validSamples, ...
    sharedFrequencyHz, frequencyStdHz, summaryFrequencyLevelDb, ...
    summaryAmplitudeCode, summaryOffsetCode, summaryFitR2, medianFitR2, ...
    summaryResidualRmsCode, sum(glitchCount), codeMin, codeMax, ...
    coverageRatio, maxAbsDnl, maxAbsInl, maxAbsInlMid, ...
    logical(config.recordsAreSampleContiguous), statusText, ...
    'VariableNames', {'Channel','FsHz','CalibrationReference', ...
    'FormalConclusion','InputSHA256','FileCount','ValidCaptureCount', ...
    'ValidCaptureFraction','TotalSamples','ValidSamples','FrequencyHz', ...
    'FrequencyStdHz','FrequencyLevelDb','FitAmplitudeCode','FitOffsetCode', ...
    'FitR2','MedianFitR2','FitResidualRmsCode','TotalGlitchSamples', ...
    'CodeMin','CodeMax','CoverageRatio','MaxAbsDNL_LSB','MaxAbsINL_LSB', ...
    'MaxAbsINLMid_LSB','RecordsAssumedContiguous','Status'});

details = struct('curveTable', curveTable, 'captureTable', captureTable, ...
    'frequencyHz', sharedFrequencyHz, 'fitR2', summaryFitR2, ...
    'maxAbsDnl', maxAbsDnl, 'maxAbsInl', maxAbsInl, ...
    'channelName', char(channelName), 'status', char(statusText), ...
    'validCaptureCount', validCaptureCount, 'fileCount', fileCount, ...
    'totalGlitchSamples', sum(glitchCount));
end

function adcCode = finiteColumn(adcCode)
adcCode = double(adcCode(:));
adcCode = adcCode(isfinite(adcCode));
end

function probability = sineCodeProbability(codeAxis, amplitudeCode, offsetCode)
lowerNormalizedCode = (codeAxis - 0.5 - offsetCode) / amplitudeCode;
upperNormalizedCode = (codeAxis + 0.5 - offsetCode) / amplitudeCode;
lowerNormalizedCode = max(-1, min(1, lowerNormalizedCode));
upperNormalizedCode = max(-1, min(1, upperNormalizedCode));
probability = (asin(upperNormalizedCode) - asin(lowerNormalizedCode)) / pi;
probability(probability < 0) = 0;
end

function [phaseError, codeJump] = boundaryDiagnostics(phaseRadians, ...
        firstCode, lastCode, sampleCount, frequencyHz, config)
fileCount = numel(phaseRadians);
phaseError = NaN(fileCount, 1);
codeJump = NaN(fileCount, 1);
if ~config.recordsAreSampleContiguous
    return;
end
for fileIndex = 2:fileCount
    expectedPhase = phaseRadians(fileIndex - 1) + ...
        2*pi*frequencyHz*sampleCount(fileIndex - 1)/config.sampleRate;
    phaseError(fileIndex) = wrapRadians(phaseRadians(fileIndex) - expectedPhase);
    codeJump(fileIndex) = firstCode(fileIndex) - lastCode(fileIndex - 1);
end
end

function [amplitude, offset, minimumR2, medianR2, residualRms, ...
        frequencyLevel, frequencyStd] = summaryFitMetrics(validMask, ...
        amplitudes, offsets, fitR2, residualRmsValues, frequencyLevels, ...
        frequencies)
if any(validMask)
    mask = validMask;
else
    mask = isfinite(fitR2);
end
amplitude = median(amplitudes(mask), 'omitnan');
offset = median(offsets(mask), 'omitnan');
minimumR2 = min(fitR2(mask), [], 'omitnan');
medianR2 = median(fitR2(mask), 'omitnan');
residualRms = max(residualRmsValues(mask), [], 'omitnan');
frequencyLevel = median(frequencyLevels(mask), 'omitnan');
frequencyStd = std(frequencies(mask), 'omitnan');
end

function curveTable = emptyCurveTable()
curveTable = table(zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    'VariableNames', {'Code','MeasuredCount','TheoreticalCount', ...
    'MeasuredProbability','TheoreticalProbability','DNL_LSB','INL_LSB'});
end

function wrappedRadians = wrapRadians(angleRadians)
wrappedRadians = mod(angleRadians + pi, 2*pi) - pi;
end

function [results, details] = calculateInlDnl(adcCodeList, fileNames, ...
        channelName, config)
%CALCULATEINLDNL Calculate sine-code-density DNL and INL.

requiredFields = {'sampleRate', 'adcBits', 'marginCode', 'minimumFitR2'};
converter.runtime.validateConfig(config, requiredFields);
if isempty(adcCodeList)
    error('converter:adc:NoInlDnlData', '没有用于 INL/DNL 分析的数据。');
end
firstCode = adcCodeList{1};
if numel(firstCode) < 16
    error('converter:adc:InsufficientSamples', '第一份 ADC 数据点数不足。');
end
[frequencyHz, frequencyLevelDb] = converter.adc.estimateFrequency( ...
    firstCode, config.sampleRate);
fit = converter.adc.fitSine(firstCode, frequencyHz, config.sampleRate);
fitAmplitudeCode = fit.amplitudeCode;
fitOffsetCode = fit.offsetCode;
fitR2 = fit.r2;
fitResidualRms = fit.residualRmsCode;

fullScalePeak = 2^(config.adcBits - 1);
codeMinFull = -fullScalePeak;
codeMaxFull = fullScalePeak - 1;
codeMin = max(codeMinFull, ...
    ceil(fitOffsetCode - fitAmplitudeCode + config.marginCode));
codeMax = min(codeMaxFull, ...
    floor(fitOffsetCode + fitAmplitudeCode - config.marginCode));
if codeMax <= codeMin
    error('converter:adc:InvalidInlDnlRange', ...
        '拟合正弦有效码值范围无效，请检查 ADC 配置或 marginCode。');
end

codeAxis = (codeMin:codeMax)';
edges = (codeMin - 0.5):(codeMax + 0.5);
counts = zeros(numel(codeAxis), 1);
totalSamples = 0;
validSamples = 0;
for fileIndex = 1:numel(adcCodeList)
    adcCode = adcCodeList{fileIndex};
    totalSamples = totalSamples + numel(adcCode);
    adcCode = adcCode(adcCode >= codeMin & adcCode <= codeMax);
    validSamples = validSamples + numel(adcCode);
    if ~isempty(adcCode)
        counts = counts + histcounts(adcCode, edges)';
    end
end
if validSamples == 0 || sum(counts) == 0
    error('converter:adc:NoValidInlDnlCodes', '有效码值数量为 0，无法计算 INL/DNL。');
end

probMeasured = counts / sum(counts);
halfSpan = max(abs(fitAmplitudeCode), eps);
codeNorm = (codeAxis - fitOffsetCode) / halfSpan;
lsbNorm = 1 / halfSpan;
vLow = max(-1, codeNorm - lsbNorm / 2);
vHigh = min(1, codeNorm + lsbNorm / 2);
probTheoretical = (asin(vHigh) - asin(vLow)) / pi;
probTheoretical(probTheoretical < 0) = 0;
probTheoretical = probTheoretical / sum(probTheoretical);
validProbability = probTheoretical > 1e-12;
dnl = NaN(size(codeAxis));
dnl(validProbability) = probMeasured(validProbability) ./ ...
    probTheoretical(validProbability) - 1;
dnlFinite = dnl(isfinite(dnl));
dnlForCumulativeSum = dnl;
dnlForCumulativeSum(~isfinite(dnlForCumulativeSum)) = 0;
inlRaw = cumsum(dnlForCumulativeSum);
baseline = polyfit(codeAxis(isfinite(inlRaw)), inlRaw(isfinite(inlRaw)), 1);
inl = inlRaw - polyval(baseline, codeAxis);
maxAbsDnl = max(abs(dnlFinite));
maxAbsInl = max(abs(inl(isfinite(inl))));
midMask = codeAxis > (-fullScalePeak / 2) & codeAxis < (fullScalePeak / 2);
maxAbsInlMid = max(abs(inl(midMask & isfinite(inl))));
coverageRatio = sum(counts > 0) / numel(counts);
statusText = 'OK';
if fitR2 < config.minimumFitR2
    statusText = 'FitR2BelowMinimum';
end

results = table({char(channelName)}, numel(fileNames), totalSamples, validSamples, ...
    frequencyHz, frequencyLevelDb, fitAmplitudeCode, fitOffsetCode, fitR2, ...
    fitResidualRms, codeMin, codeMax, coverageRatio, maxAbsDnl, maxAbsInl, ...
    maxAbsInlMid, {statusText}, ...
    'VariableNames', {'Channel','FileCount','TotalSamples','ValidSamples', ...
    'FrequencyHz','FrequencyLevelDb','FitAmplitudeCode','FitOffsetCode', ...
    'FitR2','FitResidualRmsCode','CodeMin','CodeMax','CoverageRatio', ...
    'MaxAbsDNL_LSB','MaxAbsINL_LSB','MaxAbsINLMid_LSB','Status'});
curveTable = table(codeAxis, probMeasured, probTheoretical, dnl, inl, ...
    'VariableNames', {'Code','MeasuredProbability', ...
    'TheoreticalProbability','DNL_LSB','INL_LSB'});
details = struct('curveTable', curveTable, 'frequencyHz', frequencyHz, ...
    'fitR2', fitR2, 'maxAbsDnl', maxAbsDnl, 'maxAbsInl', maxAbsInl, ...
    'channelName', char(channelName));
end


function [results, details] = calculateBandwidth(adcCodeList, fileNames, ...
        fileFrequencyHz, config)
%CALCULATEBANDWIDTH Calculate fitted amplitude response and -3 dB bandwidth.

requiredFields = {'sampleRate', 'adcBits', 'minimumFitR2', ...
    'referencePointCount', 'frequencyMismatchTolerance', 'fitCycles', ...
    'minimumFitSamples', 'clippingMarginCode'};
converter.runtime.validateConfig(config, requiredFields);
fileCount = numel(fileNames);
frequencyHz = NaN(fileCount, 1);
fitFrequencyHz = NaN(fileCount, 1);
codePp = NaN(fileCount, 1);
fitR2 = NaN(fileCount, 1);
fitResidualRmsCode = NaN(fileCount, 1);
frequencyMismatchFlag = false(fileCount, 1);
clippingFlag = false(fileCount, 1);
fullScalePeakCode = 2^(config.adcBits - 1);
[marginLowCode, marginHighCode] = railMargins(config);

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
    if isfield(config, 'fitFrequencySource') && ...
            strcmpi(config.fitFrequencySource, 'file') && ...
            isfinite(fileFrequencyHz(fileIndex))
        fitFrequencyHz(fileIndex) = fileFrequencyHz(fileIndex);
    else
        fitFrequencyHz(fileIndex) = frequencyHz(fileIndex);
    end
    fitConfig.knownFrequencyHz = fitFrequencyHz(fileIndex);
    metrics = converter.adc.analyzeDynamicMetrics(adcCode, fitConfig);
    codePp(fileIndex) = metrics.fit.codePp;
    fitR2(fileIndex) = metrics.fit.r2;
    fitResidualRmsCode(fileIndex) = metrics.fit.residualRmsCode;
    clippingFlag(fileIndex) = ...
        min(adcCode) <= -fullScalePeakCode + marginLowCode || ...
        max(adcCode) >= fullScalePeakCode - 1 - marginHighCode;
end

[fileFrequencyHz, sortIndex] = sort(fileFrequencyHz(:));
frequencyHz = frequencyHz(sortIndex);
fitFrequencyHz = fitFrequencyHz(sortIndex);
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
if isfield(config, 'bandwidthFrequencySource') && ...
        strcmpi(config.bandwidthFrequencySource, 'file')
    validFrequencyHz = fileFrequencyHz(validForBandwidth);
else
    validFrequencyHz = frequencyHz(validForBandwidth);
end
validCodePp = codePp(validForBandwidth);
referencePointCountUsed = min(numel(validCodePp), config.referencePointCount);
referenceValidIndices = 1:referencePointCountUsed;
referencePoint = false(fileCount, 1);
validIndices = find(validForBandwidth);
if referencePointCountUsed > 0
    referenceCodePp = median(validCodePp(referenceValidIndices));
    referencePoint(validIndices(referenceValidIndices)) = true;
else
    referenceCodePp = NaN;
end
relativeDb = NaN(fileCount, 1);
if ~isempty(validCodePp) && isfinite(referenceCodePp) && referenceCodePp > 0
    relativeDb(validForBandwidth) = 20 * log10(validCodePp / referenceCodePp);
end
if numel(validCodePp) >= 2 && ...
        referencePointCountUsed >= config.referencePointCount
    bandwidth3dBHz = converter.adc.findThreeDbCrossing( ...
        validFrequencyHz, relativeDb(validForBandwidth));
    if isfinite(bandwidth3dBHz)
        coverageStatus = "覆盖充分";
    else
        coverageStatus = "覆盖不足";
    end
else
    bandwidth3dBHz = NaN;
    coverageStatus = "覆盖不足";
end
% Optional source-impedance de-embedding: a device configuration may
% declare bandwidthScaleFactor (default 1) to rescale the crossing to the
% board-only bandwidth (e.g. ADC128 X11 inputs, R = 33 ohm board + 50 ohm
% generator). The relative-dB curve and all frequency checks stay in the
% measured domain; only the reported bandwidth is scaled.
bandwidthScaleFactor = 1;
if isfield(config, 'bandwidthScaleFactor') && ...
        ~isempty(config.bandwidthScaleFactor)
    bandwidthScaleFactor = double(config.bandwidthScaleFactor);
end
if isfinite(bandwidth3dBHz)
    bandwidth3dBHz = bandwidth3dBHz * bandwidthScaleFactor;
end
% The numeric crossing is reported separately; without an acceptance limit,
% the formal conclusion remains an auditable unknown state.
conclusion = "暂不能判定";
frequencyErrorHz = frequencyHz - fileFrequencyHz;
frequencyErrorPercent = 100 * frequencyErrorHz ./ fileFrequencyHz;

results = table(string(fileNames(:)), fileFrequencyHz, frequencyHz, ...
    fitFrequencyHz, ...
    frequencyErrorHz, frequencyErrorPercent, frequencyMismatchFlag, ...
    clippingFlag, codePp, relativeDb, fitR2, fitResidualRmsCode, ...
    validForBandwidth, referencePoint, repmat(bandwidth3dBHz, fileCount, 1), ...
    repmat(coverageStatus, fileCount, 1), repmat(conclusion, fileCount, 1), ...
    'VariableNames', {'FileName', 'FileFrequencyHz', 'FrequencyHz', ...
    'FitFrequencyHz', ...
    'FrequencyErrorHz', 'FrequencyErrorPercent', 'FrequencyMismatchFlag', ...
    'ClippingFlag', 'CodePp', 'RelativeDb', 'FitR2', ...
    'FitResidualRmsCode', 'ValidForBandwidth', 'ReferencePoint', ...
    'Bandwidth3dBHz', 'CoverageStatus', 'Conclusion'});
details = struct('bandwidth3dBHz', bandwidth3dBHz, ...
    'referenceCodePp', referenceCodePp, ...
    'coverageStatus', coverageStatus, 'conclusion', conclusion, ...
    'validPointCount', nnz(validForBandwidth), ...
    'bandwidthScaleFactor', bandwidthScaleFactor);
end

function [marginLowCode, marginHighCode] = railMargins(config)
%RAILMARGINS Per-side near-rail margins with the legacy single-margin fallback.
%   clippingMarginLowCode/HighCode override the shared clippingMarginCode
%   per rail when present; unchanged configurations keep the old behavior.
if isfield(config, 'clippingMarginLowCode') && ...
        ~isempty(config.clippingMarginLowCode)
    marginLowCode = config.clippingMarginLowCode;
else
    marginLowCode = config.clippingMarginCode;
end
if isfield(config, 'clippingMarginHighCode') && ...
        ~isempty(config.clippingMarginHighCode)
    marginHighCode = config.clippingMarginHighCode;
else
    marginHighCode = config.clippingMarginCode;
end
end


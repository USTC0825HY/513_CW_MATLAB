function [results, details] = calculatePowerScale(adcCodeList, fileNames, ...
        inputPowerDbm, channelNames, config, setpointInfo)
%CALCULATEPOWERSCALE Fit the ADC CodePp-to-Vpp calibration.

requiredFields = {'sampleRate', 'adcBits', 'testFrequencyHz', ...
    'frequencyMismatchTolerance', 'clippingThreshold', ...
    'clippingFractionLimit', 'plateauChangeThreshold', 'fitCycles', ...
    'minimumFitSamples'};
converter.runtime.validateConfig(config, requiredFields);
if ~isfield(config, 'powerRangeVpp') && ~isfield(config, 'powerRangeDbm')
    error('converter:adc:MissingPowerRange', ...
        '配置必须提供 powerRangeVpp 或 powerRangeDbm。');
end
minimumSineFitR2 = getOptionalConfig(config, 'minimumSineFitR2', -Inf);
excludeFrequencyMismatch = getOptionalConfig(config, ...
    'excludeFrequencyMismatchFromPowerScale', false);
if ~isscalar(minimumSineFitR2) || ...
        ~(isfinite(minimumSineFitR2) || isinf(minimumSineFitR2)) || ...
        minimumSineFitR2 > 1
    error('converter:adc:InvalidMinimumSineFitR2', ...
        'minimumSineFitR2 必须是不大于 1 的标量。');
end
if ~isscalar(excludeFrequencyMismatch)
    error('converter:adc:InvalidFrequencyQualityConfig', ...
        'excludeFrequencyMismatchFromPowerScale 必须为标量。');
end
excludeFrequencyMismatch = logical(excludeFrequencyMismatch);
fileCount = numel(fileNames);
channelNames = string(channelNames(:));
if nargin < 6 || isempty(setpointInfo)
    setpointInfo = defaultSetpointInfo(fileCount, inputPowerDbm, ...
        getReferenceImpedance(config));
else
    setpointInfo = normalizeSetpointInfo(setpointInfo, fileCount);
end
inputVoltageVpp = setpointInfo.inputVoltageVpp(:);
inputPowerDbm = inputPowerDbm(:);
if any(~isfinite(inputVoltageVpp)) || any(inputVoltageVpp <= 0)
    error('converter:adc:InvalidVppSetpoint', ...
        'Vpp 标定输入必须为正的有限数值。');
end

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
    measuredFrequencyHz(fileIndex) = converter.adc.refineSineFrequency( ...
        adcCode, measuredFrequencyHz(fileIndex), config.sampleRate, ...
        config.fitCycles, config.minimumFitSamples);
    frequencyMismatchFlag(fileIndex) = ...
        abs(measuredFrequencyHz(fileIndex) - config.testFrequencyHz) / ...
        max(config.testFrequencyHz, eps) > config.frequencyMismatchTolerance;
    fitConfig = config;
    fitConfig.fitMode = 'known';
    fitConfig.knownFrequencyHz = config.testFrequencyHz;
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

if isfield(config, 'powerSetpointUnit') && ...
        strcmpi(config.powerSetpointUnit, 'Vpp')
    [inputVoltageVpp, sortIndex] = sort(inputVoltageVpp);
    inputPowerDbm = inputPowerDbm(sortIndex);
else
    [inputPowerDbm, sortIndex] = sort(inputPowerDbm);
    inputVoltageVpp = inputVoltageVpp(sortIndex);
end
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
setpointInfo.inputVoltageVpp = inputVoltageVpp;
setpointInfo.referenceImpedanceOhm = ...
    setpointInfo.referenceImpedanceOhm(sortIndex);
setpointInfo.inputPowerSource = setpointInfo.inputPowerSource(sortIndex);
setpointInfo.inputPowerDefinition = ...
    setpointInfo.inputPowerDefinition(sortIndex);

clippingFlag = nearFullScaleFraction > config.clippingFractionLimit;
plateauFlag = false(fileCount, 1);
for fileIndex = 2:fileCount
    relativeChange = abs(codePp(fileIndex) - codePp(fileIndex - 1)) / ...
        max(codePp(fileIndex - 1), eps);
    plateauFlag(fileIndex) = relativeChange <= config.plateauChangeThreshold;
end
effectivePowerRangeDbm = [NaN NaN];
if isfield(config, 'powerRangeVpp') && ~isempty(config.powerRangeVpp)
    calibrationPowerRangeVpp = double(config.powerRangeVpp(:).');
else
    configuredPowerRangeDbm = double(config.powerRangeDbm(:).');
    autoSelectPowerRange = getOptionalConfig(config, ...
        'autoSelectPowerRangeFromUnclipped', false);
    if autoSelectPowerRange
        if numel(configuredPowerRangeDbm) ~= 2 || ...
                ~isfinite(configuredPowerRangeDbm(1))
            error('converter:adc:InvalidPowerRange', ...
                '自动选择标定上限时，powerRangeDbm 必须提供有限的下限。');
        end
        nonClippedCandidate = isfinite(inputPowerDbm) & ...
            inputPowerDbm >= configuredPowerRangeDbm(1) & ~clippingFlag;
        if ~any(nonClippedCandidate)
            error('converter:adc:NoUnclippedPowerPoint', ...
                '指定下限以上没有可用的未削顶输入功率点。');
        end
        effectivePowerRangeDbm = [configuredPowerRangeDbm(1), ...
            max(inputPowerDbm(nonClippedCandidate))];
        calibrationPowerRangeVpp = converter.adc.dbmToVpp( ...
            effectivePowerRangeDbm, getReferenceImpedance(config));
    else
        effectivePowerRangeDbm = configuredPowerRangeDbm;
        calibrationPowerRangeVpp = converter.adc.dbmToVpp( ...
            effectivePowerRangeDbm, getReferenceImpedance(config));
    end
end
inSpecifiedRange = inputVoltageVpp >= calibrationPowerRangeVpp(1) & ...
    inputVoltageVpp <= calibrationPowerRangeVpp(2);
sineFitQualityPass = fitR2 >= minimumSineFitR2;
frequencyQualityPass = ~frequencyMismatchFlag | ~excludeFrequencyMismatch;
calibrationIncluded = inSpecifiedRange & ~clippingFlag & ~plateauFlag & ...
    sineFitQualityPass & frequencyQualityPass;
% Hard safety invariant: a near-rail/clipped capture must never enter the
% formal CodePp-to-Vpp fit, even if a caller supplies an unusual range.
if any(calibrationIncluded & clippingFlag)
    error('converter:adc:ClippedPointIncluded', ...
        '削顶点不得纳入 CodePp-to-Vpp 拟合。');
end
exclusionReason = strings(fileCount, 1);
exclusionReason(~inSpecifiedRange) = "outside configured Vpp range";
exclusionReason(clippingFlag) = appendReason(exclusionReason(clippingFlag), ...
    "clipping/near-rail");
exclusionReason(plateauFlag) = appendReason(exclusionReason(plateauFlag), ...
    "amplitude plateau");
exclusionReason(~sineFitQualityPass) = appendReason( ...
    exclusionReason(~sineFitQualityPass), "sine-fit quality");
exclusionReason(~frequencyQualityPass) = appendReason( ...
    exclusionReason(~frequencyQualityPass), "frequency mismatch");
exclusionReason(calibrationIncluded) = "";
if nnz(calibrationIncluded) < 2
    error('converter:adc:InsufficientCalibrationPoints', ...
        '正式范围内有效 CodePp-to-Vpp 标定点少于 2 个。');
end

% The formal calibration direction is CodePp -> Vpp.  dBm remains a
% traceability/setpoint field only; dBm setpoints are converted to Vpp
% before this fit is performed.
coefficient = polyfit(codePp(calibrationIncluded), ...
    inputVoltageVpp(calibrationIncluded), 1);
predictedInputVpp = polyval(coefficient, codePp);
calibrationResidualVpp = inputVoltageVpp - predictedInputVpp;
measuredForFit = inputVoltageVpp(calibrationIncluded);
residualForFit = calibrationResidualVpp(calibrationIncluded);
calibrationR2 = 1 - sum(residualForFit.^2) / ...
    max(sum((measuredForFit - mean(measuredForFit)).^2), eps);

convertedCodePp = (inputVoltageVpp - coefficient(2)) / coefficient(1);
conversionResidualCodePp = convertedCodePp - codePp;
calibrationVppRange = [min(inputVoltageVpp(calibrationIncluded)), ...
    max(inputVoltageVpp(calibrationIncluded))];
conversionInRange = inputVoltageVpp >= calibrationVppRange(1) & ...
    inputVoltageVpp <= calibrationVppRange(2);
forwardFormula = makeForwardFormula(coefficient);
inverseFormula = makeInverseFormula(coefficient);

uniqueChannels = unique(channelNames);
uniqueChannels(uniqueChannels == "") = [];
if isscalar(uniqueChannels)
    channelName = uniqueChannels(1);
else
    channelName = "Unknown";
    warning('converter:adc:AmbiguousChannel', ...
        '无法确定唯一 ADC 通道，输出通道标记为 Unknown。');
end

results = table(repmat(channelName, fileCount, 1), string(fileNames(:)), ...
    inputPowerDbm, inputVoltageVpp, setpointInfo.referenceImpedanceOhm, ...
    setpointInfo.inputPowerSource, setpointInfo.inputPowerDefinition, ...
    repmat(string(getOptionalConfig(config, 'referencePlane', 'unknown')), ...
    fileCount, 1), ...
    repmat(string(getOptionalConfig(config, 'loadDefinition', 'unknown')), ...
    fileCount, 1), ...
    repmat(config.testFrequencyHz, fileCount, 1), measuredFrequencyHz, ...
    measuredFrequencyHz - config.testFrequencyHz, ...
    100 * (measuredFrequencyHz - config.testFrequencyHz) / ...
    max(config.testFrequencyHz, eps), frequencyMismatchFlag, codePp, ...
    codeRms, codeRmsDbfs, peakCode, valleyCode, fitR2, ...
    fitResidualRmsCode, nearFullScaleFraction, clippingFlag, plateauFlag, ...
    inSpecifiedRange, calibrationIncluded, exclusionReason, predictedInputVpp, ...
    calibrationResidualVpp, convertedCodePp, conversionResidualCodePp, ...
    conversionInRange, repmat(coefficient(1), fileCount, 1), ...
    repmat(coefficient(2), fileCount, 1), repmat(calibrationR2, fileCount, 1), ...
    repmat(coefficient(1), fileCount, 1), ...
    repmat(coefficient(2), fileCount, 1), ...
    repmat("暂不能判定", fileCount, 1), ...
    'VariableNames', {'Channel', 'FileName', 'InputPowerDbm', ...
    'InputVoltageVpp', 'ReferenceImpedanceOhm', 'InputPowerSource', ...
    'InputPowerDefinition', 'ReferencePlane', 'LoadDefinition', ...
    'ExpectedFrequencyHz', 'FrequencyHz', ...
    'FrequencyErrorHz', 'FrequencyErrorPercent', 'FrequencyMismatchFlag', ...
    'CodePp', 'CodeRms', 'CodeRmsDbfs', 'PeakCode', 'ValleyCode', ...
    'FitR2', 'FitResidualRmsCode', 'NearFullScaleFraction', ...
    'ClippingFlag', 'PlateauFlag', 'InSpecifiedRange', ...
    'CalibrationIncluded', 'ExclusionReason', 'PredictedInputVpp', ...
    'CalibrationResidualVpp', 'InputVppConvertedCodePp', ...
    'InputVppConversionResidualCodePp', 'InputVppConversionInCalibrationRange', ...
    'CalibrationSlopeVppPerCodePp', 'CalibrationInterceptVpp', ...
    'CalibrationR2', 'SlopeVppPerCodePp', 'InterceptVpp', 'Conclusion'});

criticalInput = converter.adc.estimateCriticalInput(results, coefficient, ...
    config, getReferenceImpedance(setpointInfo));

details = struct('coefficient', coefficient, 'calibrationR2', calibrationR2, ...
    'channelName', channelName, 'adcFullScalePeakCode', adcFullScalePeakCode, ...
    'calibrationPointCount', nnz(calibrationIncluded), ...
    'powerRangeDbm', effectivePowerRangeDbm, ...
    'calibrationPowerRangeVpp', calibrationPowerRangeVpp, ...
    'calibrationVppRange', calibrationVppRange, ...
    'forwardFormulaCodePpToVpp', forwardFormula, ...
    'inverseFormulaVppToCodePp', inverseFormula, ...
    'codePpDefinition', 'CodePp = 2 * fitted sine amplitude (LSBpp)', ...
    'inputPowerToVppFormula', getInputPowerFormula(config), ...
    'minimumSineFitR2', minimumSineFitR2, ...
    'excludeFrequencyMismatch', logical(excludeFrequencyMismatch), ...
    'powerSetpointSource', getSetpointSource(config, setpointInfo), ...
    'setpointManifestUsed', logical(setpointInfo.setpointManifestUsed), ...
    'inputPowerReference', getInputPowerReference(setpointInfo), ...
    'referenceImpedanceOhm', getReferenceImpedance(setpointInfo), ...
    'criticalInput', criticalInput);
end

function output = appendReason(existing, reason)
output = existing;
hasExisting = strlength(existing) > 0;
output(~hasExisting) = reason;
output(hasExisting) = existing(hasExisting) + "; " + reason;
end

function formula = getInputPowerFormula(config)
if isfield(config, 'powerSetpointUnit') && ...
        strcmpi(config.powerSetpointUnit, 'Vpp')
    formula = 'not applied; Vpp supplied directly by manifest/setpoint';
else
    formula = 'Vpp = 2*sqrt(2*R*1e-3*10^(InputPowerDbm/10))';
end
end

function info = defaultSetpointInfo(fileCount, inputPowerDbm, impedanceOhm)
info = struct();
info.setpointManifestUsed = false;
info.inputVoltageVpp = converter.adc.dbmToVpp(inputPowerDbm, impedanceOhm);
info.referenceImpedanceOhm = repmat(impedanceOhm, fileCount, 1);
info.inputPowerSource = repmat( ...
    "dBm value parsed from CSV filename", fileCount, 1);
info.inputPowerDefinition = repmat( ...
    "Vpp derived from filename dBm at explicit reference impedance", ...
    fileCount, 1);
end

function info = normalizeSetpointInfo(info, fileCount)
requiredNames = {'inputVoltageVpp', 'referenceImpedanceOhm', ...
    'inputPowerSource', 'inputPowerDefinition', 'setpointManifestUsed'};
for k = 1:numel(requiredNames)
    if ~isfield(info, requiredNames{k})
        error('converter:adc:InvalidSetpointInfo', ...
            'setpointInfo 缺少字段：%s。', requiredNames{k});
    end
end
if numel(info.inputVoltageVpp) ~= fileCount || ...
        numel(info.referenceImpedanceOhm) ~= fileCount || ...
        numel(info.inputPowerSource) ~= fileCount || ...
        numel(info.inputPowerDefinition) ~= fileCount
    error('converter:adc:InvalidSetpointInfo', ...
        'setpointInfo 长度必须与文件数量一致。');
end
info.inputVoltageVpp = double(info.inputVoltageVpp(:));
info.referenceImpedanceOhm = double(info.referenceImpedanceOhm(:));
info.inputPowerSource = string(info.inputPowerSource(:));
info.inputPowerDefinition = string(info.inputPowerDefinition(:));
info.setpointManifestUsed = logical(info.setpointManifestUsed);
end

function source = getSetpointSource(config, info)
values = info.inputPowerSource(info.inputPowerSource ~= "");
if isempty(values)
    if isfield(config, 'powerSetpointSource')
        source = char(config.powerSetpointSource);
    else
        source = 'input Vpp setpoint';
    end
elseif all(values == values(1))
    source = char(values(1));
else
    source = 'explicit input-power manifest';
end
end

function reference = getInputPowerReference(info)
values = info.inputPowerDefinition(info.inputPowerDefinition ~= "");
if isempty(values)
    reference = 'input Vpp setpoint';
elseif all(values == values(1))
    reference = char(values(1));
else
    reference = 'per-file input-power definitions';
end
end

function impedance = getReferenceImpedance(configOrInfo)
if isstruct(configOrInfo) && isfield(configOrInfo, ...
        'referenceImpedanceOhm')
    values = configOrInfo.referenceImpedanceOhm;
    values = values(isfinite(values));
    if isempty(values)
        impedance = NaN;
    elseif all(values == values(1))
        impedance = values(1);
    else
        impedance = NaN;
    end
else
    impedance = 50;
end
end

function value = getOptionalConfig(config, fieldName, defaultValue)
if isfield(config, fieldName) && ~isempty(config.(fieldName))
    value = config.(fieldName);
else
    value = defaultValue;
end
end

function formula = makeForwardFormula(coefficient)
formula = sprintf('Vpp = %.12g*CodePp %+.12g', ...
    coefficient(1), coefficient(2));
end

function formula = makeInverseFormula(coefficient)
formula = sprintf('CodePp = (Vpp %+.12g) / %.12g', ...
    -coefficient(2), coefficient(1));
end

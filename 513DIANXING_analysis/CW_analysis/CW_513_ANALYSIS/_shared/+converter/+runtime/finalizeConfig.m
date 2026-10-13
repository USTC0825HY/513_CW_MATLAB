function config = finalizeConfig(defaults, override)
%FINALIZECONFIG Merge caller settings, resolve derived values, and validate.
% Generic mergeConfig remains permissive for non-configuration structures.
if nargin < 2 || isempty(override), override = struct(); end
converter.runtime.validateOverrideFields(defaults, override);
override = converter.runtime.mergeConfig(struct(), override);
config = converter.runtime.mergeConfig(defaults, override);
validateValues(config);
sources = struct();
if isfield(defaults, 'parameterSources'), sources = defaults.parameterSources; end
names = setdiff(fieldnames(defaults), {'parameterSources'});
for k = 1:numel(names)
    if ~isfield(sources, names{k}), sources.(names{k}) = 'device/analysis default'; end
end
names = setdiff(fieldnames(override), {'parameterSources'});
for k = 1:numel(names), sources.(names{k}) = 'explicit caller override'; end

% Tombstones are accepted only for replay of old snapshots. They never control computation.
inactive = {'resolutionAuditRequired','frequencySearchFraction', ...
    'formalStatus','formalStatusReason','frequencyCoverageHz','bandwidthLimitHz','scaleRequirement', ...
    'picoFpgaGain','picoAsdCheckHz','picoWelch','picoDacCalibration'};
provided = intersect(fieldnames(override), inactive);
for k = 1:numel(provided)
    warning('converter:runtime:InactiveConfigField', ...
        '历史字段%s保留在配置中，但不参与本项计算或判定。', provided{k});
    sources.(provided{k}) = 'legacy metadata; inactive';
end
if isfield(config,'analysisId')
    analysis = char(config.analysisId);
else
    analysis = '';
end
noiseFields = {'targetResolutionHz','overlapRatio','windowType','minimumAsdSegmentCount', ...
    'maximumAsdBinRelativeError','asdCheckHz','asdLimit_uVPerSqrtHz', ...
    'integratedBandHz','integratedLimit_uVrms','asdOnly','requirementAsdId', ...
    'requirementIntegratedId','requirementSourceDocument','requirementSourceSha256'};
scaleFields = {'codeNameFormat','codeVppDefinition','codeConversionRule','toneFrequencyHz', ...
    'minimumCodeVpp','maximumCodeVpp'};
if isfield(config,'deviceId') && startsWith(config.deviceId,'DA')
    unused = {};
    if ~strcmp(analysis,'noise'), unused = [unused noiseFields]; end
    if ~strcmp(analysis,'scale'), unused = [unused scaleFields]; end
    provided = intersect(fieldnames(override), unused);
    for k = 1:numel(provided)
        warning('converter:runtime:InactiveConfigField', ...
            '%s不参与%s分析；仅为旧配置复跑保留。',provided{k},analysis);
        sources.(provided{k}) = 'legacy metadata; inactive for this analysis';
    end
end

% Metric-specific legacy settings may occur in saved, wider configurations.
% Accept the snapshot but explain fields whose consumers belong to another metric.
if isfield(config,'deviceId') && startsWith(config.deviceId,'AD')
    groups = { ...
        'sfdr', {'nfft','dcSpan','signalSpan','harmonicSpan','maxHarmonicOrder', ...
            'sfdrSampleStride','sfdrAnalysisSampleRateHz','sfdrSamplingMode','sfdrResultUse'}; ...
        'bandwidth', {'referencePointCount','minimumRecordCycles', ...
            'rejectFrequencyMismatch','bandwidthScaleFactor','bandwidthScaleRules'}; ...
        'power_scale', {'powerRangeDbm','powerRangeVpp','powerScalePlotMode', ...
            'criticalInputThresholdFraction','autoSelectPowerRangeFromUnclipped'}; ...
        'input_noise', {'noiseBandHz','welchNfft','welchSegmentCount', ...
            'welchOverlapRatio','noiseLimitNvPerSqrtHz','noiseCalibration'}; ...
        'inl_dnl', {'recordsAreSampleContiguous','maximumGlitchFraction', ...
            'glitchSigmaMultiplier','glitchMinimumThresholdCode'}};
    for groupIndex=1:size(groups,1)
        if strcmp(analysis,groups{groupIndex,1}), continue; end
        provided = intersect(fieldnames(override),groups{groupIndex,2});
        for k=1:numel(provided)
            warning('converter:runtime:InactiveConfigField', ...
                '%s用于%s，不参与当前%s分析；为旧配置复跑保留。', ...
                provided{k},groups{groupIndex,1},analysis);
            sources.(provided{k}) = 'legacy metadata; inactive for this analysis';
        end
    end
end

if strcmp(analysis,'power_scale') && isfield(override,'powerRangeDbm') && ...
        ~isfield(override,'powerRangeVpp') && isfield(config,'powerRangeVpp') && ...
        ~isempty(config.powerRangeVpp)
    error('converter:runtime:InactivePowerRange', ...
        '当前powerRangeVpp优先。要使用powerRangeDbm，请同时显式设置powerRangeVpp=[]。');
end
if strcmp(analysis,'sfdr')
    stride = 1;
    if isfield(config,'sfdrSampleStride'), stride = config.sfdrSampleStride; end
    validateattributes(stride, {'numeric'}, {'scalar','real','finite','integer','positive'});
    rate = config.sampleRate / stride;
    if isfield(override,'sfdrAnalysisSampleRateHz')
        validateattributes(override.sfdrAnalysisSampleRateHz, {'numeric'}, ...
            {'scalar','real','finite','positive'});
        if abs(override.sfdrAnalysisSampleRateHz-rate) > max(1,rate)*1e-12
            error('converter:adc:InconsistentSfdrSamplingRate', ...
                'SFDR分析采样率必须等于源采样率除以抽样步长。');
        end
    elseif isfield(config,'sfdrSampleStride') || isfield(config,'sfdrAnalysisSampleRateHz')
        config.sfdrAnalysisSampleRateHz = rate;
        sources.sfdrAnalysisSampleRateHz = 'derived: sampleRate / sfdrSampleStride';
    end
    if isfield(config,'ilaCaptureSampleRateHz')
        if isfield(override,'ilaCaptureSampleRateHz') && ...
                abs(override.ilaCaptureSampleRateHz-config.sampleRate) > max(1,config.sampleRate)*1e-12
            error('converter:runtime:InconsistentCaptureRate', ...
                'ilaCaptureSampleRateHz必须与原始记录sampleRate一致；ADC转换时钟另行记录。');
        end
        config.ilaCaptureSampleRateHz = config.sampleRate;
        sources.ilaCaptureSampleRateHz = 'source ILA record sampleRate';
    end
    if isfield(override,'sfdrSampleStride') && ~isfield(override,'sfdrSamplingMode')
        config.sfdrSamplingMode = sprintf('fixed_stride_keep_one_of_%d', stride);
        sources.sfdrSamplingMode = 'derived from sample stride';
    end
end
if isfield(config,'adcBits') && ~isfield(override,'adcFullScalePeakCode')
    config.adcFullScalePeakCode = 2^(config.adcBits-1);
    sources.adcFullScalePeakCode = 'derived from adcBits';
end
if isfield(override,'dacBits') && ~isfield(override,'dacCodeBits')
    config.dacCodeBits = config.dacBits;
    sources.dacCodeBits = 'derived from dacBits';
end
validateValues(config);
config.parameterSources = sources;
end

function validateValues(c)
if isfield(c,'configOverride')
    error('converter:runtime:MixedOverrideStyles', ...
        '此处应传配置字段本身；嵌套configOverride仅用于明确支持runOptions的入口。');
end
positive = {'hardwareGain','asdCheckHz','targetResolutionHz','toneFrequencyHz', ...
    'isolationFrequencyHz','testFrequencyHz','edgeThreshold','minHoldS','levelTolV'};
for k=1:numel(positive)
    if isfield(c,positive{k}), validateattributes(c.(positive{k}),{'numeric'}, ...
            {'scalar','real','finite','positive'},mfilename,positive{k}); end
end
integers = {'adcBits','dacBits','dacCodeBits','nfft','welchNfft', ...
    'sfdrSampleStride','welchSegmentCount','smoothingWindowSamples'};
for k=1:numel(integers)
    if isfield(c,integers{k}), validateattributes(c.(integers{k}),{'numeric'}, ...
            {'scalar','real','finite','positive','integer'},mfilename,integers{k}); end
end
columns = {'adcDataColumn','validDataColumn'};
for k=1:numel(columns)
    if isfield(c,columns{k}), validateattributes(c.(columns{k}),{'numeric'}, ...
            {'scalar','real','finite','nonnegative','integer'},mfilename,columns{k}); end
end
if isfield(c,'validDataColumn') && c.validDataColumn == 0
    error('converter:runtime:InvalidValidColumn','validDataColumn必须从1开始。');
end
bits = {'adcBits','dacBits','dacCodeBits'};
for k=1:numel(bits)
    if isfield(c,bits{k}), validateattributes(c.(bits{k}),{'numeric'}, ...
            {'<=',32},mfilename,bits{k}); end
end
flags = {'formalEnabled','filterValidStrobe','removeMean','asdOnly', ...
    'recordsAreSampleContiguous','autoDetectDrive','simpleIsolationSelection'};
for k=1:numel(flags)
    if isfield(c,flags{k})
        v=c.(flags{k});
        if ~((islogical(v) || isnumeric(v)) && isscalar(v) && ismember(v,[0 1]))
            error('converter:runtime:InvalidBoolean','%s必须为true或false。',flags{k});
        end
    end
end
if isfield(c,'sampleRate')
    automatic = isfield(c,'filterValidStrobe') && c.filterValidStrobe && ...
        isscalar(c.sampleRate) && isnan(c.sampleRate);
    if ~automatic, validateattributes(c.sampleRate,{'numeric'}, ...
            {'scalar','real','finite','positive'},mfilename,'sampleRate'); end
end
ratios = {'overlapRatio','welchOverlapRatio'};
for k=1:numel(ratios)
    if isfield(c,ratios{k}), validateattributes(c.(ratios{k}),{'numeric'}, ...
            {'scalar','real','finite','>=',0,'<',1},mfilename,ratios{k}); end
end
bands = {'noiseBandHz','integratedBandHz'};
for k=1:numel(bands)
    if isfield(c,bands{k})
        b=c.(bands{k}); validateattributes(b,{'numeric'},{'real','finite','numel',2,'nonnegative'});
        if b(2)<=b(1), error('converter:runtime:InvalidBand','%s上限必须大于下限。',bands{k}); end
    end
end
if isfield(c,'metadata') && (~isstruct(c.metadata) || ~isscalar(c.metadata))
    error('converter:runtime:InvalidMetadata','metadata必须为标量结构体。');
end
if isfield(c,'inputRadix') && ...
        (~(ischar(c.inputRadix) || (isstring(c.inputRadix) && isscalar(c.inputRadix))) || ...
        ~ismember(lower(char(c.inputRadix)),{'auto','hex','decimal'}))
    error('converter:io:InvalidInputRadix','inputRadix只能是auto、hex或decimal。');
end
if isfield(c,'welch')
    converter.runtime.validateOverrideFields(struct('targetResolutionHz',0.2, ...
        'overlapRatio',0.5,'windowType','hann'),c.welch,{});
    validateValues(c.welch);
end
if isfield(c,'windowType') && ~ismember(lower(string(c.windowType)),["hann","hamming"])
    error('converter:runtime:InvalidWindow','windowType只支持hann或hamming。');
end
end

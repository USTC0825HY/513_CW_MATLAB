function reportConfiguration(config)
%REPORTCONFIGURATION Print the effective user-facing parameters, with units in names.
names = {'inputRadix','adcDataColumn','validDataColumn','sfdrSampleStride', ...
    'sfdrAnalysisSampleRateHz','hardwareGain','fpgaGain','toneFrequencyHz', ...
    'testFrequencyHz','powerRangeVpp','powerRangeDbm','noiseBandHz', ...
    'welchSegmentCount','welchNfft','targetResolutionHz','overlapRatio', ...
    'integratedBandHz','edgeThreshold','minHoldS','levelTolV', ...
    'smoothingWindowSamples','formalEnabled'};
fprintf('本次生效参数（完整配置见run_config.mat或结果MAT）：\n');
for k=1:numel(names)
    if ~isfield(config,names{k}), continue; end
    value=config.(names{k});
    if isnumeric(value) || islogical(value), text=mat2str(value,12);
    else, text=char(string(value)); end
    fprintf('  %s = %s\n',names{k},text);
end
if isfield(config,'powerRangeVpp') && ~isempty(config.powerRangeVpp)
    fprintf('  拟合范围采用Vpp；powerRangeDbm和dBm自动上限在本次不生效。\n');
end
if isfield(config,'welch'), converter.runtime.reportConfiguration(config.welch); end
end

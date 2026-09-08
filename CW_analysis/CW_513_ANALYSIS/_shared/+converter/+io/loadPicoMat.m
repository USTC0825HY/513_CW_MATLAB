function capture = loadPicoMat(filePath, requestedVariable, hardwareGain, removeMean)
%LOADPICOMAT Load a PicoScope MAT waveform without external helpers.
if nargin < 2 || isempty(requestedVariable), requestedVariable = ''; end
if nargin < 3 || isempty(hardwareGain), hardwareGain = 1; end
if nargin < 4, removeMean = true; end
data = load(filePath);
sampleRate = localSampleRate(data, filePath);
variableName = localVariable(data, requestedVariable, filePath);
rawValue = data.(variableName);
raw = double(rawValue(:));
valid = isfinite(raw);
voltage = raw(valid) ./ hardwareGain;
if removeMean, voltage = voltage - mean(voltage); end
capture = struct('filePath', filePath, 'variableName', variableName, ...
    'sampleRateHz', sampleRate, 'rawSampleCount', numel(raw), ...
    'sampleCount', numel(voltage), 'droppedNonfinite', nnz(~valid), ...
    'voltage', voltage);
end

function sampleRate = localSampleRate(data, filePath)
if isfield(data, 'Tinterval') && ~isempty(data.Tinterval)
    sampleRate = 1 / double(data.Tinterval(1));
elseif isfield(data, 'fs') && ~isempty(data.fs)
    sampleRate = double(data.fs(1));
else
    error('converter:io:SampleRateMissing', ...
        'MAT文件缺少Tinterval或fs：%s', filePath);
end
if ~isfinite(sampleRate) || sampleRate <= 0
    error('converter:io:SampleRateInvalid', '采样率无效：%s', filePath);
end
end

function variableName = localVariable(data, requestedVariable, filePath)
requestedVariable = char(requestedVariable);
if ~isempty(strtrim(requestedVariable))
    if ~isfield(data, requestedVariable)
        error('converter:io:VariableMissing', ...
            'MAT文件缺少指定通道%s：%s', requestedVariable, filePath);
    end
    variableName = requestedVariable;
    return;
end
candidates = {'A', 'B', 'C', 'D'};
present = candidates(cellfun(@(name) isfield(data, name), candidates));
if numel(present) ~= 1
    error('converter:io:VariableAmbiguous', ...
        'MAT文件必须唯一包含A/B/C/D通道，或显式指定通道：%s', filePath);
end
variableName = present{1};
end

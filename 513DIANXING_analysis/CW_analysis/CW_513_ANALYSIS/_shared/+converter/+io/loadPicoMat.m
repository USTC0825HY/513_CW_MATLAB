function capture = loadPicoMat(filePath, requestedVariable, hardwareGain, removeMean)
%LOADPICOMAT Load a PicoScope MAT waveform without external helpers.
if nargin < 2 || isempty(requestedVariable), requestedVariable = ''; end
if nargin < 3 || isempty(hardwareGain), hardwareGain = 1; end
if nargin < 4, removeMean = true; end
try
    data = load(filePath);
catch exception
    fileBytes = NaN;
    item = dir(filePath);
    if ~isempty(item), fileBytes = item.bytes; end
    wrapped = MException('converter:io:MatReadFailed', ...
        ['MAT文件无法读取，文件可能尚未写完或已损坏：%s ' ...
        '(文件大小 %.0f bytes)。请重新从PicoScope导出或完整复制后再运行。' ...
        '\n原始MATLAB错误：%s'], filePath, fileBytes, exception.message);
    wrapped = addCause(wrapped, exception);
    throw(wrapped);
end
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
picoChannels = {'A', 'B', 'C', 'D'};
present = picoChannels(cellfun(@(name) isfield(data, name), picoChannels));
% Single-channel exports occasionally save the waveform under a different
% channel letter (the jiaqiang X3/X13 captures were recorded on Pico
% channel B).  When the requested channel letter is missing but exactly one
% other Pico channel is present, fall back to it instead of failing.
if ~isempty(strtrim(requestedVariable)) && ...
        ismember(upper(requestedVariable), picoChannels) && ...
        ~isfield(data, requestedVariable) && numel(present) == 1
    fprintf('PICO 波形不在通道%s，改用变量 %s：%s\n', ...
        upper(requestedVariable), present{1}, filePath);
    variableName = present{1};
    return;
end
if ~isempty(strtrim(requestedVariable))
    if ~isfield(data, requestedVariable)
        error('converter:io:VariableMissing', ...
            'MAT文件缺少指定通道%s：%s', requestedVariable, filePath);
    end
    variableName = requestedVariable;
    return;
end
if numel(present) ~= 1
    error('converter:io:VariableAmbiguous', ...
        'MAT文件必须唯一包含A/B/C/D通道，或显式指定通道：%s', filePath);
end
variableName = present{1};
end

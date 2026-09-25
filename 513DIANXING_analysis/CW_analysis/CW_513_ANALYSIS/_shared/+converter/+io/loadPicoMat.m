function capture = loadPicoMat(filePath, requestedVariable, hardwareGain, removeMean)
%LOADPICOMAT Load a PicoScope MAT waveform without external helpers.
if nargin < 2 || isempty(requestedVariable), requestedVariable = ''; end
if nargin < 3 || isempty(hardwareGain), hardwareGain = 1; end
if nargin < 4, removeMean = true; end
validateattributes(hardwareGain, {'numeric'}, {'real','scalar','finite','positive'});
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
validateattributes(rawValue, {'numeric'}, {'real','vector','nonempty'}, ...
    mfilename, 'waveform');
raw = double(rawValue(:));
valid = isfinite(raw);
if ~all(valid)
    error('converter:io:NonfiniteWaveform', ...
        '波形包含 %d 个非有限点，不能删除样点后压缩时基：%s', nnz(~valid), filePath);
end
voltage = raw ./ hardwareGain;
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
if ~isempty(strtrim(requestedVariable))
    if ~isfield(data, requestedVariable)
        error('converter:io:VariableMissing', ...
            'MAT文件缺少指定通道%s：%s', requestedVariable, filePath);
    end
    variableName = requestedVariable;
    return;
end
if numel(present) ~= 1
    if isempty(present)
        error('converter:io:VariableAmbiguous', ...
            ['MAT文件不包含任何Pico通道变量A/B/C/D：%s。' ...
             '请检查PicoScope导出设置，或在runOptions.waveVariable中' ...
             '显式给出波形变量名。'], filePath);
    end
    error('converter:io:VariableAmbiguous', ...
        ['MAT文件包含%d个Pico通道变量（%s），无法自动选择：%s。' ...
         '解决方法二选一：1) 在runOptions中显式指定通道，例如 ' ...
         'struct(''interface'',''677_1'',''waveVariable'',''A'')；' ...
         '2) 重新导出仅保留目标通道。'], ...
        numel(present), strjoin(present, '/'), filePath);
end
variableName = present{1};
end

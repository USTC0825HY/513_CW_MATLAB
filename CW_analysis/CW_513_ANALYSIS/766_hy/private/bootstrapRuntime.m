function bootstrapRuntime()
%BOOTSTRAPRUNTIME Load only the CW_513_ANALYSIS DAC runtime.
deviceFolder = fileparts(fileparts(mfilename('fullpath')));
standalone = fullfile(deviceFolder, 'internal');
source = fullfile(deviceFolder, '..', '_shared');
if isfolder(fullfile(standalone, '+converter'))
    addpath(standalone);
elseif isfolder(fullfile(source, '+converter'))
    addpath(source);
else
    error('cw513:RuntimeNotFound', '未找到CW_513_ANALYSIS公共运行内核。');
end
end

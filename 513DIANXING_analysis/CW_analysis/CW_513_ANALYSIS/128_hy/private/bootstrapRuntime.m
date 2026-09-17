function bootstrapRuntime()
%BOOTSTRAPRUNTIME Load the adjacent shared core or a packaged runtime.
deviceFolder = fileparts(fileparts(mfilename('fullpath')));
packaged = fullfile(deviceFolder, 'internal');
shared = fullfile(deviceFolder, '..', '_shared');
if isfolder(fullfile(packaged, '+converter'))
    addpath(packaged);
elseif isfolder(fullfile(shared, '+converter'))
    addpath(shared);
else
    error('adc128:RuntimeMissing', '请保留128_hy旁的_shared目录。');
end
end

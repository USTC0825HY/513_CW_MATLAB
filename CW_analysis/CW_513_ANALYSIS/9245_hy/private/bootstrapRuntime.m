function bootstrapRuntime()
%BOOTSTRAPRUNTIME Add the AD9245 shared runtime to the MATLAB path.

deviceFolder = fileparts(fileparts(mfilename('fullpath')));
standaloneRuntime = fullfile(deviceFolder, 'internal');
sourceRuntime = fullfile(deviceFolder, '..', '_shared');

if isfolder(fullfile(standaloneRuntime, '+converter'))
    addpath(standaloneRuntime);
elseif isfolder(fullfile(sourceRuntime, '+converter'))
    addpath(sourceRuntime);
else
    error('ad9245:RuntimeNotFound', ...
        ['未找到 AD9245 公共运行内核。请保持交付包目录完整，' ...
        '或从 CW_513_ANALYSIS/9245_hy 目录运行。']);
end
end

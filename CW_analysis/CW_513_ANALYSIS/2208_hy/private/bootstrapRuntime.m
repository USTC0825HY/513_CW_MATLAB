function bootstrapRuntime()
%BOOTSTRAPRUNTIME Add the self-contained AD2208 runtime to the MATLAB path.

deviceFolder = fileparts(fileparts(mfilename('fullpath')));
standaloneRuntime = fullfile(deviceFolder, 'internal');
sourceRuntime = fullfile(deviceFolder, '..', '_shared');
if isfolder(fullfile(standaloneRuntime, '+converter'))
    addpath(standaloneRuntime);
elseif isfolder(fullfile(sourceRuntime, '+converter'))
    addpath(sourceRuntime);
else
    error('ad2208:RuntimeNotFound', ...
        ['未找到 CW_513_ANALYSIS 公共运行内核。请保持库目录完整，' ...
        '或从 CW_513_ANALYSIS/2208_hy 目录运行。']);
end
end

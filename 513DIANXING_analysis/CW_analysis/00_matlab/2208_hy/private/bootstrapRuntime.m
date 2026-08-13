function bootstrapRuntime()
%BOOTSTRAPRUNTIME Add the self-contained AD2208 runtime to the MATLAB path.

deviceFolder = fileparts(fileparts(mfilename('fullpath')));
standaloneRuntime = fullfile(deviceFolder, 'internal');
if isfolder(fullfile(standaloneRuntime, '+converter'))
    addpath(standaloneRuntime);
else
    error('ad2208:RuntimeNotFound', ...
        ['未找到 AD2208 独立运行内核。请保持 2208_hy 目录完整，' ...
        '或从 00_matlab/2208_hy 目录运行。']);
end
end

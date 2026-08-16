function result = run_da766_batch(dataRoot, scaleFolder, pairManifest)
%RUN_DA766_BATCH Run all supported DA766 analyses with explicit roots.
if nargin < 1 || isempty(dataRoot), error('cw513:DataRootRequired', ...
        '批处理必须显式提供DA766数据根目录。'); end
result = struct();
result.noise = dac_noise_analysis(fullfile(dataRoot, '03_DCNoise'), {}, '');
if nargin < 2 || isempty(scaleFolder)
    scaleFolder = localFirstFolder(dataRoot, {'01_Scale', '02_Scale', '03_Scale'});
end
if ~isempty(scaleFolder) && ~isempty(dir(fullfile(scaleFolder, '*.mat')))
    result.scale = dac_scale_analysis(scaleFolder, {}, '');
else
    result.scale = localUntested('scale', scaleFolder);
end
if nargin >= 3 && ~isempty(pairManifest)
    result.isolation = dac_isolation_analysis(dataRoot, pairManifest, '');
else
    result.isolation = localUntested('isolation', fullfile(dataRoot, '04_Isolation'));
end
end

function value = localUntested(analysisId, dataFolder)
value = struct('analysis', analysisId, 'dataFolder', dataFolder, ...
    'status', '未测试', 'reason', '需要显式配置刻度文件或隔离度配对清单');
end

function folder = localFirstFolder(rootFolder, names)
folder = '';
for k = 1:numel(names)
    candidate = fullfile(rootFolder, names{k});
    if isfolder(candidate)
        folder = candidate;
        return;
    end
end
end

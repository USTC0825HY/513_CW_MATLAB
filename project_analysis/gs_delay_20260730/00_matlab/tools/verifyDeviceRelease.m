function passed = verifyDeviceRelease(releaseFolder)
%VERIFYDEVICERELEASE Verify a package without using its source parent.

releaseFolder = char(releaseFolder);
if ~isfolder(releaseFolder)
    error('converter:build:ReleaseNotFound', '发布目录不存在：%s', releaseFolder);
end
requiredEntries = {'adc_sfdr_analysis.m', 'adc_bandwidth_analysis.m', ...
    'adc_isolation_analysis.m', 'adc_power_scale_analysis.m', ...
    'adc_inl_dnl_analysis.m'};
for fileIndex = 1:numel(requiredEntries)
    if ~isfile(fullfile(releaseFolder, requiredEntries{fileIndex}))
        error('converter:build:ReleaseFileMissing', ...
            '发布包缺少文件：%s', requiredEntries{fileIndex});
    end
end
if ~isfolder(fullfile(releaseFolder, 'internal', '+converter'))
    error('converter:build:ReleaseRuntimeMissing', '发布包缺少公共运行内核。');
end

originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
removeRepositorySourcePaths(releaseFolder);
addpath(releaseFolder);
addpath(fullfile(releaseFolder, 'internal'));
clear('adc_sfdr_analysis');
clear('converter.adc.fitSine');
resolvedCore = which('converter.adc.fitSine');
if isempty(resolvedCore) || ~startsWithIgnoreCase(resolvedCore, releaseFolder)
    error('converter:build:ExternalDependencyLeak', ...
        '公共内核未从独立包解析：%s', resolvedCore);
end

runStaticChecks(releaseFolder);
verifyBaseMatlabDependencies(releaseFolder, requiredEntries);
runSyntheticSmokeTest();
clear pathCleanup;
passed = true;
fprintf('独立包验证通过：%s\n', releaseFolder);
end

function removeRepositorySourcePaths(releaseFolder)
allPaths = strsplit(path, pathsep);
for pathIndex = 1:numel(allPaths)
    currentPath = allPaths{pathIndex};
    if isempty(currentPath) || startsWithIgnoreCase(currentPath, releaseFolder)
        continue;
    end
    if contains(currentPath, [filesep '00_matlab' filesep '_shared']) || ...
            contains(currentPath, [filesep '00_matlab' filesep '9245_hy'])
        rmpath(currentPath);
    end
end
end

function runStaticChecks(releaseFolder)
files = dir(fullfile(releaseFolder, '**', '*.m'));
for fileIndex = 1:numel(files)
    filePath = fullfile(files(fileIndex).folder, files(fileIndex).name);
    messages = checkcode(filePath, '-id');
    if ~isempty(messages)
        error('converter:build:StaticCheckFailed', ...
            '静态检查未通过：%s（%s，第 %d 行）', ...
            filePath, messages(1).id, messages(1).line);
    end
end
end

function verifyBaseMatlabDependencies(releaseFolder, entryFiles)
entryPaths = cellfun(@(name) fullfile(releaseFolder, name), ...
    entryFiles, 'UniformOutput', false);
[requiredFiles, products] = matlab.codetools.requiredFilesAndProducts(entryPaths);
for fileIndex = 1:numel(requiredFiles)
    if ~startsWithIgnoreCase(requiredFiles{fileIndex}, releaseFolder)
        error('converter:build:ExternalDependencyLeak', ...
            '发现发布目录之外的代码依赖：%s', requiredFiles{fileIndex});
    end
end
productNames = {products.Name};
extraProducts = setdiff(productNames, {'MATLAB'});
if ~isempty(extraProducts)
    error('converter:build:ToolboxDependency', ...
        '入口依赖非基础 MATLAB 产品：%s', strjoin(extraProducts, ', '));
end
end

function runSyntheticSmokeTest()
smokeFolder = [tempname '_ad9245_release_smoke'];
mkdir(smokeFolder);
smokeCleanup = onCleanup(@() rmdir(smokeFolder, 's'));
dataFolder = fullfile(smokeFolder, 'raw');
outputFolder = fullfile(smokeFolder, 'results');
mkdir(dataFolder);
sampleRate = 25e6;
time = (0:4095)' / sampleRate;
code = round(3500*sin(2*pi*1e6*time) + 20*sin(2*pi*2.2e6*time));
fileName = 'X3G_1MHz.csv';
fileId = fopen(fullfile(dataFolder, fileName), 'w');
if fileId < 0
    error('converter:build:CannotWriteSmokeData', '无法生成冒烟测试数据。');
end
fileCleanup = onCleanup(@() fclose(fileId));
fprintf(fileId, 'sample,ad9245_test_module[2]\n');
fprintf(fileId, '%d,%d\n', [(0:numel(code)-1); code(:).']);
clear fileCleanup;
results = adc_sfdr_analysis(dataFolder, {fileName}, outputFolder);
if height(results) ~= 1 || isempty(dir(fullfile( ...
        outputFolder, 'run_*', 'STATUS_SUCCESS.txt')))
    error('converter:build:SmokeTestFailed', '独立包合成数据冒烟测试失败。');
end
clear smokeCleanup;
end

function result = startsWithIgnoreCase(textValue, prefix)
textValue = char(textValue);
prefix = char(prefix);
result = numel(textValue) >= numel(prefix) && ...
    strcmpi(textValue(1:numel(prefix)), prefix);
end

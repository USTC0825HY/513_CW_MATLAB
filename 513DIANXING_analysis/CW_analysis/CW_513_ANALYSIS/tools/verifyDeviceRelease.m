function passed = verifyDeviceRelease(releaseFolder, spec)
%VERIFYDEVICERELEASE Verify a package without using its source parent.

releaseFolder = char(releaseFolder);
if ~isfolder(releaseFolder)
    error('converter:build:ReleaseNotFound', '发布目录不存在：%s', releaseFolder);
end
if nargin < 2 || isempty(spec)
    spec = inferSpec(releaseFolder);
end
requiredEntries = spec.entryFiles;
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
if startsWithIgnoreCase(spec.deviceId, 'DA')
    clear('converter.dac.fitTone');
    resolvedCore = which('converter.dac.fitTone');
else
    clear('converter.adc.fitSine');
    resolvedCore = which('converter.adc.fitSine');
end
if isempty(resolvedCore) || ~startsWithIgnoreCase(resolvedCore, releaseFolder)
    error('converter:build:ExternalDependencyLeak', ...
        '公共内核未从独立包解析：%s', resolvedCore);
end

runStaticChecks(releaseFolder);
verifyBaseMatlabDependencies(releaseFolder, spec);
runSyntheticSmokeTest(spec, releaseFolder);
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
    lowerPath = lower(currentPath);
    if contains(lowerPath, [filesep 'cw_513_analysis' filesep]) || ...
            contains(lowerPath, [filesep 'laser_analysis' filesep])
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

function verifyBaseMatlabDependencies(releaseFolder, spec)
entryFiles = spec.entryFiles;
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
extraProducts = setdiff(productNames, spec.allowedProducts);
if ~isempty(extraProducts)
    error('converter:build:ToolboxDependency', ...
        '入口依赖非基础 MATLAB 产品：%s', strjoin(extraProducts, ', '));
end
end

function runSyntheticSmokeTest(spec, releaseFolder)
if startsWithIgnoreCase(spec.deviceId, 'DA')
    runDacSyntheticSmokeTest(spec, releaseFolder);
    return;
end
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
if strcmpi(spec.deviceId, 'AD2208')
    fprintf(fileId, 'sample,c1,c2,yb2208_test_module[2]\n');
    fprintf(fileId, '%d,0,0,%d\n', [(0:numel(code)-1); code(:).']);
else
    fprintf(fileId, 'sample,ad9245_test_module[2]\n');
    fprintf(fileId, '%d,%d\n', [(0:numel(code)-1); code(:).']);
end
clear fileCleanup;
results = adc_sfdr_analysis(dataFolder, {fileName}, outputFolder);
if height(results) ~= 1 || isempty(dir(fullfile( ...
        outputFolder, 'run_*', 'STATUS_SUCCESS.txt')))
    error('converter:build:SmokeTestFailed', '独立包合成数据冒烟测试失败。');
end

clear smokeCleanup;
end

function runDacSyntheticSmokeTest(~, releaseFolder)
smokeFolder = [tempname '_dac_release_smoke'];
mkdir(smokeFolder);
smokeCleanup = onCleanup(@() rmdir(smokeFolder, 's')); %#ok<NASGU>
dataFolder = fullfile(smokeFolder, 'raw'); outputFolder = fullfile(smokeFolder, 'results'); %#ok<NASGU>
mkdir(dataFolder); mkdir(outputFolder);
sampleRate = 250e3; time = (0:4095)' / sampleRate;
voltage = 0.5 * sin(2*pi*1e3*time);
Tinterval = 1 / sampleRate; A = voltage;
save(fullfile(dataFolder, '1kHz_code_10000.mat'), 'A', 'Tinterval');
save(fullfile(dataFolder, '1kHz_code_20000.mat'), 'A', 'Tinterval');
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
addpath(releaseFolder);
addpath(fullfile(releaseFolder, 'internal'));
entryName = 'dac_scale_analysis';
if ~isfile(fullfile(releaseFolder, [entryName '.m']))
    error('converter:build:DacSmokeMissing', 'DA刻度入口缺失。');
end
result = feval(entryName, dataFolder, {}, outputFolder); %#ok<NASGU>
if isempty(dir(fullfile(outputFolder, 'run_*', 'STATUS_SUCCESS.txt')))
    error('converter:build:SmokeTestFailed', 'DA独立包合成数据冒烟测试失败。');
end
noiseOverride = struct('targetResolutionHz', 10, ...
    'minimumAsdSegmentCount', 1, 'formalEnabled', false, 'asdOnly', true);
noiseResult = feval('dac_noise_analysis', dataFolder, ...
    {'1kHz_code_10000.mat'}, outputFolder, noiseOverride); %#ok<NASGU>
end

function spec = inferSpec(releaseFolder)
versionPath = fullfile(releaseFolder, 'VERSION.txt');
if ~isfile(versionPath), error('converter:build:SpecMissing', '发布包缺少VERSION.txt。'); end
textValue = fileread(versionPath);
device = regexp(textValue, 'Device:\s*(\S+)', 'tokens', 'once');
if isempty(device), error('converter:build:SpecMissing', 'VERSION.txt缺少Device。'); end
spec = deviceReleaseRegistry(device{1});
end

function result = startsWithIgnoreCase(textValue, prefix)
textValue = char(textValue);
prefix = char(prefix);
result = numel(textValue) >= numel(prefix) && ...
    strcmpi(textValue(1:numel(prefix)), prefix);
end

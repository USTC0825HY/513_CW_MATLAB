function release = buildDeviceRelease(deviceName, version)
%BUILDDEVICERELEASE Build and verify a standalone device package.
%   RELEASE = BUILDDEVICERELEASE('AD9245') creates the folder and ZIP under
%   _release only after standalone verification succeeds.

if nargin < 1 || isempty(deviceName)
    deviceName = 'AD9245';
end
toolsFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(toolsFolder);
addpath(toolsFolder);
addpath(fullfile(repositoryRoot, '_shared'));
spec = deviceReleaseRegistry(deviceName);
if ~spec.releaseReady
    error('converter:build:DeviceNotReleaseReady', ...
        '%s 尚未确认参数，releaseReady=false，禁止构建。', spec.deviceId);
end
if nargin < 2 || isempty(version)
    version = spec.version;
end
version = char(version);
if ~strcmp(version, spec.version)
    error('converter:build:VersionMismatch', ...
        '请求版本 %s 与器件配置版本 %s 不一致。', version, spec.version);
end

releaseParent = fullfile(repositoryRoot, '_release');
if ~isfolder(releaseParent)
    mkdir(releaseParent);
end
folderName = sprintf('%s_分析程序_v%s', spec.deviceId, version);
releaseFolder = fullfile(releaseParent, folderName);
zipPath = [releaseFolder '.zip'];
if isfolder(releaseFolder) || isfile(zipPath)
    error('converter:build:ReleaseAlreadyExists', ...
        '发布目标已存在，请先归档旧版本：%s', releaseFolder);
end

stagingFolder = [tempname(releaseParent) '_staging'];
mkdir(stagingFolder);
stagingCleanup = onCleanup(@() removeStagingFolder(stagingFolder));
deviceFolder = fullfile(repositoryRoot, spec.folderName);
copyRequiredFiles(deviceFolder, stagingFolder, spec.entryFiles);
copyfile(fullfile(deviceFolder, 'private'), fullfile(stagingFolder, 'private'));
copyfile(fullfile(deviceFolder, 'README_先看.md'), stagingFolder);
mkdir(fullfile(stagingFolder, 'internal'));
copyfile(fullfile(repositoryRoot, '_shared', '+converter'), ...
    fullfile(stagingFolder, 'internal', '+converter'));
writeVersionFile(stagingFolder, spec, repositoryRoot);

verifyDeviceRelease(stagingFolder, spec);
writeHashManifest(stagingFolder);
movefile(stagingFolder, releaseFolder);
clear stagingCleanup;

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(releaseParent);
zip([folderName '.zip'], folderName);
clear folderCleanup;

release = struct('folder', releaseFolder, 'zip', zipPath, ...
    'deviceId', spec.deviceId, 'version', version, 'verified', true);
fprintf('独立交付包已通过验证：\n%s\n%s\n', releaseFolder, zipPath);
end

function copyRequiredFiles(sourceFolder, destinationFolder, fileNames)
for fileIndex = 1:numel(fileNames)
    sourcePath = fullfile(sourceFolder, fileNames{fileIndex});
    if ~isfile(sourcePath)
        error('converter:build:MissingEntry', '缺少入口文件：%s', sourcePath);
    end
    copyfile(sourcePath, destinationFolder);
end
end

function writeVersionFile(folder, spec, repositoryRoot)
fileId = fopen(fullfile(folder, 'VERSION.txt'), 'w');
if fileId < 0
    error('converter:build:CannotWriteVersion', '无法写入 VERSION.txt。');
end
cleanupObject = onCleanup(@() fclose(fileId));
fprintf(fileId, 'Device: %s\n', spec.deviceId);
fprintf(fileId, 'Version: %s\n', spec.version);
fprintf(fileId, 'GitRevision: %s\n', ...
    converter.runtime.getGitRevision(repositoryRoot));
end

function writeHashManifest(folder)
files = dir(fullfile(folder, '**', '*'));
files = files(~[files.isdir]);
relativePath = cell(numel(files), 1);
sha256 = cell(numel(files), 1);
sizeBytes = zeros(numel(files), 1);
for fileIndex = 1:numel(files)
    fullPath = fullfile(files(fileIndex).folder, files(fileIndex).name);
    relativePath{fileIndex} = strrep( ...
        fullPath(numel(folder)+2:end), '\', '/');
    sha256{fileIndex} = converter.runtime.sha256File(fullPath);
    sizeBytes(fileIndex) = files(fileIndex).bytes;
end
manifest = table(relativePath, sizeBytes, sha256, ...
    'VariableNames', {'RelativePath', 'SizeBytes', 'SHA256'});
converter.report.writeTable(manifest, fullfile(folder, 'SHA256SUMS.csv'));
end

function removeStagingFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

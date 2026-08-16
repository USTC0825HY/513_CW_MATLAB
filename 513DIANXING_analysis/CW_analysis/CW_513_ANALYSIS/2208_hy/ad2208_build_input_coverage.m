function coverage = ad2208_build_input_coverage(dataRoot)
%AD2208_BUILD_INPUT_COVERAGE Inventory and classify every AD2208 input CSV.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot) || ~isfolder(dataRoot)
    error('ad2208:DataRootNotFound', 'AD2208 数据根目录不存在。');
end
dataRoot = char(dataRoot);
fileInfo = dir(fullfile(dataRoot, '**', '*.csv'));
fileInfo = excludeGeneratedFiles(fileInfo);

fileCount = numel(fileInfo);
relativePath = strings(fileCount, 1);
fileSizeBytes = zeros(fileCount, 1);
modifiedAt = strings(fileCount, 1);
sha256 = strings(fileCount, 1);
for fileIndex = 1:fileCount
    filePath = fullfile(fileInfo(fileIndex).folder, fileInfo(fileIndex).name);
    relativePath(fileIndex) = string(strrep( ...
        erase(filePath, [dataRoot filesep]), filesep, '/'));
    fileSizeBytes(fileIndex) = fileInfo(fileIndex).bytes;
    modifiedAt(fileIndex) = string(datestr( ...
        fileInfo(fileIndex).datenum, 31)); %#ok<DATST>
    sha256(fileIndex) = string(converter.runtime.sha256File(filePath));
end

canonicalMask = startsWith(relativePath, '02_FrequencyResponse/');
canonicalHashes = sha256(canonicalMask);
coverageStatus = strings(fileCount, 1);
formalConclusion = repmat("暂不能判定", fileCount, 1);
reason = strings(fileCount, 1);
for fileIndex = 1:fileCount
    currentPath = relativePath(fileIndex);
    if startsWith(currentPath, '01_SFDR/') || ...
            startsWith(currentPath, '02_FrequencyResponse/') || ...
            startsWith(currentPath, '03_InputPowerScale/') || ...
            startsWith(currentPath, '05_INL_DNL/')
        coverageStatus(fileIndex) = "已处理";
        reason(fileIndex) = "已纳入对应分组的最新成功运行";
    elseif startsWith(currentPath, '输入频率带宽/') && ...
            any(sha256(fileIndex) == canonicalHashes)
        coverageStatus(fileIndex) = "重复数据";
        reason(fileIndex) = "与 02_FrequencyResponse 中已处理文件的 SHA-256 相同";
    elseif startsWith(currentPath, '输入频率带宽/')
        coverageStatus(fileIndex) = "数据不足";
        reason(fileIndex) = "单文件无频率标签且每通道仅一个点，无法计算 -3 dB 带宽";
    else
        coverageStatus(fileIndex) = "未处理";
        formalConclusion(fileIndex) = "未测试";
        reason(fileIndex) = "当前 AD2208 批处理未覆盖该目录类别";
    end
end

coverage = table(relativePath, fileSizeBytes, modifiedAt, sha256, ...
    coverageStatus, formalConclusion, reason, ...
    'VariableNames', {'RelativePath', 'FileSizeBytes', 'ModifiedAt', ...
    'SHA256', 'CoverageStatus', 'FormalConclusion', 'Reason'});
writetable(coverage, fullfile(dataRoot, 'AD2208_input_coverage.csv'));
end

function fileInfo = excludeGeneratedFiles(fileInfo)
keepFile = true(numel(fileInfo), 1);
for fileIndex = 1:numel(fileInfo)
    pathParts = strsplit(fileInfo(fileIndex).folder, filesep);
    generatedFolder = any(strcmpi(pathParts, 'result') | ...
        strcmpi(pathParts, 'results'));
    generatedRootFile = startsWith(fileInfo(fileIndex).name, 'AD2208_');
    keepFile(fileIndex) = ~generatedFolder && ~generatedRootFile;
end
fileInfo = fileInfo(keepFile);
end

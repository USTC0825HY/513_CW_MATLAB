function [fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, dialogTitle)
%SELECTCSVFILES Select one or more CSV files from a data directory.

if nargin < 1 || isempty(dataFolder)
    dataFolder = '';
end
if nargin < 2
    selectedFileNames = [];
end
if nargin < 3 || isempty(dialogTitle)
    dialogTitle = '选择 CSV 文件';
end

if isempty(dataFolder)
    dataFolder = uigetdir(pwd, [dialogTitle '：先选择数据目录']);
    if isequal(dataFolder, 0)
        fileNames = {};
        dataFolder = '';
        return;
    end
end
dataFolder = char(dataFolder);
if ~isfolder(dataFolder)
    error('converter:io:DataFolderNotFound', '数据目录不存在：%s', dataFolder);
end

if isempty(selectedFileNames)
    [selectedFileNames, selectedPath] = uigetfile( ...
        fullfile(dataFolder, '*.csv'), dialogTitle, 'MultiSelect', 'on');
    if isequal(selectedFileNames, 0)
        fileNames = {};
        return;
    end
    dataFolder = selectedPath;
end

if ischar(selectedFileNames) || isstring(selectedFileNames)
    selectedFileNames = cellstr(selectedFileNames);
end
fileNames = selectedFileNames(:).';

for fileIndex = 1:numel(fileNames)
    filePath = fullfile(dataFolder, fileNames{fileIndex});
    if ~isfile(filePath)
        error('converter:io:InputFileNotFound', '找不到输入文件：%s', filePath);
    end
end
end


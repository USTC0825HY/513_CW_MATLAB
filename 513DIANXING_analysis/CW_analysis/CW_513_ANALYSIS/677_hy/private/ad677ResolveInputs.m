function [dataFolder, selectedFiles, outputFolder] = ad677ResolveInputs( ...
        dataFolder, selectedFiles, outputFolder)
%AD677RESOLVEINPUTS Resolve direct-folder calls without changing raw data.

if isempty(dataFolder)
    dataFolder = uigetdir(pwd, '选择 AD677 CSV 所在目录');
end
if isequal(dataFolder, 0) || ~isfolder(dataFolder)
    error('ad677:DataFolderNotFound', 'AD677 数据目录不存在。');
end
dataFolder = char(dataFolder);
if isempty(selectedFiles)
    fileInfo = dir(fullfile(dataFolder, '*.csv'));
    selectedFiles = {fileInfo.name};
end
if isempty(selectedFiles)
    error('ad677:NoCsvFiles', '所选目录没有 AD677 CSV。');
end
selectedFiles = cellstr(string(selectedFiles));
if isempty(outputFolder)
    parentFolder = fileparts(dataFolder);
    [grandParent, parentName] = fileparts(parentFolder);
    if strcmpi(parentName, 'raw')
        outputFolder = fullfile(grandParent, 'result');
    else
        outputFolder = fullfile(dataFolder, 'result');
    end
end
end

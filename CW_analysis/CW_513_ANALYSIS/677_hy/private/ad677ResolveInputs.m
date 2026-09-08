function [dataFolder, selectedFiles, outputFolder] = ad677ResolveInputs( ...
        dataFolder, selectedFiles, outputFolder)
%AD677RESOLVEINPUTS Resolve direct-folder calls without changing raw data.

if isempty(dataFolder)
    dataFolder = pwd;
end
if ~isfolder(dataFolder)
    error('ad677:DataFolderNotFound', 'AD677 数据目录不存在。');
end
dataFolder = char(dataFolder);
[selectedFiles, dataFolder] = converter.io.selectCsvFiles(dataFolder, selectedFiles, ...
    '选择本次 AD677 CSV（可多选）');
if isempty(selectedFiles)
    outputFolder = '';
    return;
end
selectedFiles = cellstr(string(selectedFiles));
if isempty(outputFolder)
    parentFolder = fileparts(dataFolder);
    [grandParent, parentName] = fileparts(parentFolder);
    if strcmpi(parentName, 'raw')
        outputFolder = fullfile(grandParent, 'results');
    else
        outputFolder = converter.io.resolveOutputBase(dataFolder, []);
    end
end
end

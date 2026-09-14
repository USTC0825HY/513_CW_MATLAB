function [fileNames, dataFolder] = selectCsvFiles(dataFolder, selectedFileNames, dialogTitle)
%SELECTCSVFILES Choose captures, or validate explicit files without a dialog.
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFileNames = []; end
if nargin < 3 || isempty(dialogTitle), dialogTitle = '选择本次 CSV 文件'; end
[fileNames, dataFolder] = converter.io.selectCaptureFiles( ...
    dataFolder, selectedFileNames, '.csv', dialogTitle);
end


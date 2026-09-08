function [fileNames, dataFolder] = selectMatFiles(dataFolder, selectedFileNames, dialogTitle)
%SELECTMATFILES Choose captures, or validate explicit files without a dialog.
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFileNames = []; end
if nargin < 3 || isempty(dialogTitle), dialogTitle = '选择本次 MAT 文件'; end
[fileNames, dataFolder] = converter.io.selectCaptureFiles( ...
    dataFolder, selectedFileNames, '.mat', dialogTitle);
end

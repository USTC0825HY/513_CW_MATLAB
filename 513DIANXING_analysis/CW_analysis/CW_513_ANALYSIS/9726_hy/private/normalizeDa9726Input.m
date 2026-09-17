function [dataFolder, selectedFiles] = normalizeDa9726Input(dataFolder, selectedFiles)
%NORMALIZEDA9726INPUT Accept a single absolute MAT path as the first input.
%   The public DAC entries traditionally take a folder followed by a file
%   list.  Accepting a file path as the first argument is useful when a
%   capture was copied to another machine, while keeping the old signature.

if nargin < 1 || isempty(dataFolder) || ~isfile(dataFolder)
    return;
end
if nargin < 2 || isempty(selectedFiles)
    selectedFiles = {char(dataFolder)};
else
    error('converter:io:FolderOrFileExpected', ...
        '第一个参数已经是MAT文件时，第二个参数必须留空。');
end
dataFolder = fileparts(char(dataFolder));
end

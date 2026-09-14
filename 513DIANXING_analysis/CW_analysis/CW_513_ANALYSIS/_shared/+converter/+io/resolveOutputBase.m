function outputBase = resolveOutputBase(dataFolder, outputFolder)
%RESOLVEOUTPUTBASE Resolve the parent folder used for timestamped runs.

if nargin >= 2 && ~isempty(outputFolder)
    outputBase = char(outputFolder);
    return;
end

dataFolder = char(java.io.File(char(dataFolder)).getCanonicalPath());
[parentFolder, leafFolder] = fileparts(dataFolder);
if strcmpi(leafFolder, 'raw')
    outputBase = fullfile(parentFolder, 'results');
else
    outputBase = fullfile(char(dataFolder), 'results');
end
end


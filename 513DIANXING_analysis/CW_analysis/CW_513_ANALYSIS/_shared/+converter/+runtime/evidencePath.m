function filePath = evidencePath(runFolder, fileName)
%EVIDENCEPATH Resolve a result file in current or historical bundle layouts.
filePath = fullfile(runFolder, 'evidence', fileName);
if ~isfile(filePath)
    filePath = fullfile(runFolder, fileName);
end
end

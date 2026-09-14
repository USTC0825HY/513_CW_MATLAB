function writeRunManifest(runFolder, dataFolder, fileNames)
%WRITERUNMANIFEST Write traceability data for all selected inputs.

fileCount = numel(fileNames);
fileSizeBytes = zeros(fileCount, 1);
modifiedAt = cell(fileCount, 1);
sha256 = cell(fileCount, 1);
for fileIndex = 1:fileCount
    fileName = char(fileNames{fileIndex});
    filePath = converter.io.resolveInputPath(dataFolder, fileName);
    info = dir(filePath);
    fileSizeBytes(fileIndex) = info.bytes;
    % Keep datestr because the delivered program must run on MATLAB R2018.
    modifiedAt{fileIndex} = datestr(info.datenum, 31); %#ok<DATST>
    sha256{fileIndex} = converter.runtime.sha256File(filePath);
end
manifest = table(fileNames(:), fileSizeBytes, modifiedAt, sha256, ...
    'VariableNames', {'FileName', 'FileSizeBytes', 'ModifiedAt', 'SHA256'});
converter.report.writeTable(manifest, fullfile(runFolder, 'run_manifest.csv'));
end

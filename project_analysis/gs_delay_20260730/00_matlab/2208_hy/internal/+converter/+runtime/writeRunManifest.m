function writeRunManifest(runFolder, dataFolder, fileNames)
%WRITERUNMANIFEST Write traceability data for all selected inputs.

fileCount = numel(fileNames);
fileSizeBytes = zeros(fileCount, 1);
modifiedAt = cell(fileCount, 1);
for fileIndex = 1:fileCount
    filePath = fullfile(dataFolder, fileNames{fileIndex});
    info = dir(filePath);
    fileSizeBytes(fileIndex) = info.bytes;
    % Keep datestr because the delivered program must run on MATLAB R2018.
    modifiedAt{fileIndex} = datestr(info.datenum, 31); %#ok<DATST>
end
manifest = table(fileNames(:), fileSizeBytes, modifiedAt, ...
    'VariableNames', {'FileName', 'FileSizeBytes', 'ModifiedAt'});
converter.report.writeTable(manifest, fullfile(runFolder, 'run_manifest.csv'));
end

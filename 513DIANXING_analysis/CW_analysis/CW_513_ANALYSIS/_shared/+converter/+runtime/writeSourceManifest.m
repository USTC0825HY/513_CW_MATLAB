function writeSourceManifest(runFolder, fileName)
%WRITESOURCEMANIFEST Identify current source including uncommitted changes.
if nargin<2, fileName='script_source_manifest.csv'; end
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
files=dir(fullfile(root,'**','*.m'));
paths=cell(numel(files),1); hashes=paths;
for k=1:numel(files)
    paths{k}=fullfile(files(k).folder,files(k).name);
    hashes{k}=converter.runtime.sha256File(paths{k});
end
converter.report.writeTable(table(paths,hashes,'VariableNames',{'SourcePath','SHA256'}), ...
    fullfile(runFolder,fileName));
end

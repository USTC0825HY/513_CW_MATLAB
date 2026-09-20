function finalizeBundle(runFolder, config)
%FINALIZEBUNDLE Export the concise workbook and organize a new result bundle.
%   Existing historical bundles are never migrated automatically. This is
%   called only by the current run, after all computations and exports finish.
evidence = fullfile(runFolder,'evidence');
if ~isfolder(evidence), mkdir(evidence); end
workbook = fullfile(runFolder,'结果汇总.xlsx');
if ~isfile(workbook)
    sheets=converter.report.buildSummarySheets(runFolder,config);
    converter.report.writeSummaryXlsx(workbook,sheets);
end
% A configuration MAT is not a duplicate of the full numeric result MAT.
files=dir(runFolder); files=files(~[files.isdir]);
for k=1:numel(files)
    [~,~,ext]=fileparts(files(k).name);
    if strcmpi(ext,'.png') || strcmpi(ext,'.xlsx'), continue; end
    destination=fullfile(evidence,files(k).name);
    if isfile(destination)
        error('converter:runtime:EvidenceCollision','证据文件已存在，拒绝覆盖：%s',destination);
    end
    movefile(fullfile(runFolder,files(k).name),destination);
end
% Update embedded output links, not raw input paths or root folder handles.
csvFiles=dir(fullfile(evidence,'*.csv'));
for k=1:numel(csvFiles)
    p=fullfile(evidence,csvFiles(k).name);
    text=fileread(p);
    if ~contains(text,runFolder), continue; end
    tableValue=readtable(p,'Delimiter',',','TextType','string');
    updated=converter.runtime.refreshResultPaths(tableValue,runFolder);
    if ~isequaln(tableValue,updated), converter.report.writeTable(updated,p); end
end
matFiles=dir(fullfile(evidence,'*result.mat'));
for k=1:numel(matFiles)
    p=fullfile(evidence,matFiles(k).name); original=load(p);
    updated=converter.runtime.refreshResultPaths(original,runFolder);
    if ~isequaln(original,updated), save(p,'-struct','updated','-v7.3'); end
end
marker=fopen(fullfile(evidence,'bundle_layout.txt'),'w');
if marker<0, error('converter:runtime:LayoutWriteFailed','无法记录输出布局。'); end
cleanup=onCleanup(@() fclose(marker)); %#ok<NASGU>
fprintf(marker,'LayoutVersion: 2\nSummary: ../结果汇总.xlsx\nFigures: ../*.png\nEvidence: .\n');
end

function report = run_platform_output_tests(workFolder)
%RUN_PLATFORM_OUTPUT_TESTS Text/array fidelity, decoded preview and diagnostics.
bridge=fileparts(fileparts(mfilename('fullpath')));
root=fileparts(fileparts(bridge));
savedPath=path; savedFolder=pwd;
cleanup=onCleanup(@() restore(savedPath,savedFolder));
addpath(bridge); addpath(fullfile(root,'_shared'));
if ~isfolder(workFolder), mkdir(workFolder); end
folder=fullfile(workFolder,'synthetic_saved_run'); mkdir(folder);
config=struct('deviceId','synthetic','analysisId','adapter_test');
save(fullfile(folder,'run_config.mat'),'config');
writetable(table(1,'VariableNames',{'SingleValue'}),fullfile(folder,'test_summary.csv'));
fig=figure('Visible','off');
subplot(1,2,1); plot(1,2,'o'); title('Single point'); xlabel('Frequency (Hz)');
subplot(1,2,2); imagesc([3;4]); title('Two rows');
savefig(fig,fullfile(folder,'adapter.fig')); close(fig);
initial=struct('warnings',{{}});
response=cw513_platform_outputs(initial,folder,struct());
assert(numel(response.plots)==2 && numel(response.tables)==1);
line=response.plots{find(cellfun(@(x)strcmp(x.kind,'line'),response.plots),1)};
heat=response.plots{find(cellfun(@(x)strcmp(x.kind,'heatmap'),response.plots),1)};
assert(strcmp(line.title,'Single point'));
assert(strcmp(line.x_label,'Frequency (Hz)'));
assert(iscell(line.series{1}.x) && isequal(line.series{1}.x,{1}));
assert(iscell(heat.matrix{1}) && isequal(heat.matrix{1},{3}));
text=jsonencode(response);
assert(contains(text,'"x":[1]') && contains(text,'"matrix":[[3],[4]]'));
csv=fullfile(workFolder,'boundary.csv');
fid=fopen(csv,'w'); closer=onCleanup(@() fclose(fid));
fprintf(fid,'Sample in Buffer,Sample in Window,TRIGGER,ADC1_JG15\n');
fprintf(fid,'0,0,0,0000\n1,1,0,7FFF\n2,2,0,8000\n3,3,0,FFFF\n');
clear closer;
job=struct('schema_version',1,'action','preview','entry_id','ad2208.ila_noise', ...
    'data_folder',workFolder,'selected_files',{{csv}},'options',struct('inputRadix','hex'));
r=cw513_platform(job,fullfile(workFolder,'boundary_preview.json'));
assert(r.ok); assert(isequal(r.plots{1}.series{1}.y,{0,32767,-32768,-1}));
listing=dir(fullfile(bridge,'**','*.m'));
c= jsondecode(fileread(fullfile(bridge,'catalog.json')));
adapters=unique(string({c.entries.config_adapter}));
files=arrayfun(@(x)fullfile(x.folder,x.name),listing,'UniformOutput',false);
for k=1:numel(adapters)
    index=find(strcmp({c.entries.config_adapter},adapters(k)),1);
    files{end+1}=fullfile(root,c.entries(index).folder,[char(adapters(k)) '.m']); %#ok<AGROW>
end
diagnostics=cell(1,numel(files));
for k=1:numel(files)
    diagnostics{k}=struct('file',files{k},'messages',{num2cell(checkcode(files{k},'-id'))});
end
report=struct('text_and_singleton_arrays','passed','hex_boundaries','passed', ...
    'checked_files',numel(files),'diagnostics',{diagnostics});
fid=fopen(fullfile(workFolder,'output_contract_report.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(report)); fclose(fid);
disp(report);
end
function restore(savedPath,savedFolder)
path(savedPath); cd(savedFolder);
end

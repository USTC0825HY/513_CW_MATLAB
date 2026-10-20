function report = run_platform_contract_tests(workFolder,picoFixture)
%RUN_PLATFORM_CONTRACT_TESTS Catalog, JSON, special signatures and outputs.
bridge=fileparts(fileparts(mfilename('fullpath')));
oldPath=path; oldFolder=pwd;
cleanup=onCleanup(@() restore(oldPath,oldFolder));
restoredefaultpath; addpath(bridge);
if ~isfolder(workFolder), mkdir(workFolder); end
base=struct('schema_version',1,'action','catalog');
c=cw513_platform(base); check(c);
defaults=cell(1,26);
for k=1:26
    fprintf('Default contract %d/26: %s\n',k,c.entries{k}.id);
    j=struct('schema_version',1,'action','defaults','entry_id',c.entries{k}.id);
    r=cw513_platform(j); check(r);
    defaults{k}=r;
    assert(strcmp(r.config_source,fullfile(fileparts(fileparts(bridge)), ...
        c.entries{k}.folder,[c.entries{k}.config_adapter '.m'])));
end
save(fullfile(workFolder,'default_contracts.mat'),'defaults');
j=struct('schema_version',1,'action','run','entry_id','ad2208.pico_noise', ...
    'data_folder',fileparts(picoFixture),'selected_files',{{picoFixture}}, ...
    'output_folder',fullfile(workFolder,'error_output'));
r=cw513_platform(j); assert(~r.ok&&strcmp(r.error.identifier,'cw513:platform:BoardRequired'));
j.options=struct('boardType','jianding');
r=cw513_platform(j); assert(~r.ok&&strcmp(r.error.identifier,'cw513:platform:InterfaceRequired'));
assert(~isfolder(j.output_folder));
j.action='defaults'; j.entry_id='da9726.noise'; j.options=struct('sampleRate',1000);
r=cw513_platform(j); assert(~r.ok&&strcmp(r.error.identifier,'cw513:platform:ManagedOption'));
j.options=struct(); j.special=struct('tone_frequency_hz',1525);
r=cw513_platform(j); assert(~r.ok&&strcmp(r.error.identifier,'cw513:platform:UnsupportedSpecial'));
% All three joint-noise entry signatures consume the same explicit MAT A.
ids={'ad2208.pico_noise','ad9245.pico_noise','ad677.pico_noise'};
interfaces={'ADC6_JG24','X3G','677_1'};
picoRuns=cell(1,3);
for k=1:3
    j=struct('schema_version',1,'action','run','entry_id',ids{k}, ...
        'data_folder',fileparts(picoFixture),'selected_files',{{picoFixture}}, ...
        'output_folder',fullfile(workFolder,['pico_' num2str(k)]), ...
        'options',struct('boardType','jianding','waveVariable','A'));
    if k==2, j.options.interfaces=interfaces(k);
    else, j.options.interface=interfaces{k}; end
    r=cw513_platform(j,fullfile(workFolder,['pico_' num2str(k) '.json']));
    check(r); assert(~isempty(r.tables)); assert(~isempty(r.plots));
    picoRuns{k}=r.run_folder;
end
% DC output retains its original CSV layout and emits a numeric table.
raw=fullfile(workFolder,'raw'); mkdir(raw);
codes=[-32768 -24577 -16385 -8193 0 8191 16383 24575 32767];
A=repelem(codes(:)*1e-4,1000); Tinterval=1/2000;
dc=fullfile(raw,'JG18_DC.mat'); save(dc,'A','Tinterval');
j=struct('schema_version',1,'action','run','entry_id','da9726.output_voltage', ...
    'data_folder',raw,'selected_files',{{dc}},'output_folder',fullfile(workFolder,'dc'), ...
    'options',struct('channelLabels',{{'JG18'}}));
r=cw513_platform(j,fullfile(workFolder,'dc.json')); check(r);
assert(~isempty(r.tables)&&~isempty(r.plots));
t=readtable(fullfile(r.run_folder,'output_voltage_summary.csv'));
assert(abs(t.slope_v_per_code(1)-1e-4)<1e-12);
% Explicit JSON-like power records become the original dedicated table.
files=cell(1,3); levels=[0.4 0.8 1.2]; records=struct([]);
for k=1:3
    values=round((levels(k)/2e-5/2)*sin(2*pi*1e6*(0:8191)'/100e6));
    files{k}=sprintf('ADC1_JG15_capture_%d.csv',k);
    fid=fopen(fullfile(raw,files{k}),'w'); closer=onCleanup(@() fclose(fid));
    fprintf(fid,'Sample in Buffer,Sample in Window,TRIGGER,ADC1_JG15\n');
    fprintf(fid,'%d,%d,0,%d\n',[(0:8191)' (0:8191)' values].');
    clear closer;
    records(k).FileName=files{k}; records(k).InputVoltageVpp=levels(k);
end
j=struct('schema_version',1,'action','run','entry_id','ad2208.power_scale', ...
    'data_folder',raw,'selected_files',{files},'output_folder',fullfile(workFolder,'power'), ...
    'options',struct('inputRadix','decimal','powerSetpoints',records));
r=cw513_platform(j,fullfile(workFolder,'power.json')); check(r); assert(numel(r.tables)==2);
t=readtable(fullfile(r.run_folder,'evidence','ADC_vpp_codepp_summary.csv'));
assert(abs(t.SlopeVppPerCodePp(1)-2e-5)<1e-8);
% Static diagnostics are saved without suppressing compiler errors.
m=dir(fullfile(bridge,'**','*.m'));
diagnostics=cell(numel(m),1);
for k=1:numel(m)
    diagnostics{k}=struct('file',fullfile(m(k).folder,m(k).name), ...
        'messages',checkcode(fullfile(m(k).folder,m(k).name),'-id'));
end
report=struct('defaults_passed',26,'pico_runs',{picoRuns}, ...
    'dc_output_verified',true,'power_setpoints_verified',true);
save(fullfile(workFolder,'contract_report.mat'),'report','diagnostics');
disp(report);
end

function check(r)
if ~r.ok, disp(r.error); error('cw513:contractTest:BridgeError','%s',r.error.message); end
end
function restore(p,f)
path(p); cd(f); close all force;
end

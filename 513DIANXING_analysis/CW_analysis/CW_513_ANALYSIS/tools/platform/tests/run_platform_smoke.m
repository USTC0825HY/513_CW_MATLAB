function report = run_platform_smoke(workFolder,skipDefaults)
%RUN_PLATFORM_SMOKE Synthetic, offline bridge/direct numerical equivalence.
% Existing source data and golden baselines are never edited.
bridge = fileparts(fileparts(mfilename('fullpath')));
if nargin<2, skipDefaults=false; end
root = fileparts(fileparts(bridge));
oldPath = path; oldFolder = pwd;
cleanup = onCleanup(@() restore(oldPath,oldFolder));
restoredefaultpath;
addpath(bridge);
if ~isfolder(workFolder), mkdir(workFolder); end
raw = fullfile(workFolder,'synthetic_inputs'); mkdir(raw);
base = struct('schema_version',1,'action','catalog');
c = cw513_platform(base); check(c); assert(numel(c.entries)==26);
for k=1:numel(c.entries)
    if skipDefaults, break; end
    fprintf('Defaults %d/26: %s\n',k,c.entries{k}.id);
    job = struct('schema_version',1,'action','defaults','entry_id',c.entries{k}.id);
    response = cw513_platform(job);
    check(response); assert(~isempty(response.fields));
end
bad = struct('schema_version',1,'action','preview','entry_id','ad2208.ila_noise');
r = cw513_platform(bad); assert(~r.ok && strcmp(r.error.identifier,'cw513:platform:FilesRequired'));
bad.action = 'defaults'; bad.options = struct('samplRate',100);
r = cw513_platform(bad); assert(~r.ok && strcmp(r.error.identifier,'cw513:platform:UnsupportedOption'));
rng(513,'twister');
n = 131072;
codes = round(20*randn(n,1));
csv = fullfile(raw,'ADC1_JG15_decimal.csv');
writeCsv(csv,codes,false);
hexCsv = fullfile(raw,'ADC1_JG15_hex.csv');
writeCsv(hexCsv,codes,true);
job = struct('schema_version',1,'action','preview','entry_id','ad2208.ila_noise', ...
    'data_folder',raw,'selected_files',{{csv}}, ...
    'options',struct('inputRadix','decimal','boardType','jianding', ...
    'inputChannels',{{'ADC1_JG15'}}));
decimal = cw513_platform(job,fullfile(workFolder,'preview_decimal.json')); check(decimal);
job.selected_files = {hexCsv}; job.options.inputRadix = 'hex';
hex = cw513_platform(job); check(hex);
assert(isequal(decimal.plots{1}.series{1}.y,hex.plots{1}.series{1}.y));
job.selected_files = {csv}; job.options.inputRadix = 'decimal';
job.action = 'run'; job.output_folder = fullfile(workFolder,'adc_bridge');
adc = cw513_platform(job,fullfile(workFolder,'adc_response.json')); check(adc);
assert(~isempty(adc.tables)); assert(~isempty(adc.plots));
assert(~contains(adc.plots{1}.x_label,'S a m p l e'));
cd(fullfile(root,'2208_hy')); addpath(pwd); addpath(fullfile(root,'_shared'));
set(groot,'DefaultFigureVisible','off');
direct = adc_ila_noise_analysis(raw,{csv},fullfile(workFolder,'adc_direct'),job.options);
compareSummary(direct.summary,readtable(fullfile(adc.run_folder,'evidence', ...
    'AD2208_input_noise_summary.csv'),'TextType','string'));
% Independently verify the saved single-segment spectrum and calibration.
saved = load(fullfile(adc.run_folder,'evidence','AD2208_input_noise_result.mat'));
cal = saved.calibration(1).slopeVPerCode;
[independentPsd,frequency] = pwelch((codes-mean(codes))*cal,hanning(n),0,n,100e6);
spectra = dir(fullfile(adc.run_folder,'evidence','*_PSD_ASD.csv'));
assert(~isempty(spectra));
actualSpectrum = readtable(fullfile(spectra(1).folder,spectra(1).name));
assert(height(actualSpectrum)==numel(frequency));
assert(any(varfun(@(v) isnumeric(v)&&numel(v)==numel(independentPsd)&& ...
    max(abs(v-independentPsd))<1e-20,actualSpectrum,'OutputFormat','uniform')));
% PICO contains two channels: explicit A must win, and preview retains gain.
fs=2048; Tinterval=1/fs; t=(0:fs*20-1)'/fs;
A=100*(3e-6*randn(size(t))+2e-6*sin(2*pi*t)); B=10*A;
mat = fullfile(raw,'JG18_noise.mat'); save(mat,'A','B','Tinterval','-v7');
options = struct('dataVariables',{{'A'}},'integratedBandHz',[10 800]);
job=struct('schema_version',1,'action','preview','entry_id','da9726.noise', ...
    'data_folder',raw,'selected_files',{{mat}},'options',options);
p=cw513_platform(job,fullfile(workFolder,'pico_preview.json')); check(p);
assert(strcmp(p.metadata.variableName,'A'));
job.action='run'; job.output_folder=fullfile(workFolder,'dac_bridge');
dac=cw513_platform(job,fullfile(workFolder,'dac_response.json')); check(dac);
assert(~isempty(dac.tables)); assert(~isempty(dac.plots));
rmpath(fullfile(root,'2208_hy'));
cd(fullfile(root,'9726_hy')); addpath(pwd);
direct=dac_noise_analysis(raw,{mat},fullfile(workFolder,'dac_direct'),options);
actual=readtable(fullfile(dac.run_folder,'evidence','dac_noise_summary.csv'),'TextType','string');
compareSummary(direct.summary,actual);
v=A/100; v=v-mean(v);
[psd,f]=pwelch(v,hann(fs/0.2,'periodic'),fs/0.2/2,fs/0.2,fs);
[~,one]=min(abs(f-1)); band=f>=10 & f<=800;
assert(abs(actual.asd_at_1hz_uV_per_sqrtHz-sqrt(psd(one))*1e6)<1e-10);
assert(abs(actual.integrated_noise_uVrms-sqrt(trapz(f(band),psd(band)))*1e6)<1e-10);
report=struct('catalog_count',26,'defaults_passed',26*~skipDefaults, ...
    'adc_bridge_run',adc.run_folder,'dac_bridge_run',dac.run_folder, ...
    'numeric_comparison','bridge vs public entry and independent pwelch passed', ...
    'hardware_validation',false);
save(fullfile(workFolder,'platform_smoke_report.mat'),'report');
disp(report);
end

function check(response)
if ~response.ok
    disp(response.error);
    error('cw513:platformTest:BridgeError','%s: %s',response.error.identifier,response.error.message);
end
end

function writeCsv(file,codes,hex)
fid=fopen(file,'w'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'Sample in Buffer,Sample in Window,TRIGGER,ADC1_JG15\n');
if hex
    words=mod(codes,65536);
    for k=1:numel(codes), fprintf(fid,'%d,%d,0,%04X\n',k-1,k-1,words(k)); end
else
    fprintf(fid,'%d,%d,0,%d\n',[(0:numel(codes)-1)' (0:numel(codes)-1)' codes].');
end
end

function compareSummary(expected,actual)
assert(height(expected)==height(actual));
names=intersect(expected.Properties.VariableNames,actual.Properties.VariableNames);
count=0;
for k=1:numel(names)
    a=expected.(names{k}); b=actual.(names{k});
    if isnumeric(a) || islogical(a)
        count=count+1;
        assert(isequal(isnan(a),isnan(b)));
        mask=isfinite(a);
        assert(all(abs(double(a(mask))-double(b(mask))) <= 1e-10*max(1,abs(double(a(mask))))));
    end
end
assert(count>=10);
end

function restore(savedPath,savedFolder)
path(savedPath); cd(savedFolder); close all force;
end

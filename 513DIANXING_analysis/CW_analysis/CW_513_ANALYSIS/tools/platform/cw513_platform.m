function response = cw513_platform(job, responsePath)
%CW513_PLATFORM File-based, noninteractive adapter to the 26 public entries.
%   RESPONSE = CW513_PLATFORM(JOB_JSON, RESPONSE_JSON) runs catalog,
%   defaults, preview or run. JOB may also be a scalar struct for tests.
%   Existing numerical kernels and public function signatures are retained.
if nargin < 2, responsePath = ''; end
response = struct('schema_version',1,'action','','entry_id','', ...
    'ok',false,'status','error','warnings',{{}},'error',[], ...
    'tables',{{}},'plots',{{}},'artifacts',{{}});
originalPath = path;
originalFolder = pwd;
originalVisibility = get(groot,'DefaultFigureVisible');
cleanup = onCleanup(@() localRestore(originalPath,originalFolder,originalVisibility));
bridgeFolder = fileparts(mfilename('fullpath'));
libraryRoot = fileparts(fileparts(bridgeFolder));
beforeRuns = {};
outputBase = '';
try
    if ischar(job) || (isstring(job) && isscalar(job))
        job = jsondecode(fileread(char(job)));
    end
    validateattributes(job,{'struct'},{'scalar'});
    if ~isfield(job,'schema_version') || ~isequal(job.schema_version,1)
        error('cw513:platform:SchemaVersion','schema_version must equal 1.');
    end
    response.action = localText(job,'action','');
    response.entry_id = localText(job,'entry_id','');
    if isfield(job,'job_id'), response.job_id = job.job_id; end
    catalog = jsondecode(fileread(fullfile(bridgeFolder,'catalog.json')));
    if strcmp(response.action,'catalog')
        response.entries = num2cell(catalog.entries);
    else
        match = find(strcmp({catalog.entries.id},response.entry_id));
        if numel(match) ~= 1
            error('cw513:platform:UnknownEntry','Unknown entry_id: %s',response.entry_id);
        end
        entry = catalog.entries(match);
        localSelectPath(libraryRoot,entry);
        config = feval(entry.config_adapter,entry.config_branch);
        options = localOptions(job,entry,config);
        localValidateSpecial(job,entry);
        switch response.action
            case 'defaults'
                response.config = config;
                response.fields = cw513_platform_fields(config,entry);
                response.config_source = which(entry.config_adapter);
                response.entry = entry;
            case 'preview'
                [folder,files] = localInputs(job,entry,false);
                response = localPreview(response,job,entry,config,options,folder,files);
            case 'run'
                [folder,files] = localInputs(job,entry,true);
                outputBase = localText(job,'output_folder','');
                if isempty(outputBase)
                    error('cw513:platform:OutputRequired', ...
                        'Specify output_folder for a reproducible platform task.');
                end
                outputBase = char(java.io.File(outputBase).getCanonicalPath());
                localRunContract(job,entry,options,files);
                % No source input can be used as the task's output directory.
                if any(strcmpi(files,outputBase)) || isfile(outputBase)
                    error('cw513:platform:OutputConflict','output_folder must be a directory.');
                end
                beforeRuns = localRunFolders(outputBase);
                if strcmp(entry.metric,'output_voltage')
                    collision = fullfile(outputBase, ...
                        ['run_' datestr(now,'yyyymmdd_HHMMSS') '_output_voltage']); %#ok<DATST,TNOW1>
                    if isfolder(collision)
                        error('cw513:platform:OutputCollision', ...
                            'A DC output run already exists for this second. Retry with a new task output folder.');
                    end
                end
                set(groot,'DefaultFigureVisible','off');
                localGuardDialogs(bridgeFolder);
                result = localInvoke(job,entry,folder,files,outputBase,options);
                runFolder = localResultFolder(result,outputBase,beforeRuns);
                response = cw513_platform_outputs(response,runFolder,result);
                evidence = fullfile(runFolder,'evidence');
                if ~isfolder(evidence), mkdir(evidence); end
                localWriteJson(fullfile(evidence,'platform_job.json'),job);
                response.entry_file = which(entry.function);
                response.matlab_version = version;
            otherwise
                error('cw513:platform:UnknownAction', ...
                    'action must be catalog, defaults, preview or run.');
        end
    end
    response.ok = true;
    if strcmp(response.status,'error'), response.status = 'success'; end
catch exception
    response.ok = false;
    response.status = 'error';
    response.error = struct('identifier',exception.identifier, ...
        'message',exception.message,'stack',{num2cell(exception.stack)});
    if ~isempty(outputBase)
        created = setdiff(localRunFolders(outputBase),beforeRuns,'stable');
        response.failed_run_folders = created;
    end
end
if ~isempty(responsePath), localWriteJson(char(responsePath),response); end
end

function localRestore(savedPath,savedFolder,savedVisibility)
path(savedPath);
cd(savedFolder);
set(groot,'DefaultFigureVisible',savedVisibility);
end

function localSelectPath(root,entry)
% Select a device without genpath or an unrelated MATLAB workflow on path.
cd(root);
parts = strsplit(path,pathsep);
for k = 1:numel(parts)
    if contains(strrep(parts{k},'\','/'),'/CW_513_ANALYSIS/') || ...
            endsWith(strrep(parts{k},'\','/'),'/CW_513_ANALYSIS')
        if isfolder(parts{k}), rmpath(parts{k}); end
    end
end
addpath(fullfile(root,'_shared'),'-begin');
addpath(fullfile(root,'tools','platform'),'-begin');
deviceFolder = fullfile(root,entry.folder);
addpath(deviceFolder,'-begin');
cd(deviceFolder);
resolved = which(entry.function);
expected = fullfile(deviceFolder,[entry.function '.m']);
if ~strcmpi(char(java.io.File(resolved).getCanonicalPath()), ...
        char(java.io.File(expected).getCanonicalPath()))
    error('cw513:platform:EntryPathMismatch','Resolved entry differs from catalog: %s',resolved);
end
end

function options = localOptions(job,entry,config)
options = struct();
if isfield(job,'options') && ~isempty(job.options), options = job.options; end
validateattributes(options,{'struct'},{'scalar'});
if isfield(options,'configOverride')
    outer = setdiff(fieldnames(options),{'configOverride','powerSetpoints','metadata'});
    if ~isempty(outer)
        error('cw513:platform:MixedOverrideStyles','Use options fields or configOverride, not both.');
    end
    original = options;
    options = options.configOverride;
    for name = {'powerSetpoints','metadata'}
        if isfield(original,name{1}), options.(name{1}) = original.(name{1}); end
    end
end
locked = {'deviceId','analysisId','version','releaseReady','dataFolder', ...
    'outputFolder','outputRoot','inputFiles','entries','selectedFiles', ...
    'pairManifest','showFigures','allowRadixPrompt'};
if strcmp(entry.input_kind,'mat')
    locked{end+1} = 'sampleRate';
end
provided = fieldnames(options);
if any(ismember(provided,locked))
    error('cw513:platform:ManagedOption', ...
        'File selection, output and runtime identity use dedicated platform fields: %s', ...
        strjoin(intersect(provided,locked),', '));
end
if strcmp(entry.invocation,'hex766')
    if ~isempty(provided)
        error('cw513:platform:HexOptions', ...
            'DA766 hex entry accepts only special.tone_frequency_hz; options must be empty.');
    end
    return;
end
if strcmp(entry.metric,'pico_noise')
    allowed = {'boardType','calibrationState','adcCalibrationRows','kDacVPerCodePp', ...
        'dacSummaryPath','interface','interfaces','fpgaGain','asdCheckHz', ...
        'referencePlane','plotDpi','calibrationWorkbook','welch','waveVariable','metadata'};
    if strcmp(entry.invocation,'pico9245'), allowed = setdiff(allowed,{'interface'});
    else, allowed = setdiff(allowed,{'interfaces'}); end
else
    allowed = [fieldnames(config); {'metadata'}];
    if strcmp(entry.input_kind,'csv')
        allowed = [allowed; {'inputChannels';'inputRadixByFile'}];
    end
    if entry.board_required
        allowed = [allowed; {'boardType';'calibrationState';'reportCalibration'; ...
            'noiseCalibration';'calibrationWorkbook';'adcCalibrationRows'}];
    end
    if strcmp(entry.metric,'power_scale'), allowed{end+1} = 'powerSetpoints'; end
    if strcmp(entry.metric,'bandwidth')
        allowed = [allowed; {'bandwidthScaleFactor';'bandwidthScaleReason';'bandwidthScaleRules'; ...
            'rejectNyquistOrAbove';'minimumRecordCycles';'fitFrequencySource'}];
    end
end
extra = setdiff(provided,allowed);
if ~isempty(extra)
    error('cw513:platform:UnsupportedOption','Unsupported options for %s: %s', ...
        entry.id,strjoin(extra,', '));
end
if isfield(options,'powerSetpoints') && ~istable(options.powerSetpoints)
    manifest = options.powerSetpoints;
    if ~isstruct(manifest) || isempty(manifest) || ...
            ~isfield(manifest,'FileName') || ...
            ~any(isfield(manifest,{'InputPowerDbm','InputVoltageVpp'}))
        error('cw513:platform:PowerSetpoints', ...
            'powerSetpoints must be records with FileName and InputPowerDbm or InputVoltageVpp.');
    end
    options.powerSetpoints = struct2table(manifest(:),'AsArray',true);
end
end

function localValidateSpecial(job,entry)
if ~isfield(job,'special') || isempty(job.special), return; end
validateattributes(job.special,{'struct'},{'scalar'});
allowed = {};
switch entry.invocation
    case 'hex766', allowed = {'tone_frequency_hz'};
    case 'inl2208', allowed = {'continuity_confirmed'};
    case 'dac_pairs', allowed = {'pair_manifest'};
end
extra = setdiff(fieldnames(job.special),allowed);
if ~isempty(extra)
    error('cw513:platform:UnsupportedSpecial','Unsupported special fields for %s: %s', ...
        entry.id,strjoin(extra,', '));
end
end

function [folder,files] = localInputs(job,entry,isRun)
folder = localText(job,'data_folder','');
files = {};
if isfield(job,'selected_files') && ~isempty(job.selected_files)
    files = cellstr(string(job.selected_files(:)));
end
if isempty(files) && strcmp(entry.invocation,'dac_pairs') && isRun
    pairs = localSpecial(job,'pair_manifest',[]);
    if isstruct(pairs) && all(isfield(pairs,{'driven_file','victim_file'}))
        driven = cellstr(string({pairs.driven_file}));
        victim = cellstr(string({pairs.victim_file}));
        files = unique([driven(:);victim(:)],'stable');
    end
end
if isempty(files)
    error('cw513:platform:FilesRequired', ...
        'Select explicit CSV/MAT files. The platform never opens MATLAB file dialogs.');
end
if isempty(folder)
    if ~java.io.File(files{1}).isAbsolute()
        error('cw513:platform:DataFolderRequired','Relative selected_files require data_folder.');
    end
    folder = fileparts(files{1});
end
if ~isfolder(folder)
    error('cw513:platform:DataFolderMissing','Data directory does not exist: %s',folder);
end
folder = char(java.io.File(folder).getCanonicalPath());
for k = 1:numel(files)
    files{k} = converter.io.resolveInputPath(folder,files{k}); %#ok<AGROW>
    files{k} = char(java.io.File(files{k}).getCanonicalPath()); %#ok<AGROW>
    [~,~,extension] = fileparts(files{k});
    if ~isfile(files{k}) || ~strcmpi(extension,['.' entry.input_kind])
        error('cw513:platform:InputMissing','Expected a %s capture: %s',entry.input_kind,files{k});
    end
end
if numel(unique(lower(string(files)))) ~= numel(files)
    error('cw513:platform:DuplicateInput','Select each capture only once.');
end
if isRun && entry.max_files > 0 && numel(files) > entry.max_files
    error('cw513:platform:TooManyFiles','%s accepts %d capture per run.',entry.id,entry.max_files);
end
end

function localRunContract(job,entry,options,files)
if strcmp(entry.metric,'bandwidth')
    for k=1:numel(files)
        [~,stem,extension] = fileparts(files{k});
        if ~isfinite(converter.io.parseFrequencyHz([stem extension]))
            error('cw513:platform:FrequencyRequired', ...
                'Bandwidth input filename must contain a measured frequency: %s',files{k});
        end
    end
end
if entry.board_required
    custom = any(isfield(options,{'adcCalibrationRows','reportCalibration', ...
        'noiseCalibration','calibrationWorkbook'}));
    if ~custom && (~isfield(options,'boardType') || isempty(options.boardType))
        error('cw513:platform:BoardRequired', ...
            'Set options.boardType to jianding or jiaqiang for built-in noise calibration.');
    end
end
if strcmp(entry.metric,'pico_noise')
    if strcmp(entry.invocation,'pico9245')
        if ~isfield(options,'interfaces') || numel(options.interfaces) ~= numel(files)
            error('cw513:platform:InterfaceRequired','options.interfaces must correspond to selected_files.');
        end
    elseif ~isfield(options,'interface') || isempty(options.interface)
        error('cw513:platform:InterfaceRequired','Set options.interface explicitly for the PICO capture.');
    end
end
if strcmp(entry.invocation,'dac_pairs') && isempty(localSpecial(job,'pair_manifest',[]))
    error('cw513:platform:PairsRequired', ...
        'DAC isolation requires special.pair_manifest with reference/victim conditions.');
end
end

function localGuardDialogs(bridgeFolder)
saved = warning('query','MATLAB:dispatcher:nameConflict');
cleanup = onCleanup(@() warning(saved.state,saved.identifier));
warning('off','MATLAB:dispatcher:nameConflict');
addpath(fullfile(bridgeFolder,'dialog_guard'),'-begin');
end

function result = localInvoke(job,entry,folder,files,out,options)
if isfield(options,'powerSetpoints')
    names = cellstr(string(options.powerSetpoints.FileName));
    for k = 1:numel(names)
        names{k} = char(java.io.File(converter.io.resolveInputPath(folder,names{k})).getCanonicalPath());
    end
    options.powerSetpoints.FileName = string(names);
end
switch entry.invocation
    case 'pico9245'
        options.selectedFiles = files;
        result = feval(entry.function,folder,out,options);
    case 'inl2208'
        continuity = localSpecial(job,'continuity_confirmed',[]);
        if ~isempty(continuity) && ~(islogical(continuity) && isscalar(continuity))
            error('cw513:platform:ContinuityFlag','special.continuity_confirmed must be boolean.');
        end
        result = feval(entry.function,folder,files,out,continuity,options);
    case 'hex766'
        result = feval(entry.function,folder,files,out,localSpecial(job,'tone_frequency_hz',[]));
    case 'dac_pairs'
        result = feval(entry.function,folder,localSpecial(job,'pair_manifest',[]),out,options);
    otherwise
        result = feval(entry.function,folder,files,out,options);
end
end

function response = localPreview(response,job,entry,config,options,folder,files)
preview = struct();
if isfield(job,'preview'), preview = job.preview; end
index = 1;
if isfield(preview,'file_index'), index = preview.file_index; end
validateattributes(index,{'numeric'},{'scalar','integer','>=',1,'<=',numel(files)});
maxPoints = 12000;
if isfield(preview,'max_points'), maxPoints = preview.max_points; end
validateattributes(maxPoints,{'numeric'},{'scalar','integer','>=',100,'<=',200000});
source = files{index};
if strcmp(entry.input_kind,'csv')
    [config,~] = converter.runtime.applyRunOptions(config,options);
    config.allowRadixPrompt = false;
    [values,metadata] = converter.io.readAdcCsv(source,config);
    sampleRate = NaN;
    if isfield(config,'sampleRate'), sampleRate = config.sampleRate; end
    if isfield(config,'filterValidStrobe') && config.filterValidStrobe
        % Entry-specific valid spacing is derived by the public run entry.
        sampleRate = NaN;
    end
    label = 'ADC analysis code (code)';
    metadata.preview_reference = 'decoded analysis code; no voltage calibration';
else
    variable = '';
    if isfield(options,'waveVariable')
        variable = options.waveVariable;
    elseif isfield(options,'dataVariables') && ~isempty(options.dataVariables)
        variables = cellstr(string(options.dataVariables));
        if isscalar(variables)
            variable = variables{1};
        elseif numel(variables) == numel(files)
            variable = variables{index};
        else
            error('cw513:platform:VariableCount','dataVariables must have one item or one per file.');
        end
    end
    capture = converter.io.loadPicoMat(source,variable,1,false);
    values = capture.voltage;
    metadata = rmfield(capture,'voltage');
    metadata.preview_reference = 'PICO measured voltage; gain=1; mean retained';
    sampleRate = capture.sampleRateHz;
    label = 'PICO measured voltage (V)';
end
count = numel(values);
indices = localEnvelopeIndices(values,maxPoints);
if isfinite(sampleRate) && sampleRate > 0
    x = (indices-1)/sampleRate;
    xLabel = 'Time (s)';
else
    x = indices-1;
    xLabel = 'Retained sample index (0-based)';
end
series = struct('label',entry.device,'name',entry.device,'x',{num2cell(x(:).')}, ...
    'y',{num2cell(values(indices).')},'style','line');
plot = struct('kind','line','title','Input preview','x_label',xLabel, ...
    'y_label',label,'x_scale','linear','y_scale','linear', ...
    'series',{{series}},'source_file',source, ...
    'display_only_decimation',numel(indices)<count);
response.plots = {plot};
metadata.sample_count = count;
metadata.sample_rate_hz = sampleRate;
metadata.displayed_points = numel(indices);
metadata.source_file = source;
metadata.data_folder = folder;
response.metadata = metadata;
response.warnings = {'Preview is display-only; formal analysis reads all selected source samples.'};
end

function indices = localEnvelopeIndices(values,maximum)
count = numel(values);
if count <= maximum, indices = (1:count)'; return; end
edges = round(linspace(1,count+1,floor(maximum/2)+1));
indices = zeros(2*(numel(edges)-1),1);
for k = 1:numel(edges)-1
    segment = values(edges(k):edges(k+1)-1);
    [~,lo] = min(segment); [~,hi] = max(segment);
    indices(2*k-1:2*k) = edges(k)-1+sort([lo;hi]);
end
indices = unique(indices,'stable');
end

function folder = localResultFolder(result,out,before)
folder = '';
if isstruct(result) && isscalar(result)
    for name = {'runFolder','outputFolder'}
        if isfield(result,name{1}) && isfolder(result.(name{1}))
            folder = char(result.(name{1})); break;
        end
    end
end
created = setdiff(localRunFolders(out),before,'stable');
if isempty(folder) && isscalar(created), folder = created{1}; end
if isempty(folder) || ~ismember(folder,created)
    error('cw513:platform:RunFolderUnresolved', ...
        'Expected exactly one new run directory under the explicit output_folder.');
end
end

function folders = localRunFolders(base)
folders = {};
if ~isfolder(base), return; end
listing = dir(fullfile(base,'run_*'));
listing = listing([listing.isdir]);
folders = arrayfun(@(item) fullfile(item.folder,item.name),listing,'UniformOutput',false);
end

function value = localSpecial(job,name,defaultValue)
value = defaultValue;
if isfield(job,'special') && isstruct(job.special) && isfield(job.special,name)
    value = job.special.(name);
end
end

function value = localText(object,name,defaultValue)
value = defaultValue;
if isfield(object,name) && ~isempty(object.(name))
    validateattributes(object.(name),{'char','string'},{'nonempty'});
    value = char(object.(name));
end
end

function localWriteJson(destination,value)
parent = fileparts(destination);
if ~isempty(parent) && ~isfolder(parent), mkdir(parent); end
temporary = [destination '.partial'];
fileId = fopen(temporary,'w','n','UTF-8');
if fileId < 0, error('cw513:platform:ResponseWrite','Cannot write response: %s',destination); end
closer = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s',jsonencode(value));
clear closer;
movefile(temporary,destination,'f');
end

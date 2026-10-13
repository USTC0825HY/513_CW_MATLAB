function result = adc_pico_noise_1hz_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_PICO_NOISE_1HZ_ANALYSIS Analyze one AD2208 PICO capture using DA9726 scale.
%   No arguments: select one MAT file, then explicitly select its ADC interface.
%   RESULT = ADC_PICO_NOISE_1HZ_ANALYSIS(FOLDER, FILE, OUTPUT, OPTIONS)
%   requires OPTIONS.interface, e.g. 'ADC6_JG24', when FILE is supplied.
%   OPTIONS also accepts fpgaGain, calibrationWorkbook,
%   referencePlane, waveVariable, asdCheckHz, plotDpi and a partial welch struct.
%   One capture per run prevents overwriting the core's interface-named files.
%   A single PICO waveform can be selected automatically; multichannel MAT
%   requires waveVariable. Unity analog gain and no baseline subtraction are fixed.
arguments
    dataFolder (1,1) string = ""
    selectedFiles = []
    outputFolder (1,1) string = ""
    runOptions (1,1) struct = struct()
end
result = struct();
campaign = fullfile('F:', '01_Laser', '0_20260727_513test', 'CW_Data', '513_CW_DATA');
if strlength(dataFolder) == 0
    dataFolder = fullfile(campaign, 'AD2208', '06_Noise', '02_1Hz_PICO');
end
interactive = isempty(selectedFiles);
if interactive
    [fileName, folder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
        '选择一份 AD2208 PICO MAT（单通道；确认 FPGA 增益，默认128）');
    if isequal(fileName, 0), return; end
    dataFolder = string(folder);
    selectedFiles = {fileName};
end
files = string(selectedFiles);
if numel(files) ~= 1 || ismissing(files) || strlength(files) == 0
    error('ad2208:PicoSingleCaptureRequired', '每次请选择一份 MAT；不同记录请分别运行。');
end
if ~isfolder(dataFolder)
    error('ad2208:PicoDataFolderMissing', '数据目录不存在：%s', dataFolder);
end
capturePath = files;
if ~java.io.File(char(capturePath)).isAbsolute()
    capturePath = fullfile(dataFolder, capturePath);
end
capturePath = char(java.io.File(char(capturePath)).getCanonicalPath());
[~, ~, extension] = fileparts(capturePath);
if ~isfile(capturePath) || ~strcmpi(extension, '.mat')
    error('ad2208:PicoCaptureMissing', 'PICO MAT 不存在或扩展名错误：%s', capturePath);
end
allowedInterfaces = {'ADC1_JG15','ADC2_JG17','ADC3_JG19','ADC5_JG22','ADC6_JG24'};
if ~isfield(runOptions, 'interface') && interactive
    [index, accepted] = listdlg('ListString', allowedInterfaces, ...
        'SelectionMode', 'single', 'InitialValue', 5, ...
        'PromptString', '明确选择本次 ADC 接口（不根据文件名推断）');
    if ~accepted, return; end
    runOptions.interface = allowedInterfaces{index};
end
if ~isfield(runOptions, 'interface') || ...
        ~isscalar(string(runOptions.interface)) || ...
        ~any(strcmp(string(runOptions.interface), allowedInterfaces))
    error('ad2208:PicoInterfaceRequired', 'runOptions.interface 必须明确指定有效 AD2208 接口。');
end
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
bootstrapRuntime();
cfg = localConfig(campaign, runOptions);
[cfg, ~, cancelled] = converter.calibration.resolveNoiseCalibration( ...
    cfg, 'AD2208', {runOptions.interface}, interactive, true);
if cancelled, return; end
if strlength(outputFolder) == 0
    outputFolder = fullfile(dataFolder, 'results');
end
cfg.outputRoot = char(outputFolder);
cfg.entries = struct('device', 'AD2208', 'interface', char(runOptions.interface), ...
    'matFile', capturePath);
cfg.entryScript = mfilename('fullpath');
cfg.entryScriptSha256 = converter.runtime.sha256File([cfg.entryScript '.m']);
formalRoot = fileparts(fileparts(mfilename('fullpath')));
cfg.coreScript = fullfile(formalRoot, 'noise_chain_hy', 'adc_input_equiv_noise_analysis.m');
cfg.coreScriptSha256 = converter.runtime.sha256File(cfg.coreScript);
cfg.matlabVersion = version;
addpath(fullfile(formalRoot, 'noise_chain_hy'));
result = adc_input_equiv_noise_analysis(cfg);
localWriteEntryEvidence(result);
converter.runtime.finalizeBundle(result.runFolder, result.config);
result = converter.runtime.refreshResultPaths(result, result.runFolder);
fprintf('DA9726 selected calibration: k_DAC = %.15g V/code\n', ...
    result.calibration.kDac);
disp(result.summary(:, {'interface','sample_rate_hz','duration_s', ...
    'asd_check_actual_hz','input_asd_at_check_n_v_per_sqrt_hz','formal_state'}));
end

function cfg = localConfig(~, options)
cfg = ad2208Config('pico_noise');
allowed = {'boardType','calibrationState','adcCalibrationRows','kDacVPerCodePp','dacSummaryPath', 'interface','fpgaGain','asdCheckHz','referencePlane','plotDpi', ...
    'calibrationWorkbook','welch','waveVariable','metadata'};
defaults = cfg;
names = fieldnames(options);
if ~all(ismember(names, allowed))
    error('ad2208:PicoUnknownOption', '存在不支持的 runOptions 字段。请查 README。');
end
for k = 1:numel(names)
    name = names{k};
    if strcmp(name, 'interface'), continue; end
    if strcmp(name, 'welch')
        validateattributes(options.welch, {'struct'}, {'scalar'});
        fields = fieldnames(options.welch);
        if ~all(ismember(fields, fieldnames(cfg.welch)))
            error('ad2208:PicoWelchOption', '不支持的 Welch 参数。');
        end
        for j = 1:numel(fields), cfg.welch.(fields{j}) = options.welch.(fields{j}); end
    else
        cfg.(name) = options.(name);
    end
end
applied = options;
if isfield(applied,'interface'), applied = rmfield(applied,'interface'); end
if isfield(applied,'welch'), applied.welch = cfg.welch; end
cfg = converter.runtime.finalizeConfig(defaults, applied);
validateattributes(cfg.fpgaGain, {'numeric'}, {'real','scalar','finite','nonzero'});
validateattributes(cfg.asdCheckHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.plotDpi, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.welch.targetResolutionHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.welch.overlapRatio, {'numeric'}, {'real','scalar','finite','>=',0,'<',1});
if ~isequal(string(cfg.welch.windowType), "hann")
    error('ad2208:PicoWindowUnsupported', '公共内核仅实现 Hann 窗。');
end
end

function localWriteEntryEvidence(result)
cfg = result.config;
% Report references already carry their pinned SHA in the calibration records.
% Hash only live source/input files here; never reopen a report during analysis.
raw = result.manifest(strcmp(string({result.manifest.source_type}),'raw'));
paths = [{[cfg.entryScript '.m']}; {cfg.coreScript}; cellstr(string({raw.path})')];
items = repmat(struct('path',"",'size_bytes',0,'modified',"",'sha256',""),numel(paths),1);
for k = 1:numel(paths)
    info = dir(paths{k});
    items(k) = struct('path',string(paths{k}),'size_bytes',info.bytes, ...
        'modified',string(info.date),'sha256',string(converter.runtime.sha256File(paths{k})));
end
converter.report.writeTable(struct2table(items),fullfile(result.runFolder,'entry_source_manifest.csv'));
fileId = fopen(fullfile(result.runFolder,'entry_run_log.txt'),'w');
if fileId < 0, error('ad2208:PicoLogWriteFailed','无法写入入口运行日志。'); end
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId,'MATLAB: %s\nEntry: %s\nCore: %s\nDAC: %s\nkDAC: %.15g\n', ...
    cfg.matlabVersion,cfg.entryScript,cfg.coreScript, ...
    result.calibration.dacSummaryPath,result.calibration.kDac);
fprintf(fileId,'Output: %s\nFormal state: %s\n',result.runFolder,result.summary.formal_state);
end

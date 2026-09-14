function result = adc_pico_noise_1hz_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_PICO_NOISE_1HZ_ANALYSIS Analyze one AD2208 PICO capture using DA9726 scale.
%   No arguments: select one MAT file, then explicitly select its ADC interface.
%   RESULT = ADC_PICO_NOISE_1HZ_ANALYSIS(FOLDER, FILE, OUTPUT, OPTIONS)
%   requires OPTIONS.interface, e.g. 'ADC6_JG24', when FILE is supplied.
%   OPTIONS also accepts fpgaGain, calibrationWorkbook,
%   referencePlane, asdCheckHz, plotDpi and a partial welch struct.
%   One capture per run prevents overwriting the core's interface-named files.
%   PICO variable A, unity analog gain, mean removal and no baseline subtraction
%   are fixed. Sampling rate is read from the MAT, never inferred from its name.
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
        '选择一份 AD2208 PICO MAT（A 通道；确认 FPGA 增益，默认128）');
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
cfg = localValidateCalibration(cfg, runOptions.interface);
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
fprintf('DA9726 fixed calibration: k_DAC = %.15g V/CodePp (no DAC CSV read)\n', ...
    result.calibration.kDac);
disp(result.summary(:, {'interface','sample_rate_hz','duration_s', ...
    'asd_check_actual_hz','input_asd_at_check_n_v_per_sqrt_hz','formal_state'}));
end

function cfg = localConfig(~, options)
cfg = struct('analysisId', 'ad2208_pico_noise_1hz', 'version', '1.2.0', ...
    'baselineMode', 'none', 'fpgaGain', 128, 'asdCheckHz', 1, ...
    'referencePlane', 'AD2208 external board input', 'plotDpi', 180, ...
    'calibrationWorkbook', which('converter.calibration.reportCalibration'));
% User-pinned DA9726 JG18 slope. Do not locate or read DAC calibration CSVs.
cfg.kDacVPerCodePp = 1.01451391294771e-4;
cfg.dacCalibrationSource = 'Fixed configuration: DA9726 JG18; user-pinned k_DAC = 1.01451391294771e-4 V/CodePp';
cfg.welch = struct('targetResolutionHz', 0.2, 'overlapRatio', 0.5, 'windowType', 'hann');
allowed = {'interface','fpgaGain','asdCheckHz','referencePlane','plotDpi', ...
    'calibrationWorkbook','welch'};
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
validateattributes(cfg.fpgaGain, {'numeric'}, {'real','scalar','finite','nonzero'});
validateattributes(cfg.asdCheckHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.plotDpi, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.welch.targetResolutionHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.welch.overlapRatio, {'numeric'}, {'real','scalar','finite','>=',0,'<',1});
if ~isequal(string(cfg.welch.windowType), "hann")
    error('ad2208:PicoWindowUnsupported', '公共内核仅实现 Hann 窗。');
end
end

function cfg = localValidateCalibration(cfg, interfaceName)
% Validate selected ADC calibration before the core creates a result directory.
rows = converter.calibration.loadAdcCalibration(cfg.calibrationWorkbook);
match = strcmp({rows.device},'AD2208') & strcmp({rows.interface},char(interfaceName));
if nnz(match) ~= 1
    error('cw513:AdcCalibrationAmbiguous','AD2208/%s 刻度必须唯一匹配。',interfaceName);
end
validateattributes(rows(match).slope,{'numeric'},{'real','scalar','finite','positive'});
end

function localWriteEntryEvidence(result)
cfg = result.config;
paths = [{[cfg.entryScript '.m']}; {cfg.coreScript}; cellstr(string({result.manifest.path})')];
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

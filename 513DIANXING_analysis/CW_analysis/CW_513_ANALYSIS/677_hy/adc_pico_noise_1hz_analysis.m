function result = adc_pico_noise_1hz_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_PICO_NOISE_1HZ_ANALYSIS Analyze AD677 input-equivalent 1 Hz ASD.
%   The measured PICO voltage is referred through DA9726 JG18 and the FPGA
%   gain to the selected AD677 input. One MAT capture is processed per run.
arguments
    dataFolder (1,1) string = ""
    selectedFiles = []
    outputFolder (1,1) string = ""
    runOptions (1,1) struct = struct()
end

result = struct();
if strlength(dataFolder) == 0
    dataFolder = fullfile('F:', '01_Laser', '0_20260727_513test', ...
        'CW_Data', '513_CW_DATA', 'AD677', '01_noise');
end
interactive = isempty(selectedFiles);
if interactive
    [fileName, folder] = uigetfile(fullfile(dataFolder, '*.mat'), ...
        '选择一份 AD677 PICO MAT（确认回放增益，默认128）');
    if isequal(fileName, 0), return; end
    dataFolder = string(folder);
    selectedFiles = {fileName};
end
files = string(selectedFiles);
if numel(files) ~= 1 || ismissing(files) || strlength(files) == 0
    error('ad677:PicoSingleCaptureRequired', '每次必须选择一份 AD677 PICO MAT。');
end
if ~isfolder(dataFolder)
    error('ad677:PicoDataFolderMissing', '数据目录不存在：%s', dataFolder);
end
capturePath = files;
if ~java.io.File(char(capturePath)).isAbsolute()
    capturePath = fullfile(dataFolder, capturePath);
end
capturePath = string(java.io.File(char(capturePath)).getCanonicalPath());
[~, ~, extension] = fileparts(capturePath);
if ~isfile(capturePath) || ~strcmpi(extension, '.mat')
    error('ad677:PicoCaptureMissing', 'PICO MAT 不存在或扩展名错误：%s', capturePath);
end

allowedInterfaces = {'677_1', '677_2'};
if ~isfield(runOptions, 'interface') && interactive
    [index, accepted] = listdlg('ListString', allowedInterfaces, ...
        'SelectionMode', 'single', 'InitialValue', 1, ...
        'PromptString', '明确选择本次 AD677 接口（不根据文件名推断）');
    if ~accepted, return; end
    runOptions.interface = allowedInterfaces{index};
end
if ~isfield(runOptions, 'interface') || ...
        ~isscalar(string(runOptions.interface)) || ...
        ~any(strcmp(string(runOptions.interface), allowedInterfaces))
    error('ad677:PicoInterfaceRequired', ...
        'runOptions.interface 必须明确指定 677_1 或 677_2。');
end

originalPath = path;
pathCleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
bootstrapRuntime();
deviceConfig = ad677Config('input_noise');
cfg = localConfig(deviceConfig, runOptions);
% loadPicoMat falls back to the only present A/B/C/D channel when the
% requested letter is missing (jiaqiang X3/X13 exports use channel B).
capture = converter.io.loadPicoMat(char(capturePath), 'A', 1, true);
minimumDurationS = 1 / cfg.welch.targetResolutionHz;
if capture.sampleCount / capture.sampleRateHz < minimumDurationS
    error('ad677:PicoFrequencyCoverage', ...
        ['记录时长 %.6g s，不足以按 %.6g Hz 分辨率分析 1 Hz ASD；' ...
         '至少需要 %.6g s。'], capture.sampleCount / capture.sampleRateHz, ...
        cfg.welch.targetResolutionHz, minimumDurationS);
end
if strlength(outputFolder) == 0
    outputFolder = converter.io.resolveOutputBase(char(dataFolder), []);
end
cfg.outputRoot = char(outputFolder);
cfg.entries = struct('device', 'AD677', ...
    'interface', char(string(runOptions.interface)), ...
    'matFile', char(capturePath));
formalRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(formalRoot, 'noise_chain_hy'));
result = adc_input_equiv_noise_analysis(cfg);
end

function cfg = localConfig(deviceConfig, options)
configPath = fullfile(fileparts(mfilename('fullpath')), 'private', 'ad677Config.m');
cfg = struct('analysisId', 'ad677_pico_noise_1hz', 'version', '1.0.0', ...
    'baselineMode', 'none', 'fpgaGain', deviceConfig.picoFpgaGain, ...
    'asdCheckHz', deviceConfig.picoAsdCheckHz, ...
    'referencePlane', deviceConfig.referencePlane, 'plotDpi', 180, ...
    'welch', deviceConfig.picoWelch, ...
    'adcCalibrationRows', localCoreCalibration(deviceConfig.noiseCalibration), ...
    'adcCalibrationSource', configPath, ...
    'adcCalibrationDescription', deviceConfig.noiseCalibrationSource, ...
    'kDacVPerCodePp', deviceConfig.picoDacCalibration.slopeVPerCode, ...
    'dacCalibrationSource', deviceConfig.picoDacCalibration.source, ...
    'plotLimitUvPerSqrtHz', deviceConfig.noiseLimitNvPerSqrtHz / 1e3, ...
    'formalEnabled', false);
allowed = {'interface', 'fpgaGain', 'asdCheckHz', 'referencePlane', ...
    'plotDpi', 'welch'};
names = fieldnames(options);
if ~all(ismember(names, allowed))
    error('ad677:PicoUnknownOption', '存在不支持的 runOptions 字段。请查 README。');
end
for k = 1:numel(names)
    name = names{k};
    if strcmp(name, 'interface'), continue; end
    if strcmp(name, 'welch')
        fields = fieldnames(options.welch);
        if ~all(ismember(fields, fieldnames(cfg.welch)))
            error('ad677:PicoWelchOption', '不支持的 Welch 参数。');
        end
        for j = 1:numel(fields), cfg.welch.(fields{j}) = options.welch.(fields{j}); end
    else
        cfg.(name) = options.(name);
    end
end
validateattributes(cfg.fpgaGain, {'numeric'}, {'real','scalar','finite','nonzero'});
validateattributes(cfg.asdCheckHz, {'numeric'}, {'real','scalar','finite','positive'});
validateattributes(cfg.welch.targetResolutionHz, {'numeric'}, ...
    {'real','scalar','finite','positive'});
validateattributes(cfg.welch.overlapRatio, {'numeric'}, {'real','scalar','>=',0,'<',1});
if ~isequal(string(cfg.welch.windowType), "hann")
    error('ad677:PicoWindowUnsupported', '公共内核仅实现 Hann 窗。');
end
end

function rows = localCoreCalibration(deviceRows)
rows = repmat(struct('device', '', 'interface', '', 'slope', NaN, ...
    'intercept', NaN, 'r2', NaN, 'dataGroup', ''), numel(deviceRows), 1);
for k = 1:numel(deviceRows)
    rows(k) = struct('device', deviceRows(k).device, ...
        'interface', deviceRows(k).channel, ...
        'slope', deviceRows(k).slopeVPerCode, ...
        'intercept', NaN, 'r2', NaN, ...
        'dataGroup', deviceRows(k).sourceSection);
end
end

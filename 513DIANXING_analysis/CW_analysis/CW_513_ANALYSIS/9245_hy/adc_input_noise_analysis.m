function result = adc_input_noise_analysis(dataFolder, outputFolder, runOptions)
%ADC_INPUT_NOISE_ANALYSIS Select AD9245 PICO MAT captures for 1 Hz chain noise.
%   Empty entries/files opens a MAT chooser; select each ADC interface explicitly.
%   Explicit RUNOPTIONS.entries (device/interface/matFile) suppresses all UI.
%   Alternatively use RUNOPTIONS.selectedFiles and RUNOPTIONS.interfaces.
%   One capture per interface prevents overwriting interface-named core outputs.
if nargin < 1, dataFolder = []; end
if nargin < 2, outputFolder = []; end
if nargin < 3 || isempty(runOptions), runOptions = struct(); end
validateattributes(runOptions, {'struct'}, {'scalar'});
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
bootstrapRuntime();
campaign = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA');
if isempty(dataFolder), dataFolder = fullfile(campaign, 'AD9245', '01_noise'); end
result = struct([]);
entries = struct('device', {}, 'interface', {}, 'matFile', {});
interactive = ~(isfield(runOptions,'entries') && ~isempty(runOptions.entries)) && ...
    ~(isfield(runOptions,'selectedFiles') && ~isempty(runOptions.selectedFiles));
if isfield(runOptions, 'entries') && ~isempty(runOptions.entries)
    entries = runOptions.entries;
elseif isfield(runOptions, 'selectedFiles') && ~isempty(runOptions.selectedFiles)
    [files, dataFolder] = converter.io.selectMatFiles(dataFolder, runOptions.selectedFiles);
    if ~isfield(runOptions, 'interfaces') || numel(string(runOptions.interfaces)) ~= numel(files)
        error('ad9245:NoiseInterfaceRequired', 'interfaces 必须与 selectedFiles 逐一对应。');
    end
    names = string(runOptions.interfaces);
    for k = 1:numel(files)
        entries(k) = localEntry(names(k), converter.io.resolveInputPath(dataFolder, files{k}));
    end
else
    [files, dataFolder] = converter.io.selectMatFiles(dataFolder, [], ...
        '选择本次 AD9245 PICO MAT（A通道；每接口一份）');
    if isempty(files), return; end
    for k = 1:numel(files)
        [index, accepted] = listdlg('ListString', {'X1G','X2G','X3G','X4G'}, ...
            'SelectionMode', 'single', 'PromptString', ['明确 ADC 输入接口：' files{k}]);
        if ~accepted, return; end
        allowed = {'X1G','X2G','X3G','X4G'};
        entries(k) = localEntry(allowed{index}, converter.io.resolveInputPath(dataFolder, files{k}));
    end
end
if ~isstruct(entries) || isempty(entries) || ...
        ~all(isfield(entries, {'device','interface','matFile'}))
    error('ad9245:NoiseEntriesRequired', 'entries 必须明确 device、interface 和 matFile。');
end
for k = 1:numel(entries)
    if ~isequal(string(entries(k).device), "AD9245") || ...
            ~isscalar(string(entries(k).interface)) || ...
            ~any(strcmp(string(entries(k).interface), {'X1G','X2G','X3G','X4G'}))
        error('ad9245:NoiseInterfaceRequired', '必须明确 AD9245 的 X1G-X4G 接口。');
    end
    entries(k).matFile = converter.io.resolveInputPath(dataFolder, entries(k).matFile);
    converter.io.selectMatFiles(dataFolder, {entries(k).matFile});
end
if numel(unique(string({entries.interface}))) ~= numel(entries)
    error('ad9245:DuplicateInterfaceSelection', '每接口只能选择一份 MAT；同接口多记录请分别运行。');
end
if numel(unique(lower(string({entries.matFile})))) ~= numel(entries)
    error('converter:io:DuplicateInput', '同一 MAT 不能重复声明为不同接口。');
end
runConfig = ad9245Config('pico_noise');
converter.runtime.validateOverrideFields(runConfig, runOptions, ...
    {'boardType','calibrationState','adcCalibrationRows','kDacVPerCodePp','dacSummaryPath','calibrationWorkbook','entries','selectedFiles','interfaces','outputRoot','waveVariable','metadata'});
defaults = runConfig;
names = fieldnames(runOptions);
for k = 1:numel(names)
    if ismember(names{k}, {'entries','selectedFiles','interfaces'}), continue; end
    if strcmp(names{k}, 'welch')
        converter.runtime.validateOverrideFields(runConfig.welch, runOptions.welch, {});
        runConfig.welch = converter.runtime.mergeConfig(runConfig.welch, runOptions.welch);
    else
        runConfig.(names{k}) = runOptions.(names{k});
    end
end
applied = runOptions;
controls = intersect(fieldnames(applied), {'entries','selectedFiles','interfaces'});
applied = rmfield(applied, controls);
if isfield(applied,'welch'), applied.welch = runConfig.welch; end
runConfig = converter.runtime.finalizeConfig(defaults, applied);
runConfig.entries = entries;
if isempty(outputFolder) && isfield(runConfig, 'outputRoot')
    outputFolder = runConfig.outputRoot;
end
runConfig.outputRoot = converter.io.resolveOutputBase(dataFolder, outputFolder);
validateattributes(runConfig.fpgaGain, {'numeric'}, {'scalar','real','finite','nonzero'});
[runConfig, ~, cancelled] = converter.calibration.resolveNoiseCalibration( ...
    runConfig, 'AD9245', {entries.interface}, interactive, true);
if cancelled, return; end
noiseChainFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'noise_chain_hy');
addpath(noiseChainFolder, '-begin');
result = adc_input_equiv_noise_analysis(runConfig);
fprintf('\nAD9245 输入等效 ASD @ 1 Hz（实际 bin）\n');
disp(result.summary(:, {'interface','sample_rate_hz','duration_s', ...
    'asd_check_actual_hz','input_asd_at_check_n_v_per_sqrt_hz','formal_state'}));
end

function entry = localEntry(interfaceName, matFile)
entry = struct('device', 'AD9245', 'interface', char(interfaceName), 'matFile', char(matFile));
end

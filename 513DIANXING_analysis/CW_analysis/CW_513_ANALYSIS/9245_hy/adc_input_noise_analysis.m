function result = adc_input_noise_analysis(dataFolder, outputFolder, runOptions)
%ADC_INPUT_NOISE_ANALYSIS Analyze AD9245 1 Hz input-equivalent noise.
%   RESULT = ADC_INPUT_NOISE_ANALYSIS() first opens a folder chooser for
%   the AD9245 noise-data root, then lets the user choose one or more
%   X1G-X4G G=128 MAT captures. The selected captures are acquired through
%   AD9245 -> FPGA (G=128) -> JG18 DAC -> PICO.
%   Existing AD9245 CodePp-to-Vpp and JG18 Vpp/CodePp calibrations are
%   referenced directly; this entry never performs a new calibration.
%
%   DATAFOLDER suppresses the interactive chooser and processes the four
%   standard X1G-X4G paths below that folder. OUTPUTFOLDER defaults to its
%   results child. RUNOPTIONS may override fields in the fixed run config,
%   for example to process a copied capture set or choose another output.

bootstrapRuntime();
defaultDataFolder = fullfile('F:', filesep, '01_Laser', ...
    '0_20260727_513test', 'CW_Data', '513_CW_DATA', 'AD9245', ...
    '01_noise');
selectedEntries = struct('device', {}, 'interface', {}, 'matFile', {});
if nargin < 1 || isempty(dataFolder)
    [dataFolder, selectedEntries, wasCancelled] = ...
        localSelectG128Captures(defaultDataFolder);
    if wasCancelled
        result = struct([]);
        return;
    end
end
if nargin < 2 || isempty(outputFolder)
    outputFolder = fullfile(dataFolder, 'results');
end
if nargin < 3 || isempty(runOptions)
    runOptions = struct();
end
if ~isstruct(runOptions) || ~isscalar(runOptions)
    error('ad9245:InvalidNoiseOptions', ...
        'RUNOPTIONS 必须是标量 struct。');
end

runConfig = localDefaultRunConfig(dataFolder, outputFolder);
if ~isempty(selectedEntries)
    runConfig.entries = selectedEntries;
end
runConfig = localMergeRunOptions(runConfig, runOptions);
noiseChainFolder = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'noise_chain_hy');
if ~isfile(fullfile(noiseChainFolder, 'adc_input_equiv_noise_analysis.m'))
    error('ad9245:NoiseCoreMissing', ...
        '未找到当前库的 ADC 输入等效噪声内核：%s', noiseChainFolder);
end
addpath(noiseChainFolder, '-begin');
result = adc_input_equiv_noise_analysis(runConfig);
localDisplay1HzAsd(result.summary);
end

function config = localDefaultRunConfig(dataFolder, outputFolder)
dataRoot = localFindCampaignDataRoot(dataFolder);
config = struct();
config.analysisId = 'ad9245_input_equiv_noise_1hz';
config.version = '1.2.0';
config.outputRoot = outputFolder;
config.baselineMode = 'none';
config.fpgaGain = 128;
config.asdCheckHz = 1;
config.referencePlane = 'AD9245 external board input';
config.plotDpi = 180;
config.welch = struct('targetResolutionHz', 0.2, 'overlapRatio', 0.5, ...
    'windowType', 'hann');

% The workbook contains the reviewed 2026-08-22 AD9245 X1G-X4G fit rows.
% k_DAC is the user-specified JG18 scale for this analysis. It is deliberately
% fixed here so the run does not depend on a separately located CSV summary.
config.calibrationWorkbook = fullfile(dataRoot, ...
    'CW_513_ANALYSIS_AD2208_AD9245_刻度参数_20260822.xlsx');
config.kDacVPerCodePp = 1.014514e-4;
config.dacCalibrationSource = [ ...
    'Fixed configuration: DA9726 DAC1_JG18; ' ...
    'k_DAC = 1.014514e-4 V/CodePp (user-specified)'];
config.entries = [ ...
    localEntry('X1G', fullfile(dataFolder, 'X1G', 'X1G_G128_CH1_100KSPS.mat')); ...
    localEntry('X2G', fullfile(dataFolder, 'X2G', 'X2G_100KSPS_CH1_G128.mat')); ...
    localEntry('X3G', fullfile(dataFolder, 'X3G', 'X3G_100KSPS_CH1_G128.mat')); ...
    localEntry('X4G', fullfile(dataFolder, 'X4G', 'X4G_100KSPS_CH1_G128.mat'))];
end

function dataRoot = localFindCampaignDataRoot(startFolder)
%LOCATECAMPAIGNDATAROOT Find the parent containing the reviewed AD9245 fit.
workbookName = 'CW_513_ANALYSIS_AD2208_AD9245_刻度参数_20260822.xlsx';
dataRoot = char(startFolder);
while true
    if isfile(fullfile(dataRoot, workbookName))
        return;
    end
    parentFolder = fileparts(dataRoot);
    if strcmp(parentFolder, dataRoot)
        break;
    end
    dataRoot = parentFolder;
end
error('ad9245:CalibrationWorkbookMissing', ...
    ['从所选数据目录向上未找到 AD9245 刻度工作簿 %s。' newline ...
    '请选取 513_CW_DATA\AD9245\01_noise 或其子目录。'], workbookName);
end

function entry = localEntry(interfaceName, matFile)
entry = struct('device', 'AD9245', 'interface', interfaceName, ...
    'matFile', matFile);
end

function localDisplay1HzAsd(summary)
%LOCALDISPLAY1HZASD Print the requested-bin ASD in the MATLAB command window.
columns = {'interface', 'sample_rate_hz', 'duration_s', ...
    'frequency_resolution_hz', 'asd_check_actual_hz', ...
    'input_asd_at_check_n_v_per_sqrt_hz', 'formal_state', 'note'};
fprintf('\nAD9245 输入等效 ASD @ 1 Hz（实际 bin）\n');
disp(summary(:, columns));
end

function [dataFolder, entries, wasCancelled] = localSelectG128Captures(defaultDataFolder)
%LOCALSELECTG128CAPTURES Interactively choose AD9245 G=128 MAT captures.
dataFolder = uigetdir(defaultDataFolder, ...
    '选择 AD9245 1 Hz 噪声数据根目录（含 X1G-X4G 子目录）');
entries = struct('device', {}, 'interface', {}, 'matFile', {});
wasCancelled = isequal(dataFolder, 0);
if wasCancelled
    dataFolder = defaultDataFolder;
    return;
end
dataFolder = char(dataFolder);

matFiles = dir(fullfile(dataFolder, '**', '*.mat'));
paths = strings(0, 1);
interfaces = strings(0, 1);
labels = strings(0, 1);
for index = 1:numel(matFiles)
    matPath = fullfile(matFiles(index).folder, matFiles(index).name);
    interfaceToken = regexp(matPath, '(?i)(?<![A-Z0-9])(X[1-4]G)(?![A-Z0-9])', ...
        'tokens', 'once');
    if isempty(interfaceToken) || ~contains(upper(string(matPath)), "G128")
        continue;
    end

    interfaceName = upper(string(interfaceToken{1}));
    relativePath = erase(string(matPath), string([dataFolder filesep]));
    paths(end + 1, 1) = string(matPath); %#ok<AGROW>
    interfaces(end + 1, 1) = interfaceName; %#ok<AGROW>
    labels(end + 1, 1) = interfaceName + " | " + relativePath; %#ok<AGROW>
end
if isempty(paths)
    error('ad9245:NoG128Captures', ...
        '目录中未找到名称或路径含 X1G-X4G 且标记 G128 的 MAT 文件：%s', ...
        dataFolder);
end

[labels, order] = sort(labels);
paths = paths(order);
interfaces = interfaces(order);
[selection, wasSelected] = listdlg( ...
    'PromptString', '选择要处理的 AD9245 G=128 MAT 数据：', ...
    'SelectionMode', 'multiple', ...
    'ListString', cellstr(labels), ...
    'ListSize', [760, 280], ...
    'Name', 'AD9245 1 Hz 输入等效噪声');
wasCancelled = ~wasSelected || isempty(selection);
if wasCancelled
    return;
end

selectedInterfaces = interfaces(selection);
if numel(unique(selectedInterfaces)) ~= numel(selectedInterfaces)
    error('ad9245:DuplicateInterfaceSelection', ...
        '每个接口只能选择一个 MAT 文件；请重新运行并为每个 X?G 只选择一项。');
end
for index = 1:numel(selection)
    entries(end + 1, 1) = localEntry(char(selectedInterfaces(index)), ...
        char(paths(selection(index)))); %#ok<AGROW>
end
end

function config = localMergeRunOptions(config, options)
names = fieldnames(options);
for index = 1:numel(names)
    config.(names{index}) = options.(names{index});
end
end

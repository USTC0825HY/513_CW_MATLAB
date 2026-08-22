function status = run_cw513_ad_input_analysis_20260819()
% Deprecated compatibility driver. Use run_cw513_ad9245_analysis_20260820
% for the complete AD9245 X1G-X4G rerun with the verified 20 MHz clock.
%RUN_CW513_AD_INPUT_ANALYSIS_20260819 Run the requested AD input analyses.
%   This task driver selects only the reviewed 513 raw captures and writes
%   each bundle below the raw directory's sibling result folder.

libraryRoot = fileparts(fileparts(mfilename('fullpath')));
dataRoot = 'F:\01_Laser\20260727_513test\CW_Data\513_CW_DATA';
device2208 = fullfile(libraryRoot, '2208_hy');
device9245 = fullfile(libraryRoot, '9245_hy');

status = struct('Name', {}, 'Success', {}, 'Message', {});
failures = {};

% AD2208 JG15 frequency: the complete 18-point c7 capture only.
selectDevice(device2208, device9245);
jg15FrequencyRoot = fullfile(dataRoot, 'AD2208', '02_FrequencyResponse', ...
    'ADC1_JG15', 'raw');
jg15FrequencyGroup = fullfile(jg15FrequencyRoot, ...
    'adc-stimulus-preflight-c7ac2cde72bd');
jg15FrequencyFiles = nestedCaptureFiles(jg15FrequencyRoot, ...
    jg15FrequencyGroup);
requireCount(jg15FrequencyFiles, 18, 'AD2208 JG15 输入频率');
status = runStep(status, 'AD2208 JG15 输入频率', @() ...
    adc_bandwidth_analysis(jg15FrequencyRoot, jg15FrequencyFiles, ...
    fullfile(dataRoot, 'AD2208', '02_FrequencyResponse', ...
    'ADC1_JG15', 'result')));

% AD2208 JG24 frequency: the complete 18-point 5 dBm capture.
selectDevice(device2208, device9245);
jg24FrequencyRoot = fullfile(dataRoot, 'AD2208', '02_FrequencyResponse', ...
    'ADC6_JG24', 'raw', ...
    'yb2208_ch05_input_frequency_5dBm_frequency_sweep_20260819_202003_200760');
jg24FrequencyFiles = directCsvFiles(jg24FrequencyRoot, jg24FrequencyRoot);
requireCount(jg24FrequencyFiles, 18, 'AD2208 JG24 输入频率');
status = runStep(status, 'AD2208 JG24 输入频率', @() ...
    adc_bandwidth_analysis(jg24FrequencyRoot, jg24FrequencyFiles, ...
    fullfile(dataRoot, 'AD2208', '02_FrequencyResponse', ...
    'ADC6_JG24', 'result')));

% AD2208 JG15 power: current 1 MHz sweep, retaining +7/+8 dBm as detail.
selectDevice(device2208, device9245);
jg15PowerRoot = fullfile(dataRoot, 'AD2208', '03_InputPowerScale', ...
    'ADC1_JG15', 'raw', ...
    'yb2208_ch01_rf_input_power_1MHz_power_sweep_20260819_202934_875932');
jg15PowerFiles = directCsvFiles(jg15PowerRoot, jg15PowerRoot);
requireCount(jg15PowerFiles, 19, 'AD2208 JG15 输入功率');
jg15PowerOptions = struct('configOverride', struct('testFrequencyHz', 1e6));
status = runStep(status, 'AD2208 JG15 输入功率', @() ...
    adc_power_scale_analysis(jg15PowerRoot, jg15PowerFiles, ...
    fullfile(dataRoot, 'AD2208', '03_InputPowerScale', ...
    'ADC1_JG15', 'result'), jg15PowerOptions));

% AD2208 JG24 power: use the non-error Vpp capture and an explicit
% 50-ohm-equivalent dBm manifest. The source metadata says high_z, so the
% result records this as an equivalent value rather than board input power.
selectDevice(device2208, device9245);
jg24PowerRoot = fullfile(dataRoot, 'AD2208', '03_InputPowerScale', ...
    'ADC6_JG24', 'raw', 'adc-stimulus-preflight-4bc7c7245988');
jg24PowerFiles = nestedCaptureFiles(jg24PowerRoot, jg24PowerRoot);
requireCount(jg24PowerFiles, 10, 'AD2208 JG24 输入功率');
jg24PowerManifest = makeVppManifest(jg24PowerFiles);
jg24PowerOptions = struct('configOverride', struct('testFrequencyHz', 1e6), ...
    'powerSetpoints', jg24PowerManifest);
status = runStep(status, 'AD2208 JG24 输入功率', @() ...
    adc_power_scale_analysis(jg24PowerRoot, jg24PowerFiles, ...
    fullfile(dataRoot, 'AD2208', '03_InputPowerScale', ...
    'ADC6_JG24', 'result'), jg24PowerOptions));

% AD9245 X1G frequency: process the ordinary and N100 sweeps separately.
selectDevice(device9245, device2208);
x1gFrequencyBase = fullfile(dataRoot, 'AD9245', '02_FrequencyResponse', ...
    'X1G', 'raw');
x1gFrequencyNormalRoot = fullfile(x1gFrequencyBase, ...
    'ad9245_ch01_input_frequency_3dBm_frequency_sweep_20260819_205559_815776');
x1gFrequencyN100Root = fullfile(x1gFrequencyBase, ...
    'ad9245_ch01_input_frequency_n100_3dBm_frequency_sweep_20260819_210149_636455');
x1gFrequencyNormalFiles = directCsvFiles(x1gFrequencyNormalRoot, ...
    x1gFrequencyNormalRoot);
x1gFrequencyN100Files = directCsvFiles(x1gFrequencyN100Root, ...
    x1gFrequencyN100Root);
requireCount(x1gFrequencyNormalFiles, 15, 'AD9245 X1G 普通输入频率');
requireCount(x1gFrequencyN100Files, 15, 'AD9245 X1G N100 输入频率');
x1gFrequencyOptions = struct('configOverride', struct('sampleRate', 20e6));
status = runStep(status, 'AD9245 X1G 普通输入频率', @() ...
    adc_bandwidth_analysis(x1gFrequencyNormalRoot, x1gFrequencyNormalFiles, ...
    fullfile(dataRoot, 'AD9245', '02_FrequencyResponse', 'X1G', 'result'), ...
    x1gFrequencyOptions));
status = runStep(status, 'AD9245 X1G N100 输入频率', @() ...
    adc_bandwidth_analysis(x1gFrequencyN100Root, x1gFrequencyN100Files, ...
    fullfile(dataRoot, 'AD9245', '02_FrequencyResponse', 'X1G', 'result'), ...
    x1gFrequencyOptions));

% AD9245 X1G power: current 1 kHz sweep.
selectDevice(device9245, device2208);
x1gPowerRoot = fullfile(dataRoot, 'AD9245', '03_InputPowerScale', ...
    'X1G', 'raw', ...
    'ad9245_ch01_rf_input_power_1kHz_power_sweep_20260819_210707_036916');
x1gPowerFiles = directCsvFiles(x1gPowerRoot, x1gPowerRoot);
requireCount(x1gPowerFiles, 17, 'AD9245 X1G 输入功率');
x1gPowerOptions = struct('configOverride', struct('testFrequencyHz', 1e3));
status = runStep(status, 'AD9245 X1G 输入功率', @() ...
    adc_power_scale_analysis(x1gPowerRoot, x1gPowerFiles, ...
    fullfile(dataRoot, 'AD9245', '03_InputPowerScale', 'X1G', 'result'), ...
    x1gPowerOptions));

for k = 1:numel(status)
    if ~status(k).Success
        failures{end + 1} = sprintf('%s: %s', status(k).Name, ...
            status(k).Message); %#ok<AGROW>
    end
end
if ~isempty(failures)
    error('cw513:InputAnalysisFailed', '%s', strjoin(failures, newline));
end
end

function selectDevice(deviceFolder, otherDeviceFolder)
%SELECTDEVICE Ensure duplicate device entry names resolve deterministically.

clear adc_bandwidth_analysis adc_power_scale_analysis;
if any(strcmp(strsplit(path, pathsep), otherDeviceFolder))
    rmpath(otherDeviceFolder);
end
addpath(deviceFolder, '-begin');
end

function files = directCsvFiles(dataFolder, relativeRoot)
entries = dir(fullfile(dataFolder, '*.csv'));
files = cell(numel(entries), 1);
for k = 1:numel(entries)
    files{k} = relativeFile(fullfile(dataFolder, entries(k).name), relativeRoot);
end
files = sort(files);
end

function files = nestedCaptureFiles(dataFolder, groupFolder)
pointDirs = dir(fullfile(groupFolder, 'point_*'));
files = {};
for pointIndex = 1:numel(pointDirs)
    if ~pointDirs(pointIndex).isdir
        continue;
    end
    pointFolder = fullfile(groupFolder, pointDirs(pointIndex).name);
    captures = dir(fullfile(pointFolder, '*.csv'));
    for captureIndex = 1:numel(captures)
        files{end + 1, 1} = relativeFile( ...
            fullfile(pointFolder, captures(captureIndex).name), dataFolder); %#ok<AGROW>
    end
end
files = sort(files);
end

function relativeName = relativeFile(filePath, rootFolder)
prefix = [rootFolder filesep];
if strncmpi(filePath, prefix, numel(prefix))
    relativeName = filePath(numel(prefix) + 1:end);
else
    error('cw513:PathOutsideRoot', '文件不在指定 raw 根目录下：%s', filePath);
end
end

function manifest = makeVppManifest(fileNames)
fileCount = numel(fileNames);
inputVoltageVpp = NaN(fileCount, 1);
inputPowerDbm = NaN(fileCount, 1);
for k = 1:fileCount
    token = regexp(fileNames{k}, ...
        '(?i)a_([0-9]+(?:p[0-9]+)?)Vpp', 'tokens', 'once');
    if isempty(token)
        error('cw513:VppSetpointMissing', ...
            '无法从文件名解析 Vpp：%s', fileNames{k});
    end
    inputVoltageVpp(k) = str2double(strrep(token{1}, 'p', '.'));
    inputPowerDbm(k) = 10 * log10((inputVoltageVpp(k) / (2 * sqrt(2)))^2 ...
        / (50 * 1e-3));
end
source = repmat( ...
    "50 ohm equivalent from Vpp; original source load=high_z", fileCount, 1);
definition = repmat( ...
    "P_eq_dBm=10*log10((Vpp/(2*sqrt(2)))^2/(50*1e-3))", fileCount, 1);
manifest = table(string(fileNames(:)), inputPowerDbm, inputVoltageVpp, ...
    repmat(50, fileCount, 1), source, definition, ...
    'VariableNames', {'FileName', 'InputPowerDbm', 'InputVoltageVpp', ...
    'ReferenceImpedanceOhm', 'InputPowerSource', 'InputPowerDefinition'});
end

function requireCount(files, expectedCount, label)
if numel(files) ~= expectedCount
    error('cw513:UnexpectedSourceCount', ...
        '%s 应有 %d 个 CSV，实际为 %d。', label, expectedCount, numel(files));
end
end

function status = runStep(status, name, callback)
row.Name = name;
row.Success = false;
row.Message = '';
try
    callback();
    row.Success = true;
    row.Message = 'completed';
catch analysisError
    row.Message = analysisError.message;
end
status(end + 1) = row;
end

function status = run_cw513_ad2208_new_data_20260820()
%RUN_CW513_AD2208_NEW_DATA_20260820 Process newly captured AD2208 groups.
%   Frequency and input-power groups are kept separate so incomplete or
%   differently configured captures cannot be mixed into one calibration.
%   Raw CSV files and acquisition manifests are read only. New timestamped
%   result bundles are written below each channel's result folder.

libraryRoot = fileparts(fileparts(mfilename('fullpath')));
dataRoot = 'F:\01_Laser\20260727_513test\CW_Data\513_CW_DATA';
deviceFolder = fullfile(libraryRoot, '2208_hy');
status = struct('Name', {}, 'Success', {}, 'Message', {});
failures = {};

% These groups were added after the prior 20260820 00:37 result runs.
% The seven-point JG15 group is intentionally retained as a separate run;
% its coverage status must be decided by the analysis, not hidden.
frequencySpecs = {
    'ADC1_JG15', 'yb2208_ch01_input_frequency_5dBm_frequency_sweep_20260820_153426_445599', 7;
    'ADC1_JG15', 'yb2208_ch01_input_frequency_5dBm_frequency_sweep_20260820_153557_527137', 18;
    % The raw directory was captured from module[1] but is currently named
    % ADC1_JG17 by the ingestion layout; retain the source channel label in
    % the result while using the actual directory.
    'ADC1_JG17', 'yb2208_ch02_input_frequency_5dBm_frequency_sweep_20260820_154256_104927', 18;
    'ADC3_JG19', 'yb2208_ch03_input_frequency_5dBm_frequency_sweep_20260820_160205_000120', 18;
    'ADC5_JG22', 'yb2208_ch04_input_frequency_5dBm_frequency_sweep_20260820_163210_130283', 18};

frequencyBase = fullfile(dataRoot, 'AD2208', '02_FrequencyResponse');
for specIndex = 1:size(frequencySpecs, 1)
    channel = frequencySpecs{specIndex, 1};
    groupName = frequencySpecs{specIndex, 2};
    expectedCount = frequencySpecs{specIndex, 3};
    dataFolder = fullfile(frequencyBase, channel, 'raw');
    groupFolder = fullfile(dataFolder, groupName);
    selectedFiles = nestedCaptureFiles(dataFolder, groupFolder);
    requireCount(selectedFiles, expectedCount, ...
        sprintf('AD2208 %s 输入频率 %s', channel, groupName));
    outputFolder = fullfile(frequencyBase, channel, 'result');
    selectDevice(deviceFolder);
    status = runStep(status, ...
        sprintf('AD2208 %s 输入频率 %s', channel, groupName), ...
        @() adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, ...
        struct('configOverride', struct('sampleRate', 100e6))));
end

% Frequency is taken from the acquisition manifest/file naming. The ADC
% sampling clock remains the AD2208 fixed 100 MHz configuration. The ADC5
% group whose directory says 15 MHz is explicitly processed at 1 MHz because
% its run_manifest.json and source readback both record 1 MHz.
powerSpecs = {
    'ADC1_JG15', 'yb2208_ch01_rf_input_power_1MHz_power_sweep_20260820_171021_194148', 19, 1e6, '1 MHz';
    'ADC2_JG17', 'yb2208_ch02_rf_input_power_15MHz_power_sweep_20260820_154851_230634', 17, 15e6, '15 MHz';
    'ADC2_JG17', 'yb2208_ch02_rf_input_power_1MHz_power_sweep_20260820_171453_912065', 19, 1e6, '1 MHz';
    'ADC3_JG19', 'yb2208_ch03_rf_input_power_1MHz_power_sweep_20260820_155839_629203', 17, 1e6, '1 MHz';
    'ADC3_JG19', 'yb2208_ch03_rf_input_power_1MHz_power_sweep_20260820_172022_573713', 19, 1e6, '1 MHz';
    'ADC5_JG22', 'yb2208_ch04_rf_input_power_15MHz_power_sweep_20260820_163731_590715', 17, 1e6, '1 MHz (目录名误标15 MHz)';
    'ADC5_JG22', 'yb2208_ch04_rf_input_power_1MHz_power_sweep_20260820_165001_293797', 19, 1e6, '1 MHz';
    'ADC6_JG24', 'yb2208_ch05_rf_input_power_1MHz_power_sweep_20260820_170256_277198', 19, 1e6, '1 MHz'};

powerBase = fullfile(dataRoot, 'AD2208', '03_InputPowerScale');
for specIndex = 1:size(powerSpecs, 1)
    channel = powerSpecs{specIndex, 1};
    groupName = powerSpecs{specIndex, 2};
    expectedCount = powerSpecs{specIndex, 3};
    testFrequencyHz = powerSpecs{specIndex, 4};
    conditionLabel = powerSpecs{specIndex, 5};
    dataFolder = fullfile(powerBase, channel, 'raw');
    groupFolder = fullfile(dataFolder, groupName);
    selectedFiles = nestedCaptureFiles(dataFolder, groupFolder);
    requireCount(selectedFiles, expectedCount, ...
        sprintf('AD2208 %s 输入功率 %s', channel, groupName));
    outputFolder = fullfile(powerBase, channel, 'result');
    selectDevice(deviceFolder);
    status = runStep(status, ...
        sprintf('AD2208 %s 输入功率 %s @ %s', channel, groupName, conditionLabel), ...
        @() adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, ...
        struct('configOverride', struct( ...
        'sampleRate', 100e6, 'testFrequencyHz', testFrequencyHz))));
end

for k = 1:numel(status)
    if ~status(k).Success
        failures{end + 1} = sprintf('%s: %s', status(k).Name, ...
            status(k).Message); %#ok<AGROW>
    end
end
if ~isempty(failures)
    error('cw513:Ad2208NewDataFailed', '%s', strjoin(failures, newline));
end
end

function selectDevice(deviceFolder)
%SELECTDEVICE Ensure the independent AD2208 entrypoint is selected.
clear adc_bandwidth_analysis adc_power_scale_analysis;
addpath(deviceFolder, '-begin');
end

function files = nestedCaptureFiles(dataFolder, groupFolder)
captures = dir(fullfile(groupFolder, '*.csv'));
files = cell(numel(captures), 1);
for k = 1:numel(captures)
    files{k} = relativeFile(fullfile(groupFolder, captures(k).name), ...
        dataFolder);
end
files = sort(files);
end

function relativeName = relativeFile(filePath, rootFolder)
prefix = [rootFolder filesep];
if strncmpi(filePath, prefix, numel(prefix))
    relativeName = filePath(numel(prefix) + 1:end);
else
    error('cw513:PathOutsideRoot', ...
        '文件不在指定数据根目录下：%s', filePath);
end
end

function requireCount(files, expectedCount, label)
if numel(files) ~= expectedCount
    error('cw513:UnexpectedSourceCount', ...
        '%s 应有 %d 个 CSV，实际为 %d。', label, expectedCount, ...
        numel(files));
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

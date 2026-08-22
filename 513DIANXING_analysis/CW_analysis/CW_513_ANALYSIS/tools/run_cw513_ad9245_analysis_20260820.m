function status = run_cw513_ad9245_analysis_20260820()
%RUN_CW513_AD9245_ANALYSIS_20260820 Reprocess AD9245 data at 20 MHz.
%   The AD9245 sampling clock is 20 MHz. This driver keeps each acquisition
%   group separate and writes new timestamped bundles below each channel's
%   result folder. Raw CSV files are read only.

libraryRoot = fileparts(fileparts(mfilename('fullpath')));
dataRoot = 'F:\01_Laser\20260727_513test\CW_Data\513_CW_DATA';
deviceFolder = fullfile(libraryRoot, '9245_hy');

status = struct('Name', {}, 'Success', {}, 'Message', {});
failures = {};
sampleRateOverride = struct('sampleRate', 20e6);

% Frequency response: retain duplicate acquisition groups as separate runs.
frequencyBase = fullfile(dataRoot, 'AD9245', '02_FrequencyResponse');
frequencySpecs = {
    'X1G', 'raw', 'ad9245_ch01_input_frequency_3dBm_frequency_sweep_20260819_205559_815776';
    'X1G', 'raw', 'ad9245_ch01_input_frequency_n100_3dBm_frequency_sweep_20260819_210149_636455';
    'X2G', 'raw', 'ad9245_ch02_input_frequency_3dBm_frequency_sweep_20260820_102241_336373';
    'X3G', 'raw', 'ad9245_ch03_input_frequency_3dBm_frequency_sweep_20260820_112518_770946';
    'X3G', 'raw', 'ad9245_ch03_input_frequency_3dBm_frequency_sweep_20260820_112831_903838';
    'X4G', '',    'ad9245_ch04_input_frequency_3dBm_frequency_sweep_20260820_113530_647389'};
for specIndex = 1:size(frequencySpecs, 1)
    channel = frequencySpecs{specIndex, 1};
    rawName = frequencySpecs{specIndex, 2};
    groupName = frequencySpecs{specIndex, 3};
    if isempty(rawName)
        dataFolder = fullfile(frequencyBase, channel);
    else
        dataFolder = fullfile(frequencyBase, channel, rawName);
    end
    groupFolder = fullfile(dataFolder, groupName);
    selectedFiles = nestedCaptureFiles(dataFolder, groupFolder);
    requireCount(selectedFiles, 15, ...
        sprintf('AD9245 %s 输入频率 %s', channel, groupName));
    outputFolder = fullfile(frequencyBase, channel, 'result');
    selectDevice(deviceFolder);
    status = runStep(status, ...
        sprintf('AD9245 %s 输入频率 %s @ 20 MHz', channel, groupName), ...
        @() adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, ...
        struct('configOverride', sampleRateOverride)));
end

% Input power: all four channels, 1 kHz stimulus, 20 MHz ADC sampling clock.
powerBase = fullfile(dataRoot, 'AD9245', '03_InputPowerScale');
powerSpecs = {
    'X1G', 'ad9245_ch01_rf_input_power_1kHz_power_sweep_20260819_210707_036916';
    'X2G', 'ad9245_ch02_rf_input_power_1kHz_power_sweep_20260820_102939_580372';
    'X3G', 'ad9245_ch03_rf_input_power_1kHz_power_sweep_20260820_112056_366101';
    'X4G', 'ad9245_ch04_rf_input_power_1kHz_power_sweep_20260820_114109_484375'};
for specIndex = 1:size(powerSpecs, 1)
    channel = powerSpecs{specIndex, 1};
    groupName = powerSpecs{specIndex, 2};
    dataFolder = fullfile(powerBase, channel, 'raw');
    groupFolder = fullfile(dataFolder, groupName);
    selectedFiles = nestedCaptureFiles(dataFolder, groupFolder);
    requireCount(selectedFiles, 17, ...
        sprintf('AD9245 %s 输入功率', channel));
    powerOptions = struct('configOverride', struct( ...
        'sampleRate', 20e6, 'testFrequencyHz', 1e3));
    outputFolder = fullfile(powerBase, channel, 'result');
    selectDevice(deviceFolder);
    status = runStep(status, ...
        sprintf('AD9245 %s 输入功率 @ 20 MHz', channel), ...
        @() adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, ...
        powerOptions));
end

% INL/DNL: all four 60-capture groups, using the fixed 20 MHz configuration.
inlBase = fullfile(dataRoot, 'AD9245', '05_INL_DNL');
inlSpecs = {
    'X1G_4dBm';
    'X2G_-3.8dBm';
    'X3G_-3.8dBm';
    'X4G_-3.8dBm'};
for specIndex = 1:numel(inlSpecs)
    groupName = inlSpecs{specIndex};
    dataFolder = fullfile(inlBase, groupName, 'raw');
    selectedFiles = directCsvFiles(dataFolder, dataFolder);
    requireCount(selectedFiles, 60, ...
        sprintf('AD9245 %s INL/DNL', groupName));
    outputFolder = fullfile(inlBase, groupName, 'result');
    selectDevice(deviceFolder);
    status = runStep(status, ...
        sprintf('AD9245 %s INL/DNL @ 20 MHz', groupName), ...
        @() adc_inl_dnl_analysis(dataFolder, selectedFiles, outputFolder));
end

for k = 1:numel(status)
    if ~status(k).Success
        failures{end + 1} = sprintf('%s: %s', status(k).Name, ...
            status(k).Message); %#ok<AGROW>
    end
end
if ~isempty(failures)
    error('cw513:Ad9245AnalysisFailed', '%s', strjoin(failures, newline));
end
end

function selectDevice(deviceFolder)
%SELECTDEVICE Ensure the independent 9245 entrypoint is selected.

clear adc_bandwidth_analysis adc_power_scale_analysis adc_inl_dnl_analysis;
addpath(deviceFolder, '-begin');
end

function files = directCsvFiles(dataFolder, relativeRoot)
entries = dir(fullfile(dataFolder, '*.csv'));
files = cell(numel(entries), 1);
for k = 1:numel(entries)
    files{k} = relativeFile(fullfile(dataFolder, entries(k).name), ...
        relativeRoot);
end
files = sort(files);
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

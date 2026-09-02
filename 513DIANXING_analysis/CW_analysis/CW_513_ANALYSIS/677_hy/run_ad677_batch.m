function batchSummary = run_ad677_batch(dataRoot)
%RUN_AD677_BATCH Process the four available AD677 frequency/scale groups.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot) || ~isfolder(dataRoot)
    error('ad677:DataRootNotFound', 'AD677 数据根目录不存在。');
end
specs = {
    '02_FrequencyResponse', '677_1', 'bandwidth';
    '02_FrequencyResponse', '677_2', 'bandwidth';
    '03_InputPowerScale', '677_1', 'power_scale';
    '03_InputPowerScale', '677_2', 'power_scale'};
metric = strings(size(specs, 1), 1);
channel = strings(size(specs, 1), 1);
status = strings(size(specs, 1), 1);
message = strings(size(specs, 1), 1);
runFolder = strings(size(specs, 1), 1);

for specIndex = 1:size(specs, 1)
    metric(specIndex) = specs{specIndex, 1};
    channel(specIndex) = specs{specIndex, 2};
    rawFolder = fullfile(dataRoot, specs{specIndex, 1}, ...
        specs{specIndex, 2}, 'raw');
    captureFolder = findCaptureFolder(rawFolder);
    csvInfo = dir(fullfile(captureFolder, '*.csv'));
    selectedFiles = {csvInfo.name};
    outputFolder = fullfile(dataRoot, specs{specIndex, 1}, ...
        specs{specIndex, 2}, 'result');
    try
        if strcmp(specs{specIndex, 3}, 'bandwidth')
            adc_bandwidth_analysis(captureFolder, selectedFiles, outputFolder);
        else
            adc_power_scale_analysis(captureFolder, selectedFiles, outputFolder);
        end
        status(specIndex) = "成功";
        message(specIndex) = sprintf('%d 个 CSV', numel(selectedFiles));
        runFolder(specIndex) = string(latestSuccessfulRun(outputFolder));
    catch analysisError
        status(specIndex) = "失败";
        message(specIndex) = string(analysisError.message);
        warning('ad677:BatchGroupFailed', '%s/%s：%s', ...
            specs{specIndex, 1}, specs{specIndex, 2}, analysisError.message);
    end
end
batchSummary = table(metric, channel, status, message, runFolder, ...
    'VariableNames', {'Metric', 'Channel', 'Status', 'Message', 'RunFolder'});
disp(batchSummary);
end

function captureFolder = findCaptureFolder(rawFolder)
manifestInfo = dir(fullfile(rawFolder, '**', 'run_manifest.json'));
if numel(manifestInfo) ~= 1
    error('ad677:ManifestCount', ...
        '目录必须且只能包含一个 run_manifest.json：%s。', rawFolder);
end
captureFolder = manifestInfo(1).folder;
end

function runFolder = latestSuccessfulRun(resultFolder)
runFolder = '';
runInfo = dir(fullfile(resultFolder, 'run_*'));
runInfo = runInfo([runInfo.isdir]);
[~, order] = sort([runInfo.datenum], 'descend');
for runIndex = order
    candidate = fullfile(runInfo(runIndex).folder, runInfo(runIndex).name);
    if isfile(fullfile(candidate, 'STATUS_SUCCESS.txt'))
        runFolder = candidate;
        return;
    end
end
end

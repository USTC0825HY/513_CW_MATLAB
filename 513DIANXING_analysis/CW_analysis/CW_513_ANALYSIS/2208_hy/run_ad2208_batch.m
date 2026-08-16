function batchSummary = run_ad2208_batch(dataRoot)
%RUN_AD2208_BATCH Process the available YB2208 CW CSV data tree.
%   The raw data is never modified. Each channel receives a timestamped
%   run directory below its existing results folder.

bootstrapRuntime();
if nargin < 1 || isempty(dataRoot)
    dataRoot = uigetdir(pwd, '选择 AD2208 数据根目录');
end
if isequal(dataRoot, 0) || ~isfolder(dataRoot)
    error('ad2208:DataRootNotFound', 'AD2208 数据根目录不存在。');
end
dataRoot = char(dataRoot);

records = cell(0, 4);
records = processFileGroups(records, dataRoot, '01_SFDR', 'sfdr');
records = processFileGroups(records, dataRoot, '02_FrequencyResponse', 'bandwidth');
records = processFileGroups(records, dataRoot, '03_InputPowerScale', 'power_scale');
records = processFileGroups(records, dataRoot, '05_INL_DNL', 'inl_dnl');

missingMetrics = {'04_Isolation'; '06_Noise'; '07_ClockSource'};
for index = 1:numel(missingMetrics)
    metricPath = fullfile(dataRoot, missingMetrics{index});
    csvFiles = dir(fullfile(metricPath, '**', '*.csv'));
    if isempty(csvFiles)
        records(end + 1, :) = {missingMetrics{index}, '', '未处理', ...
            '当前目录没有原始 CSV'}; %#ok<AGROW>
    end
end

batchSummary = cell2table(records, 'VariableNames', ...
    {'Metric', 'Channel', 'Status', 'Message'});
summaryPath = fullfile(dataRoot, 'AD2208_batch_summary.csv');
writetable(batchSummary, summaryPath);
ad2208_build_input_coverage(dataRoot);
audit_ad2208_results(dataRoot);
disp(batchSummary);
fprintf('AD2208 批处理汇总已保存至：%s\n', summaryPath);
end

function records = processFileGroups(records, dataRoot, metricFolder, analysisId)
metricRoot = fullfile(dataRoot, metricFolder);
if ~isfolder(metricRoot)
    records(end + 1, :) = {metricFolder, '', '未处理', ...
        '指标目录不存在'}; %#ok<AGROW>
    return;
end

fileInfo = dir(fullfile(metricRoot, '**', '*.csv'));
fileInfo = excludeResultFiles(fileInfo);
if isempty(fileInfo)
    records(end + 1, :) = {metricFolder, '', '未处理', ...
        '没有原始 CSV'}; %#ok<AGROW>
    return;
end

groupNames = strings(numel(fileInfo), 1);
relativeNames = strings(numel(fileInfo), 1);
for index = 1:numel(fileInfo)
    absolutePath = fullfile(fileInfo(index).folder, fileInfo(index).name);
    groupNames(index) = string(converter.io.extractChannel(absolutePath));
    relativeNames(index) = string(strrep( ...
        erase(absolutePath, [metricRoot filesep]), filesep, '/'));
end

validGroup = strlength(groupNames) > 0;
for channel = unique(groupNames(validGroup)).'
    selected = find(groupNames == channel);
    if isempty(selected)
        continue;
    end
    resultFolder = fullfile(metricRoot, char(channel), 'results');
    if ~isfolder(resultFolder)
        mkdir(resultFolder);
    end
    selectedFiles = cellstr(relativeNames(selected));
    try
        switch analysisId
            case 'sfdr'
                adc_sfdr_analysis(metricRoot, selectedFiles, resultFolder);
            case 'bandwidth'
                adc_bandwidth_analysis(metricRoot, selectedFiles, resultFolder);
            case 'power_scale'
                adc_power_scale_analysis(metricRoot, selectedFiles, resultFolder);
            case 'inl_dnl'
                adc_inl_dnl_analysis(metricRoot, selectedFiles, resultFolder);
        end
        records(end + 1, :) = {metricFolder, char(channel), '成功', ...
            sprintf('%d 个 CSV', numel(selectedFiles))}; %#ok<AGROW>
    catch analysisError
        records(end + 1, :) = {metricFolder, char(channel), '失败', ...
            analysisError.message}; %#ok<AGROW>
        warning('ad2208:BatchGroupFailed', '%s/%s：%s', ...
            metricFolder, char(channel), analysisError.message);
    end
end
end

function fileInfo = excludeResultFiles(fileInfo)
%EXCLUDERESULTFILES Prevent generated CSV files from becoming raw inputs.

keepFile = true(numel(fileInfo), 1);
for index = 1:numel(fileInfo)
    pathParts = strsplit(fileInfo(index).folder, filesep);
    keepFile(index) = ~any(strcmpi(pathParts, 'result') | ...
        strcmpi(pathParts, 'results'));
end
fileInfo = fileInfo(keepFile);
end

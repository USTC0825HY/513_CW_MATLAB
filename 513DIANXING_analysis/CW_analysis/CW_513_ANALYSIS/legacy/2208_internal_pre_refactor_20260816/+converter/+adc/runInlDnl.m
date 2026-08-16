function results = runInlDnl(config, dataFolder, selectedFileNames, outputFolder)
%RUNINLDNL Run the complete traceable sine-code-density workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择 ADC INL/DNL CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，INL/DNL 分析已取消。\n');
    results = table;
    return;
end
fileNames = sort(fileNames);
runContext = converter.runtime.createRun( ...
    config, dataFolder, fileNames, outputFolder);
try
    adcCodeList = cell(numel(fileNames), 1);
    for fileIndex = 1:numel(fileNames)
        filePath = fullfile(dataFolder, fileNames{fileIndex});
        adcCodeList{fileIndex} = converter.io.readAdcCsv(filePath, config);
        fprintf('INL/DNL 读取：%d/%d  %s\n', ...
            fileIndex, numel(fileNames), fileNames{fileIndex});
    end
    firstPath = fullfile(dataFolder, fileNames{1});
    channelName = converter.io.extractChannel(firstPath);
    if isempty(channelName)
        channelName = 'Unknown';
    end
    [results, details] = converter.adc.calculateInlDnl( ...
        adcCodeList, fileNames, channelName, config);
    [modifiedAt, modifiedElapsedSeconds] = getFileTimes( ...
        dataFolder, fileNames);
    details.captureTable.ModifiedAt = modifiedAt;
    details.captureTable.ModifiedElapsedSeconds = modifiedElapsedSeconds;
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_summary.csv'));
    converter.report.writeTable(details.curveTable, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_curve.csv'));
    converter.report.writeTable(details.captureTable, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_capture_metrics.csv'));
    save(fullfile(runContext.folder, 'ADC_inl_dnl_result.mat'), ...
        'results', 'details');
    converter.report.plotInlDnl(details, runContext.folder, config);
    disp(results);
    fprintf('INL/DNL 结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'INL/DNL analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end

function [modifiedAt, elapsedSeconds] = getFileTimes(dataFolder, fileNames)
fileCount = numel(fileNames);
modifiedAt = cell(fileCount, 1);
modifiedDatenum = NaN(fileCount, 1);
for fileIndex = 1:fileCount
    fileInfo = dir(fullfile(dataFolder, fileNames{fileIndex}));
    if isempty(fileInfo)
        continue;
    end
    modifiedDatenum(fileIndex) = fileInfo(1).datenum;
    modifiedAt{fileIndex} = datestr(fileInfo(1).datenum, 31); %#ok<DATST>
end
validTime = isfinite(modifiedDatenum);
elapsedSeconds = NaN(fileCount, 1);
if any(validTime)
    firstModifiedDatenum = modifiedDatenum(find(validTime, 1));
    elapsedSeconds(validTime) = ...
        (modifiedDatenum(validTime) - firstModifiedDatenum) * 86400;
end
end


function results = runIsolation(config, dataFolder, selectedFileNames, outputFolder)
%RUNISOLATION Run the complete traceable channel-isolation workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择四路隔离度测试 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，隔离度分析已取消。\n');
    results = table;
    return;
end
summaryMask = ~cellfun('isempty', regexpi(fileNames, 'summary\.csv$'));
fileNames = fileNames(~summaryMask);
if isempty(fileNames)
    error('converter:adc:NoIsolationInput', '没有可用于隔离度分析的原始 CSV 文件。');
end

detectedDriven = cellfun(@converter.io.parseDrivenChannel, ...
    fileNames, 'UniformOutput', false);
detectedDriven = unique(detectedDriven(~cellfun('isempty', detectedDriven)));
drivenChannel = config.drivenChannel;
if isscalar(detectedDriven)
    drivenChannel = detectedDriven{1};
end
runContext = converter.runtime.createRun( ...
    config, dataFolder, fileNames, outputFolder);
try
    fileCount = numel(fileNames);
    adcCodeList = cell(fileCount, 1);
    channelNames = strings(fileCount, 1);
    for fileIndex = 1:fileCount
        filePath = fullfile(dataFolder, fileNames{fileIndex});
        channelNames(fileIndex) = converter.io.detectChannel( ...
            filePath, fileNames{fileIndex}, dataFolder, config);
        if strlength(channelNames(fileIndex)) == 0
            error('converter:adc:ChannelNotDetected', ...
                '无法识别通道：%s', fileNames{fileIndex});
        end
        adcCodeList{fileIndex} = converter.io.readAdcCsv(filePath, config);
    end
    [results, details] = converter.adc.calculateIsolation( ...
        adcCodeList, channelNames, drivenChannel, config);
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_isolation_summary.csv'));
    save(fullfile(runContext.folder, 'ADC_isolation_result.mat'), ...
        'results', 'details');
    converter.report.plotIsolation(results, drivenChannel, ...
        details.drivenFrequencyHz, runContext.folder, config);
    disp(results);
    fprintf('\n最差隔离度：%.3f dB\n', details.worstIsolationDb);
    fprintf('隔离度结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'Isolation analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end


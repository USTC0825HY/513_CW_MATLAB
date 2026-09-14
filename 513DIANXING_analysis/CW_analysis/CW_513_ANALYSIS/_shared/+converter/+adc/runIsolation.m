function results = runIsolation(config, dataFolder, selectedFileNames, outputFolder)
%RUNISOLATION Run the complete traceable channel-isolation workflow.

interactive = isempty(selectedFileNames);
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

channelNames = converter.io.resolveAdcChannels(config, dataFolder, fileNames, interactive);
if isempty(channelNames), results = table; return; end
drivenChannel = config.drivenChannel;
if interactive
    [index, accepted] = listdlg('ListString', cellstr(channelNames), ...
        'SelectionMode', 'single', 'PromptString', '选择实际驱动通道（其文件作为参考）');
    if ~accepted, results = table; return; end
    drivenChannel = char(channelNames(index));
    answer = inputdlg({'已确认输入频率 / Hz','本次共同参考面和连接条件'}, ...
        '确认 ADC 隔离度条件', 1, {num2str(config.isolationFrequencyHz),' '});
    if isempty(answer), results = table; return; end
    config.isolationFrequencyHz = str2double(answer{1});
    if strlength(strtrim(string(answer{2}))) == 0
        error('converter:adc:ReferenceRequired', '请明确隔离度参考面和连接条件。');
    end
    config.referencePlane = answer{2};
end
validateattributes(config.isolationFrequencyHz, {'numeric'}, {'scalar','real','finite','positive'});
if nnz(channelNames == string(drivenChannel)) ~= 1
    error('converter:adc:DrivenChannelMissing', '必须选择唯一驱动通道参考文件：%s', drivenChannel);
end
if numel(unique(channelNames)) ~= numel(channelNames)
    error('converter:adc:DuplicateChannels', '每通道只选择一份记录。');
end
if numel(channelNames) < 2
    error('converter:adc:QuietChannelMissing', '还需要至少一个受扰通道文件。');
end
config.drivenChannel = drivenChannel;
config.inputChannels = cellstr(channelNames);
runContext = converter.runtime.createRun( ...
    config, dataFolder, fileNames, outputFolder);
try
    fileCount = numel(fileNames);
    adcCodeList = cell(fileCount, 1);
    for fileIndex = 1:fileCount
        filePath = converter.io.resolveInputPath(dataFolder, fileNames{fileIndex});
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


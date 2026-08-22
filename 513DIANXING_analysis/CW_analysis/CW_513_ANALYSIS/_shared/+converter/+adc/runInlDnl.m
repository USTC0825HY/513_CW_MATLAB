function results = runInlDnl(config, dataFolder, selectedFileNames, outputFolder)
%RUNINLDNL Run the complete traceable sine-code-density workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择 ADC INL/DNL CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，INL/DNL 分析已取消。\n');
    results = table;
    return;
end
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
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_summary.csv'));
    converter.report.writeTable(details.curveTable, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_curve.csv'));
    analysisParameters = createParameterTable(config);
    converter.report.writeTable(analysisParameters, ...
        fullfile(runContext.folder, 'ADC_inl_dnl_analysis_parameters.csv'));
    save(fullfile(runContext.folder, 'ADC_inl_dnl_result.mat'), ...
        'results', 'details', 'analysisParameters');
    converter.report.plotInlDnl(details, runContext.folder, config);
    disp(results);
    fprintf('INL/DNL 结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'INL/DNL analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end

function parameterTable = createParameterTable(config)
%CREATEPARAMETERTABLE Persist the configuration used for this INL/DNL run.
parameterName = {'sample_rate_hz'; 'adc_bits'; 'adc_code_format'; ...
    'margin_code'; 'minimum_fit_r2'; 'fit_frequency_source'; ...
    'code_density_method'};
parameterValue = {num2str(config.sampleRate, 15); num2str(config.adcBits); ...
    config.adcCodeFormat; num2str(config.marginCode, 15); ...
    num2str(config.minimumFitR2, 15); ...
    'FFT estimate refined by minimum sine-fit residual'; ...
    'sine-fit residual and code-density histogram'};
parameterTable = table(parameterName, parameterValue, ...
    'VariableNames', {'Parameter', 'Value'});
end


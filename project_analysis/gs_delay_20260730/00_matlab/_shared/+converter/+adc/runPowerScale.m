function results = runPowerScale(config, dataFolder, selectedFileNames, outputFolder)
%RUNPOWERSCALE Run the complete traceable input-power calibration workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择输入功率标定 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，功率标定已取消。\n');
    results = table;
    return;
end
inputPowerDbm = cellfun(@converter.io.parsePowerDbm, fileNames);
parseValid = isfinite(inputPowerDbm);
if any(~parseValid)
    fprintf('以下文件名无法解析 dBm，已忽略：\n');
    fprintf('  %s\n', fileNames{~parseValid});
    fileNames = fileNames(parseValid);
    inputPowerDbm = inputPowerDbm(parseValid);
end
if isempty(fileNames)
    error('converter:adc:NoPowerInput', '没有可解析输入功率的 CSV 文件。');
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
        adcCodeList{fileIndex} = converter.io.readAdcCsv(filePath, config);
    end
    [results, details] = converter.adc.calculatePowerScale( ...
        adcCodeList, fileNames, inputPowerDbm, channelNames, config);
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_power_scale_summary.csv'));
    save(fullfile(runContext.folder, 'ADC_power_scale_result.mat'), ...
        'results', 'details');
    converter.report.plotPowerScale(results, details, runContext.folder, config);
    disp(results);
    fprintf('\n通道：%s\n', char(details.channelName));
    fprintf('标定斜率：%.6f dB/dBm\n', details.coefficient(1));
    fprintf('标定截距：%.6f dBFS\n', details.coefficient(2));
    fprintf('标定 R^2：%.8f\n', details.calibrationR2);
    fprintf('功率标定结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'Power-scale analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end


function results = runSfdr(config, dataFolder, selectedFileNames, outputFolder)
%RUNSFDR Run the complete traceable SFDR workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择需要计算 SFDR 的 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，SFDR 分析已取消。\n');
    results = table;
    return;
end
runContext = converter.runtime.createRun( ...
    config, dataFolder, fileNames, outputFolder);
try
    fileCount = numel(fileNames);
    fundamentalFrequencyHz = zeros(fileCount, 1);
    codePp = zeros(fileCount, 1);
    sfdrDb = zeros(fileCount, 1);
    snrDb = zeros(fileCount, 1);
    sinadDb = zeros(fileCount, 1);
    thdDb = zeros(fileCount, 1);
    enobBit = zeros(fileCount, 1);
    fitConfig = config;
    fitConfig.fitMode = 'auto';
    for fileIndex = 1:fileCount
        fileName = fileNames{fileIndex};
        adcCode = converter.io.readAdcCsv( ...
            converter.io.resolveInputPath(dataFolder, fileName), config);
        metrics = converter.adc.analyzeDynamicMetrics(adcCode, fitConfig);
        fundamentalFrequencyHz(fileIndex) = metrics.spectrum.fundamentalFrequencyHz;
        codePp(fileIndex) = metrics.fit.codePp;
        sfdrDb(fileIndex) = metrics.dynamic.SFDR;
        snrDb(fileIndex) = metrics.dynamic.SNR;
        sinadDb(fileIndex) = metrics.dynamic.SINAD;
        thdDb(fileIndex) = metrics.dynamic.THD;
        enobBit(fileIndex) = metrics.dynamic.ENOB;
        fprintf(['\n文件：%s\n基波：%.6f MHz\nCode_pp：%.3f LSB\n' ...
            'SFDR：%.3f dB，SNR：%.3f dB，SINAD：%.3f dB\n' ...
            'THD：%.3f dB，ENOB：%.3f bit\n'], ...
            fileName, fundamentalFrequencyHz(fileIndex) / 1e6, ...
            codePp(fileIndex), sfdrDb(fileIndex), snrDb(fileIndex), ...
            sinadDb(fileIndex), thdDb(fileIndex), enobBit(fileIndex));
        converter.report.plotSfdrSpectrum( ...
            metrics, fileName, runContext.folder, config);
    end
    results = table(string(fileNames(:)), fundamentalFrequencyHz, codePp, ...
        sfdrDb, snrDb, sinadDb, thdDb, enobBit, ...
        'VariableNames', {'FileName', 'FundamentalFrequencyHz', 'CodePp', ...
        'SFDR', 'SNR', 'SINAD', 'THD', 'ENOB'});
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_SFDR_summary.csv'));
    save(fullfile(runContext.folder, 'ADC_SFDR_result.mat'), 'results');
    converter.report.plotSfdrSummary(results, runContext.folder, config);
    disp(results);
    fprintf('\nSFDR 结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'SFDR analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end


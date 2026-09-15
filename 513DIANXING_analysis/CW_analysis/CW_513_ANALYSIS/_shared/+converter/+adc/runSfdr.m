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
    sourceSampleCount = zeros(fileCount, 1);
    analysisSampleCount = zeros(fileCount, 1);
    [sampleStride, analysisSampleRateHz, samplingMode, resultUse] = ...
        resolveSampling(config);
    fprintf(['SFDR采样：源 %.9g Hz，每%d点保留1点，' ...
        '分析采样率 %.9g Hz；%s。\n'], config.sampleRate, ...
        sampleStride, analysisSampleRateHz, resultUse);
    fitConfig = config;
    fitConfig.fitMode = 'auto';
    fitConfig.sampleRate = analysisSampleRateHz;
    for fileIndex = 1:fileCount
        fileName = fileNames{fileIndex};
        adcCode = converter.io.readAdcCsv( ...
            converter.io.resolveInputPath(dataFolder, fileName), config);
        sourceSampleCount(fileIndex) = numel(adcCode);
        adcCode = adcCode(1:sampleStride:end);
        analysisSampleCount(fileIndex) = numel(adcCode);
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
            metrics, fileName, runContext.folder, fitConfig);
    end
    results = table(string(fileNames(:)), fundamentalFrequencyHz, codePp, ...
        sfdrDb, snrDb, sinadDb, thdDb, enobBit, ...
        'VariableNames', {'FileName', 'FundamentalFrequencyHz', 'CodePp', ...
        'SFDR', 'SNR', 'SINAD', 'THD', 'ENOB'});
    if sampleStride > 1 || isfield(config, 'sfdrSamplingMode')
        results.SourceSampleCount = sourceSampleCount;
        results.AnalysisSampleCount = analysisSampleCount;
        results.SourceSampleRateHz = repmat(config.sampleRate, fileCount, 1);
        results.SampleStride = repmat(sampleStride, fileCount, 1);
        results.AnalysisSampleRateHz = repmat(analysisSampleRateHz, fileCount, 1);
        results.SamplingMode = repmat(string(samplingMode), fileCount, 1);
        results.ResultUse = repmat(string(resultUse), fileCount, 1);
    end
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

function [sampleStride, analysisSampleRateHz, samplingMode, resultUse] = ...
        resolveSampling(config)
sampleStride = 1;
analysisSampleRateHz = config.sampleRate;
samplingMode = 'direct_uniform_samples';
resultUse = '按器件配置解释';
if isfield(config, 'sfdrSampleStride')
    sampleStride = config.sfdrSampleStride;
end
validateattributes(sampleStride, {'numeric'}, ...
    {'real', 'finite', 'scalar', 'integer', 'positive'});
if isfield(config, 'sfdrAnalysisSampleRateHz')
    analysisSampleRateHz = config.sfdrAnalysisSampleRateHz;
else
    analysisSampleRateHz = config.sampleRate / sampleStride;
end
validateattributes(analysisSampleRateHz, {'numeric'}, ...
    {'real', 'finite', 'scalar', 'positive'});
expectedRateHz = config.sampleRate / sampleStride;
if abs(analysisSampleRateHz - expectedRateHz) > ...
        max(1, expectedRateHz) * 1e-12
    error('converter:adc:InconsistentSfdrSamplingRate', ...
        'SFDR分析采样率必须等于源采样率除以抽样步长。');
end
if isfield(config, 'sfdrSamplingMode')
    samplingMode = char(string(config.sfdrSamplingMode));
end
if isfield(config, 'sfdrResultUse')
    resultUse = char(string(config.sfdrResultUse));
end
end


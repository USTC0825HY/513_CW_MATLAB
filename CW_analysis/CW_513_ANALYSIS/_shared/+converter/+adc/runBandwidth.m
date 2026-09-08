function results = runBandwidth(config, dataFolder, selectedFileNames, outputFolder)
%RUNBANDWIDTH Run the complete traceable bandwidth workflow.

[fileNames, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFileNames, '选择频率响应 CSV 文件');
if isempty(fileNames)
    fprintf('未选择文件，带宽分析已取消。\n');
    results = table;
    return;
end
fileFrequencyHz = cellfun(@converter.io.parseFrequencyHz, fileNames).';
runContext = converter.runtime.createRun( ...
    config, dataFolder, fileNames, outputFolder);
try
    adcCodeList = readAllCodes(dataFolder, fileNames, config);
    [results, details] = converter.adc.calculateBandwidth( ...
        adcCodeList, fileNames, fileFrequencyHz, config);
    converter.report.writeTable(results, ...
        fullfile(runContext.folder, 'ADC_bandwidth_summary.csv'));
    analysisParameters = createParameterTable(config);
    converter.report.writeTable(analysisParameters, ...
        fullfile(runContext.folder, 'analysis_parameters.csv'));
    converter.report.writeTable(analysisParameters, ...
        fullfile(runContext.folder, 'ADC_bandwidth_analysis_parameters.csv'));
    bandwidth3dBHz = details.bandwidth3dBHz;
    referenceCodePp = details.referenceCodePp;
    sampleRate = config.sampleRate;
    save(fullfile(runContext.folder, 'ADC_bandwidth_result.mat'), ...
        'results', 'analysisParameters', 'bandwidth3dBHz', ...
        'referenceCodePp', 'sampleRate');
    converter.report.plotBandwidth( ...
        results, bandwidth3dBHz, runContext.folder, config);
    disp(results);
    if isfinite(bandwidth3dBHz)
        fprintf('\n估算 -3 dB 带宽：%.6f MHz\n', bandwidth3dBHz / 1e6);
    else
        fprintf('\n覆盖内未发现 -3 dB 交点：覆盖不足，暂不能判定。\n');
    end
    fprintf('带宽结果已保存至：%s\n', runContext.folder);
    converter.runtime.finishRun(runContext, true, 'Bandwidth analysis completed.');
catch analysisError
    converter.runtime.finishRun(runContext, false, analysisError.message);
    rethrow(analysisError);
end
end

function adcCodeList = readAllCodes(dataFolder, fileNames, config)
adcCodeList = cell(numel(fileNames), 1);
for fileIndex = 1:numel(fileNames)
    fprintf('[%d/%d] 正在读取：%s\n', ...
        fileIndex, numel(fileNames), fileNames{fileIndex});
    adcCodeList{fileIndex} = converter.io.readAdcCsv( ...
        converter.io.resolveInputPath(dataFolder, fileNames{fileIndex}), config);
end
end

function parameterTable = createParameterTable(config)
parameterName = {'sample_rate_hz'; 'adc_bits'; 'adc_code_format'; ...
    'minimum_fit_r2'; 'reference_point_count'; 'reference_method'; ...
    'fit_frequency_source'; 'frequency_check_method'; 'crossing_method'; ...
    'clipping_margin_code'; 'calibration_reference'};
parameterValue = {num2str(config.sampleRate, 12); num2str(config.adcBits); ...
    config.adcCodeFormat; num2str(config.minimumFitR2, 12); ...
    num2str(config.referencePointCount); ...
    'median of lowest-frequency consecutive valid points'; ...
    getFitFrequencySource(config); ...
    'FFT estimate; tolerance=max(relative tolerance, 2 FFT bins)'; ...
    'linear interpolation in log10(f)-dB plane'; ...
    num2str(config.clippingMarginCode); ...
    'relative code amplitude; no voltage calibration used'};
parameterTable = table(parameterName, parameterValue, ...
    'VariableNames', {'Parameter', 'Value'});
end

function value = getFitFrequencySource(config)
if isfield(config, 'fitFrequencySource') && ...
        strcmpi(config.fitFrequencySource, 'file')
    value = 'frequency parsed from filename; measured frequency retained for QA';
else
    value = 'FFT estimate refined by minimum sine-fit residual';
end
end


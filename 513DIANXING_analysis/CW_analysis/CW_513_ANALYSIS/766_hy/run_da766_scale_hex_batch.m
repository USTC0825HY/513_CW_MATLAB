function [batchResult, batchFolder] = run_da766_scale_hex_batch(dataRoot, outputRoot)
%RUN_DA766_SCALE_HEX_BATCH Process all DA766 scale channels.
%   Each immediate subfolder of dataRoot is treated as an independent
%   output channel.  Only standard CODE*.mat captures are selected; files
%   ending in _CH2.mat are retained in the selection audit as excluded
%   historical data.

if nargin < 1 || isempty(dataRoot)
    error('cw513:DataRootRequired', '必须提供DA766 06_scale数据根目录。');
end
dataRoot = char(dataRoot);
if ~isfolder(dataRoot)
    error('cw513:DataRootMissing', 'DA766刻度数据根目录不存在：%s', dataRoot);
end
if nargin < 2 || isempty(outputRoot)
    outputRoot = fullfile(dataRoot, 'results');
else
    outputRoot = char(outputRoot);
end
if ~isfolder(outputRoot), mkdir(outputRoot); end

bootstrapRuntime();
batchFolder = localUniqueFolder(outputRoot, ...
    ['DA766_scale_hex_batch_' datestr(now, 'yyyymmdd_HHMMSS')]); %#ok<DATST,TNOW1>
mkdir(batchFolder);

channelDirs = dir(dataRoot);
channelDirs = channelDirs([channelDirs.isdir]);
channelDirs = channelDirs(~ismember({channelDirs.name}, {'.', '..'}));
channelDirs = channelDirs(~strcmpi({channelDirs.name}, 'results'));
[~, channelOrder] = sort(lower(string({channelDirs.name})));
channelDirs = channelDirs(channelOrder);

summaryList = {};
measurementList = {};
selectionRows = repmat(localSelectionTemplate(), 0, 1);
errorRows = repmat(localErrorTemplate(), 0, 1);
channelNames = cell(numel(channelDirs), 1);

for channelIndex = 1:numel(channelDirs)
    channelName = channelDirs(channelIndex).name;
    channelNames{channelIndex} = channelName;
    channelFolder = fullfile(dataRoot, channelName);
    [selectedFiles, selectionRows] = localSelectChannelFiles( ...
        channelFolder, channelName, selectionRows);
    if numel(selectedFiles) < 2
        errorRows(end + 1) = localErrorRow(channelName, channelFolder, ...
            '可用于拟合的标准MAT文件少于2个', numel(selectedFiles)); %#ok<AGROW>
        continue;
    end

    try
        result = dac_scale_hex_analysis(channelFolder, selectedFiles, batchFolder);
        channelSummary = result.summary;
        channelSummary.channel = repmat(string(channelName), height(channelSummary), 1);
        channelSummary.run_folder = repmat(string(result.outputFolder), ...
            height(channelSummary), 1);
        channelSummary.k = string(sprintf('%.6e', ...
            channelSummary.slope_v_per_code_vpp));
        channelSummary.b = string(sprintf('%.6e', channelSummary.intercept_v));
        converter.report.writeTable(channelSummary, fullfile(result.outputFolder, ...
            'dac_scale_summary_scientific.csv'));
        summaryList{end + 1, 1} = channelSummary; %#ok<AGROW>

        channelMeasurements = result.measurements;
        channelMeasurements.channel = repmat(string(channelName), ...
            height(channelMeasurements), 1);
        channelMeasurements.run_folder = repmat(string(result.outputFolder), ...
            height(channelMeasurements), 1);
        channelMeasurements.raw_code_hex = localHexColumn( ...
            channelMeasurements.raw_code);
        measurementList{end + 1, 1} = channelMeasurements; %#ok<AGROW>
    catch exception
        errorRows(end + 1) = localErrorRow(channelName, channelFolder, ...
            exception.message, numel(selectedFiles)); %#ok<AGROW>
    end
end

summaryTable = localConcatenateTables(summaryList, 'summary');
measurementTable = localConcatenateTables(measurementList, 'measurement');
selectionTable = struct2table(selectionRows);
errorTable = struct2table(errorRows);

converter.report.writeTable(selectionTable, fullfile(batchFolder, ...
    'DA766_scale_input_selection.csv'));
converter.report.writeTable(measurementTable, fullfile(batchFolder, ...
    'DA766_scale_batch_measurements.csv'));
converter.report.writeTable(summaryTable, fullfile(batchFolder, ...
    'DA766_scale_batch_summary.csv'));
converter.report.writeTable(errorTable, fullfile(batchFolder, ...
    'DA766_scale_batch_errors.csv'));

inputManifest = localInputManifest(measurementTable);
converter.report.writeTable(inputManifest, fullfile(batchFolder, ...
    'DA766_scale_batch_manifest.csv'));

parameterTable = localBatchParameters(dataRoot, batchFolder, ...
    numel(channelDirs), height(measurementTable), measurementTable);
converter.report.writeTable(parameterTable, fullfile(batchFolder, ...
    'DA766_scale_batch_parameters.csv'));

figureHandle = localTypicalFigure(channelNames, summaryTable, measurementTable);
converter.report.saveFigure(figureHandle, fullfile(batchFolder, ...
    'DA766_scale_typical_fit'), 200);
close(figureHandle);
individualFigureStems = localWriteIndividualFigures(channelNames, ...
    summaryTable, measurementTable, batchFolder);

allSucceeded = isempty(errorRows) && ~isempty(summaryList);
status = '失败';
if allSucceeded, status = '成功'; end
localWriteStatus(batchFolder, status, numel(channelDirs), ...
    height(summaryTable), height(errorTable));

batchResult = struct('device', 'DA766', 'analysis', 'scale_hex_unsigned', ...
    'dataRoot', dataRoot, 'outputFolder', batchFolder, 'status', status, ...
    'summary', summaryTable, 'measurements', measurementTable, ...
    'selection', selectionTable, 'errors', errorTable, ...
    'parameters', parameterTable);
batchResult.individualFigureStems = individualFigureStems;
save(fullfile(batchFolder, 'DA766_scale_batch_result.mat'), 'batchResult');
end

function folder = localUniqueFolder(parentFolder, stem)
folder = fullfile(parentFolder, stem);
suffix = 1;
while isfolder(folder)
    folder = fullfile(parentFolder, sprintf('%s_%02d', stem, suffix));
    suffix = suffix + 1;
end
end

function [selectedFiles, rows] = localSelectChannelFiles(channelFolder, channelName, rows)
items = dir(fullfile(channelFolder, '*.mat'));
names = {};
codes = [];
for k = 1:numel(items)
    fileName = items(k).name;
    if ~isempty(regexpi(fileName, '_CH2\.mat$', 'once'))
        rows(end + 1) = localSelectionRow(channelName, fileName, false, ...
            '历史CH2文件未纳入本次标准通道批次', NaN); %#ok<AGROW>
        continue;
    end
    token = regexp(fileName, ...
        '(?i)(?:code|coade)[-_]?([0-9a-f]+)(?:-\d+)?\.mat$', ...
        'tokens', 'once');
    if isempty(token)
        rows(end + 1) = localSelectionRow(channelName, fileName, false, ...
            '文件名未匹配CODE十六进制码值格式', NaN); %#ok<AGROW>
        continue;
    end
    rawCode = hex2dec(token{1});
    if ~isfinite(rawCode) || rawCode >= 2^16
        rows(end + 1) = localSelectionRow(channelName, fileName, false, ...
            '十六进制码值超出16 bit范围', rawCode); %#ok<AGROW>
        continue;
    end
    names{end + 1, 1} = fileName; %#ok<AGROW>
    codes(end + 1, 1) = rawCode; %#ok<AGROW>
end

[~, order] = sort(codes);
selectedFiles = names(order);
for k = 1:numel(selectedFiles)
    rows(end + 1) = localSelectionRow(channelName, selectedFiles{k}, true, ...
        '纳入', codes(order(k))); %#ok<AGROW>
end
end

function row = localSelectionTemplate()
row = struct('channel', "", 'input_file', "", 'selected', false, ...
    'reason', "", 'raw_code_hex', "", 'raw_code', NaN, ...
    'signed_code', NaN, 'code_vpp', NaN);
end

function row = localSelectionRow(channelName, fileName, selected, reason, rawCode)
row = localSelectionTemplate();
row.channel = string(channelName);
row.input_file = string(fileName);
row.selected = selected;
row.reason = string(reason);
if isfinite(rawCode)
    row.raw_code_hex = string(sprintf('0x%04X', round(rawCode)));
    row.raw_code = rawCode;
    if rawCode >= 2^15
        row.signed_code = rawCode - 2^16;
    else
        row.signed_code = rawCode;
    end
    row.code_vpp = 2 * abs(row.signed_code);
end
end

function row = localErrorTemplate()
row = struct('channel', "", 'data_folder', "", 'message', "", ...
    'selected_file_count', NaN);
end

function row = localErrorRow(channelName, dataFolder, message, selectedCount)
row = localErrorTemplate();
row.channel = string(channelName);
row.data_folder = string(dataFolder);
row.message = string(message);
row.selected_file_count = selectedCount;
end

function column = localHexColumn(rawCodes)
column = strings(numel(rawCodes), 1);
for k = 1:numel(rawCodes)
    if isfinite(rawCodes(k))
        column(k) = string(sprintf('0x%04X', round(rawCodes(k))));
    end
end
end

function tableValue = localConcatenateTables(tableList, tableType)
if ~isempty(tableList)
    tableValue = vertcat(tableList{:});
    return;
end
if strcmp(tableType, 'summary')
    tableValue = table(strings(0, 1), strings(0, 1), NaN(0, 1), NaN(0, 1), ...
        NaN(0, 1), NaN(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), ...
        'VariableNames', {'device', 'analysis', 'slope_v_per_code_vpp', ...
        'intercept_v', 'fit_r_squared', 'fit_point_count', 'status', ...
        'channel', 'run_folder', 'k', 'b'});
else
    tableValue = table(strings(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), strings(0, 1), NaN(0, 1), NaN(0, 1), ...
        NaN(0, 1), strings(0, 1), NaN(0, 1), NaN(0, 1), NaN(0, 1), ...
        NaN(0, 1), false(0, 1), strings(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', {'input_file', 'input_path', 'source_sha256', ...
        'variable', 'code_vpp_definition', 'exclusion_reason', 'raw_code', ...
        'signed_code', 'code_vpp', 'sample_rate_hz', 'duration_s', ...
        'output_vpp_v', 'fit_r_squared', 'fit_residual_rms_v', ...
        'included_in_fit', 'channel', 'run_folder', 'raw_code_hex'});
end
end

function tableValue = localInputManifest(measurements)
names = {'channel', 'input_file', 'input_path', 'source_sha256', ...
    'raw_code_hex', 'raw_code', 'signed_code', 'code_vpp'};
if isempty(measurements)
    tableValue = table(strings(0, 1), strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), NaN(0, 1), NaN(0, 1), NaN(0, 1), ...
        'VariableNames', names);
else
    tableValue = measurements(:, names);
end
end

function tableValue = localBatchParameters(dataRoot, batchFolder, ...
    channelCount, measurementCount, measurements)
sampleRateText = '未获得';
if ~isempty(measurements)
    values = measurements.sample_rate_hz(isfinite(measurements.sample_rate_hz));
    if ~isempty(values), sampleRateText = mat2str(unique(values)'); end
end
names = {'deviceId'; 'analysisId'; 'codeNameFormat'; 'rawCodeInterpretation'; ...
    'signedConversion'; 'codeVppDefinition'; 'fitModel'; 'toneFrequencyHz'; ...
    'hardwareGain'; 'minimumFitR2'; 'minimumCodeVpp'; 'maximumCodeVpp'; ...
    'actualSampleRateHz'; 'channelCount'; 'measurementCount'; 'dataRoot'; ...
    'outputFolder'; 'formalEnabled'; 'formalStatus'};
values = {'DA766'; 'scale_hex_unsigned'; 'unsigned_16bit_hex'; ...
    '0x0000-0x7FFF -> 0..32767; 0x8000-0xFFFF -> -32768..-1'; ...
    'signed = raw - 0x10000 when raw >= 0x8000'; ...
    '2*abs(signed_code)'; 'Vpp = slope * CodePp + intercept'; '1525'; ...
    '1'; '0.98'; '512'; num2str(2^16, '%.12g'); sampleRateText; ...
    num2str(channelCount); num2str(measurementCount); dataRoot; batchFolder; ...
    'false'; '暂不能判定（需求/参考面未闭环）'};
tableValue = table(string(names), string(values), ...
    'VariableNames', {'Parameter', 'Value'});
end

function figureHandle = localTypicalFigure(channelNames, summary, measurements)
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [100 100 1500 850]);
channelCount = numel(channelNames);
if channelCount == 0
    axes('Parent', figureHandle); text(0.2, 0.5, '无可用DA766刻度结果'); axis off;
    return;
end
columnCount = min(4, max(1, channelCount));
rowCount = ceil(channelCount / columnCount);
for k = 1:channelCount
    axisHandle = subplot(rowCount, columnCount, k, 'Parent', figureHandle);
    localPlotChannel(axisHandle, string(channelNames{k}), summary, ...
        measurements, false);
end
annotation(figureHandle, 'textbox', [0.30 0.955 0.40 0.035], ...
    'String', 'DA766 十六进制码值刻度：Vpp = a·CodePp + b', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'Color', 'k', 'FontWeight', 'bold');
end

function figureStems = localWriteIndividualFigures(channelNames, summary, ...
    measurements, batchFolder)
figureStems = cell(numel(channelNames), 1);
for k = 1:numel(channelNames)
    channel = string(channelNames{k});
    figureHandle = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1100 760]);
    axisHandle = axes('Parent', figureHandle);
    localPlotChannel(axisHandle, channel, summary, measurements, true);
    annotation(figureHandle, 'textbox', [0.22 0.955 0.56 0.035], ...
        'String', sprintf('DA766 %s 十六进制码值刻度', char(channel)), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'Color', 'k', 'FontWeight', 'bold');
    stem = fullfile(batchFolder, sprintf('DA766_%s_scale_fit', ...
        localSafeName(channel)));
    converter.report.saveFigure(figureHandle, stem, 200);
    close(figureHandle);
    figureStems{k} = stem;
end
end

function localPlotChannel(axisHandle, channel, summary, measurements, showLegend)
hold(axisHandle, 'on'); grid(axisHandle, 'on');
set(axisHandle, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
    'GridColor', [0.75 0.75 0.75], 'FontSize', 11);
legendHandles = [];
legendLabels = {};
if ~isempty(measurements)
    rows = measurements.channel == channel;
    used = rows & measurements.included_in_fit;
    excluded = rows & ~measurements.included_in_fit;
    if any(used)
        usedHandle = plot(axisHandle, measurements.code_vpp(used), ...
            measurements.output_vpp_v(used), 'o', ...
            'Color', [0.1 0.4 0.8], ...
            'MarkerFaceColor', [0.1 0.4 0.8], 'MarkerSize', 7);
        legendHandles(end + 1) = usedHandle; %#ok<AGROW>
        legendLabels{end + 1} = '拟合点'; %#ok<AGROW>
    end
    if any(excluded)
        excludedHandle = plot(axisHandle, measurements.code_vpp(excluded), ...
            measurements.output_vpp_v(excluded), 'rx', 'LineWidth', 1.4, ...
            'MarkerSize', 10);
        legendHandles(end + 1) = excludedHandle; %#ok<AGROW>
        legendLabels{end + 1} = '排除/保留观察点'; %#ok<AGROW>
    end
    fitRow = summary(summary.channel == channel, :);
    if height(fitRow) == 1 && isfinite(fitRow.slope_v_per_code_vpp)
        x = measurements.code_vpp(used | excluded);
        if ~isempty(x)
            x = linspace(min(x), max(x), 200);
            fitHandle = plot(axisHandle, x, ...
                fitRow.slope_v_per_code_vpp * x + fitRow.intercept_v, ...
                'r-', 'LineWidth', 1.3);
            legendHandles(end + 1) = fitHandle; %#ok<AGROW>
            legendLabels{end + 1} = '线性拟合'; %#ok<AGROW>
            text(axisHandle, 0.04, 0.91, sprintf( ...
                'k = %.6e V/CodePp\nb = %.6e V\nR^2 = %.6f', ...
                fitRow.slope_v_per_code_vpp, fitRow.intercept_v, ...
                fitRow.fit_r_squared), 'Units', 'normalized', ...
                'Color', 'k', 'FontSize', 10, 'VerticalAlignment', 'top');
        end
    end
end
xlabel(axisHandle, 'DAC CodePp (code)');
ylabel(axisHandle, 'Output Vpp (V)');
title(axisHandle, sprintf('DA766 %s', char(channel)), ...
    'Interpreter', 'none', 'Color', 'k');
if showLegend && ~isempty(legendHandles)
    legend(axisHandle, legendHandles, legendLabels, 'Location', 'best');
end
end

function name = localSafeName(channel)
name = regexprep(char(channel), '[^a-zA-Z0-9_-]', '_');
end

function localWriteStatus(batchFolder, status, channelCount, successCount, errorCount)
if strcmp(status, '成功')
    fileName = 'BATCH_STATUS_SUCCESS.txt';
else
    fileName = 'BATCH_STATUS_FAILED.txt';
end
fileId = fopen(fullfile(batchFolder, fileName), 'w');
if fileId < 0, error('cw513:StatusWriteFailed', '无法写入批处理状态文件。'); end
cleanupObject = onCleanup(@() fclose(fileId)); %#ok<NASGU>
fprintf(fileId, 'DA766 scale hex batch status: %s\n', status);
fprintf(fileId, 'Channels discovered: %d\n', channelCount);
fprintf(fileId, 'Channel result summaries: %d\n', successCount);
fprintf(fileId, 'Channel errors: %d\n', errorCount);
fprintf(fileId, 'Formal status: 暂不能判定（需求/参考面未闭环）\n');
end

function result = runIsolation(config)
%RUNISOLATION Analyze DAC driven-to-victim channel isolation.
converter.runtime.validateConfig(config, ...
    {'deviceId', 'analysisId', 'version', 'dataFolder', 'outputFolder'});
pairs = localPairs(config);
fileNames = localFileNames(pairs);
runContext = converter.runtime.createRun(config, config.dataFolder, ...
    fileNames, config.outputFolder);
try
rows = repmat(localEmptyRow(), numel(pairs), 1);
for k = 1:numel(pairs)
    pair = pairs(k);
    drivePath = localPath(config.dataFolder, pair.driven_file);
    victimPath = localPath(config.dataFolder, pair.victim_file);
    drive = converter.io.loadPicoMat(drivePath, pair.driven_variable, ...
        config.hardwareGain, true);
    victim = converter.io.loadPicoMat(victimPath, pair.victim_variable, ...
        config.hardwareGain, true);
    driveFit = converter.dac.fitTone(drive.voltage, drive.sampleRateHz, pair.frequency_hz);
    victimFit = converter.dac.fitTone(victim.voltage, victim.sampleRateHz, pair.frequency_hz);
    isolation = 20 * log10(abs(driveFit.amplitudePeakV) / ...
        max(abs(victimFit.amplitudePeakV), realmin));
    rows(k).driven_file = string(pair.driven_file);
    rows(k).victim_file = string(pair.victim_file);
    rows(k).driven_label = string(pair.driven_label);
    rows(k).victim_label = string(pair.victim_label);
    rows(k).frequency_hz = pair.frequency_hz;
    rows(k).nominal_frequency_hz = localOptionalNumber(pair, ...
        'nominal_frequency_hz', pair.frequency_hz);
    rows(k).frequency_offset_hz = pair.frequency_hz - rows(k).nominal_frequency_hz;
    rows(k).driven_sample_rate_hz = drive.sampleRateHz;
    rows(k).victim_sample_rate_hz = victim.sampleRateHz;
    rows(k).driven_sample_count = drive.sampleCount;
    rows(k).victim_sample_count = victim.sampleCount;
    rows(k).driven_vpp_v = driveFit.vppV;
    rows(k).victim_vpp_v = victimFit.vppV;
    rows(k).driven_fit_r2 = driveFit.rSquared;
    rows(k).victim_fit_r2 = victimFit.rSquared;
    rows(k).driven_residual_rms_v = driveFit.residualRmsV;
    rows(k).victim_residual_rms_v = victimFit.residualRmsV;
    rows(k).isolation_db = isolation;
    driveFitReady = ~isfield(config, 'minimumFitR2') || ...
        (isfinite(driveFit.rSquared) && driveFit.rSquared >= config.minimumFitR2);
    rows(k).judgment = localLowerLimit(isolation, config.minimumIsolationDb, ...
        config.formalEnabled && driveFitReady);
    if driveFitReady, rows(k).fit_quality = "驱动拟合有效";
    else, rows(k).fit_quality = "驱动拟合不足，暂不能判定"; end
    rows(k).driven_sha256 = string(converter.runtime.sha256File(drivePath));
    rows(k).victim_sha256 = string(converter.runtime.sha256File(victimPath));
end
summary = struct2table(rows);
if isempty(rows)
    summary = table(string(config.deviceId), "未测试", ...
        'VariableNames', {'device','status'});
else
    valid = isfinite(summary.isolation_db);
    if any(valid), worst = min(summary.isolation_db(valid)); else, worst = NaN; end
    if isfield(config, 'minimumFitR2')
        fitReady = isfinite(summary.driven_fit_r2) & ...
            summary.driven_fit_r2 >= config.minimumFitR2;
    else
        fitReady = true(height(summary), 1);
    end
    overall = localLowerLimit(worst, config.minimumIsolationDb, ...
        config.formalEnabled && all(fitReady));
    summary.overall_status = repmat(string(overall), height(summary), 1);
end
converter.report.writeTable(summary, fullfile(runContext.folder, ...
    'dac_isolation_summary.csv'));
converter.report.writeTable(localParameters(config), fullfile(runContext.folder, ...
    'analysis_parameters.csv'));
if ~isempty(rows)
    isolationMatrix = localIsolationMatrix(summary);
    converter.report.writeTable(isolationMatrix.table, ...
        fullfile(runContext.folder, 'dac_isolation_matrix_db.csv'));
    figureHandle = localIsolationHeatmap(isolationMatrix, config);
    converter.report.saveFigure(figureHandle, fullfile(runContext.folder, ...
        'dac_isolation_summary'), 180); close(figureHandle);
else
    isolationMatrix = localEmptyIsolationMatrix();
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    axis off;
    text(0.05, 0.5, '未提供隔离度配对清单：暂不能判定', ...
        'FontSize', 14, 'Interpreter', 'none');
    converter.report.saveFigure(figureHandle, fullfile(runContext.folder, ...
        'dac_isolation_summary'), 180); close(figureHandle);
end
result = struct('config', config, 'summary', summary, ...
    'isolationMatrix', isolationMatrix, 'outputFolder', runContext.folder);
save(fullfile(runContext.folder, 'dac_isolation_result.mat'), 'result');
converter.runtime.finishRun(runContext, true, 'DA隔离度分析完成');
result = converter.runtime.refreshResultPaths(result, runContext.folder);
catch exception
    converter.runtime.finishRun(runContext, false, exception.message);
    rethrow(exception);
end
end

function pairs = localPairs(config)
if ~isfield(config, 'pairManifest') || isempty(config.pairManifest)
    pairs = struct([]); return;
end
source = config.pairManifest;
if ischar(source) || isstring(source)
    tableValue = readtable(char(source));
    pairs = table2struct(tableValue);
elseif istable(source)
    pairs = table2struct(source);
else
    pairs = source;
end
required = {'driven_file','victim_file','driven_variable','victim_variable', ...
    'frequency_hz','driven_label','victim_label'};
for k = 1:numel(required)
    if ~isfield(pairs, required{k}) && ~isempty(pairs)
        error('converter:dac:IsolationManifestMissing', ...
            '隔离度清单缺少字段：%s', required{k});
    end
end
end

function names = localFileNames(pairs)
names = {};
for k = 1:numel(pairs)
    names{end+1} = char(pairs(k).driven_file); %#ok<AGROW>
    names{end+1} = char(pairs(k).victim_file); %#ok<AGROW>
end
names = unique(names, 'stable');
end

function filePath = localPath(dataFolder, fileName)
filePath = converter.io.resolveInputPath(dataFolder, fileName);
end

function judgment = localLowerLimit(value, limit, enabled)
if ~enabled || ~isfinite(value)
    judgment = "暂不能判定";
elseif value > limit
    judgment = "满足";
else
    judgment = "不满足";
end
end

function row = localEmptyRow()
row = struct('driven_file', "", 'victim_file', "", 'driven_label', "", ...
    'victim_label', "", 'frequency_hz', NaN, 'nominal_frequency_hz', NaN, ...
    'frequency_offset_hz', NaN, 'driven_sample_rate_hz', NaN, ...
    'victim_sample_rate_hz', NaN, 'driven_sample_count', NaN, ...
    'victim_sample_count', NaN, 'driven_vpp_v', NaN, ...
    'victim_vpp_v', NaN, 'driven_fit_r2', NaN, 'victim_fit_r2', NaN, ...
    'driven_residual_rms_v', NaN, 'victim_residual_rms_v', NaN, ...
    'isolation_db', NaN, 'judgment', "", 'fit_quality', "", ...
    'driven_sha256', "", 'victim_sha256', "", 'overall_status', "");
end

function value = localOptionalNumber(source, fieldName, defaultValue)
if isfield(source, fieldName) && ~isempty(source.(fieldName))
    value = double(source.(fieldName));
else
    value = defaultValue;
end
if ~isscalar(value) || ~isfinite(value)
    value = defaultValue;
end
end

function tableValue = localParameters(config)
names = fieldnames(config); values = cell(numel(names), 1);
for k = 1:numel(names), values{k} = converter.runtime.valueToText(config.(names{k})); end
tableValue = table(string(names), string(values), ...
    'VariableNames', {'Parameter', 'Value'});
end

function matrix = localIsolationMatrix(summary)
drivenLabels = unique(string(summary.driven_label), 'stable');
victimLabels = unique(string(summary.victim_label), 'stable');
valuesDb = NaN(numel(drivenLabels), numel(victimLabels));
for k = 1:height(summary)
    drivenIndex = find(drivenLabels == string(summary.driven_label(k)), 1);
    victimIndex = find(victimLabels == string(summary.victim_label(k)), 1);
    if isempty(drivenIndex) || isempty(victimIndex)
        continue;
    end
    if isfinite(valuesDb(drivenIndex, victimIndex))
        error('converter:dac:IsolationMatrixDuplicate', ...
            '隔离度清单包含重复配对：%s -> %s。', ...
            drivenLabels(drivenIndex), victimLabels(victimIndex));
    end
    valuesDb(drivenIndex, victimIndex) = summary.isolation_db(k);
end
columnNames = [{'driven_label'}, cellstr("victim_" + victimLabels + ...
    "_isolation_db")'];
columnNames = matlab.lang.makeValidName(columnNames);
columnNames = matlab.lang.makeUniqueStrings(columnNames);
tableValue = table(drivenLabels, 'VariableNames', columnNames(1));
for k = 1:numel(victimLabels)
    tableValue.(columnNames{k + 1}) = valuesDb(:, k);
end
matrix = struct('drivenLabels', drivenLabels, 'victimLabels', victimLabels, ...
    'valuesDb', valuesDb, 'table', tableValue);
end

function matrix = localEmptyIsolationMatrix()
matrix = struct('drivenLabels', strings(0, 1), ...
    'victimLabels', strings(0, 1), 'valuesDb', zeros(0, 0), ...
    'table', table());
end

function figureHandle = localIsolationHeatmap(matrix, config)
rowCount = numel(matrix.drivenLabels);
columnCount = numel(matrix.victimLabels);
figureWidth = max(900, 220 + 150 * columnCount);
figureHeight = max(600, 230 + 110 * rowCount);
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [80, 80, figureWidth, figureHeight]);
axisHandle = axes('Parent', figureHandle, 'Position', [0.16, 0.18, 0.68, 0.70]);
finiteMask = isfinite(matrix.valuesDb);
if any(finiteMask(:))
    imageHandle = imagesc(axisHandle, matrix.valuesDb);
    set(imageHandle, 'AlphaData', double(finiteMask));
    finiteValues = matrix.valuesDb(finiteMask);
    colorLimits = localHeatmapColorLimits(finiteValues);
    set(axisHandle, 'CLim', colorLimits);
    colormap(axisHandle, parula(256));
    colorbarHandle = colorbar(axisHandle);
    ylabel(colorbarHandle, '隔离度 (dB)');
    for rowIndex = 1:rowCount
        for columnIndex = 1:columnCount
            if ~finiteMask(rowIndex, columnIndex)
                continue;
            end
            value = matrix.valuesDb(rowIndex, columnIndex);
            normalized = (value - colorLimits(1)) / ...
                max(colorLimits(2) - colorLimits(1), realmin);
            if normalized > 0.58
                textColor = [0.05, 0.05, 0.05];
            else
                textColor = [1, 1, 1];
            end
            text(axisHandle, columnIndex, rowIndex, sprintf('%.2f', value), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontSize', 11, 'FontWeight', 'bold', 'Color', textColor);
        end
    end
else
    axis(axisHandle, [0.5, max(columnCount, 1) + 0.5, ...
        0.5, max(rowCount, 1) + 0.5]);
    text(axisHandle, 1, 1, '没有有限的隔离度 dB 数值', ...
        'HorizontalAlignment', 'center', 'Color', [0.2, 0.2, 0.2]);
end
set(axisHandle, 'XTick', 1:columnCount, ...
    'XTickLabel', cellstr(matrix.victimLabels), 'YTick', 1:rowCount, ...
    'YTickLabel', cellstr(matrix.drivenLabels), 'YDir', 'reverse', ...
    'Layer', 'top', 'FontSize', 10, 'Color', [0.94, 0.94, 0.94]);
xlabel(axisHandle, '受扰接口');
ylabel(axisHandle, '驱动接口');
title(axisHandle, sprintf('%s DAC隔离度矩阵（dB）', config.deviceId), ...
    'Interpreter', 'none');
grid(axisHandle, 'on');
set(axisHandle, 'GridColor', [1, 1, 1], 'GridAlpha', 0.85, ...
    'XLim', [0.5, columnCount + 0.5], 'YLim', [0.5, rowCount + 0.5]);
if isfield(config, 'minimumIsolationDb') && ...
        isfinite(config.minimumIsolationDb)
    annotation(figureHandle, 'textbox', [0.16, 0.04, 0.68, 0.06], ...
        'String', sprintf('参考阈值 %.4g dB；正式状态由配置决定', ...
        config.minimumIsolationDb), 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'Color', [0.25, 0.25, 0.25]);
end
end

function colorLimits = localHeatmapColorLimits(values)
lower = min(values);
upper = max(values);
span = upper - lower;
if span <= 0 || ~isfinite(span)
    padding = max(1, 0.02 * max(abs(lower), 1));
else
    padding = max(0.5, 0.05 * span);
end
colorLimits = [lower - padding, upper + padding];
end

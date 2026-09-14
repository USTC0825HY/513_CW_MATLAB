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
    rows(k).driven_vpp_v = driveFit.vppV;
    rows(k).victim_vpp_v = victimFit.vppV;
    rows(k).isolation_db = isolation;
    rows(k).judgment = localLowerLimit(isolation, config.minimumIsolationDb, ...
        config.formalEnabled);
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
    overall = localLowerLimit(worst, config.minimumIsolationDb, config.formalEnabled);
    summary.overall_status = repmat(string(overall), height(summary), 1);
end
converter.report.writeTable(summary, fullfile(runContext.folder, ...
    'dac_isolation_summary.csv'));
converter.report.writeTable(localParameters(config), fullfile(runContext.folder, ...
    'analysis_parameters.csv'));
if ~isempty(rows)
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    labels = cellstr(summary.driven_label + " -> " + summary.victim_label);
    bar(categorical(labels), summary.isolation_db); grid on;
    plot(xlim, [1 1] * config.minimumIsolationDb, 'r--', ...
        'DisplayName', sprintf('%.4g dB limit', config.minimumIsolationDb));
    ylabel('Isolation (dB)'); title(sprintf('%s DAC isolation', config.deviceId), ...
        'Interpreter', 'none');
    converter.report.saveFigure(figureHandle, fullfile(runContext.folder, ...
        'dac_isolation_summary'), 180); close(figureHandle);
else
    figureHandle = figure('Visible', 'off', 'Color', 'w');
    axis off;
    text(0.05, 0.5, '未提供隔离度配对清单：暂不能判定', ...
        'FontSize', 14, 'Interpreter', 'none');
    converter.report.saveFigure(figureHandle, fullfile(runContext.folder, ...
        'dac_isolation_summary'), 180); close(figureHandle);
end
result = struct('config', config, 'summary', summary, ...
    'outputFolder', runContext.folder);
save(fullfile(runContext.folder, 'dac_isolation_result.mat'), 'result');
converter.runtime.finishRun(runContext, true, 'DA隔离度分析完成');
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
if ~enabled || ~isfinite(value), judgment = "暂不能判定";
elseif value > limit, judgment = "满足";
else, judgment = "不满足"; end
end

function row = localEmptyRow()
row = struct('driven_file', "", 'victim_file', "", 'driven_label', "", ...
    'victim_label', "", 'frequency_hz', NaN, 'driven_vpp_v', NaN, ...
    'victim_vpp_v', NaN, 'isolation_db', NaN, 'judgment', "", ...
    'driven_sha256', "", 'victim_sha256', "", 'overall_status', "");
end

function tableValue = localParameters(config)
names = fieldnames(config); values = cell(numel(names), 1);
for k = 1:numel(names), values{k} = converter.runtime.valueToText(config.(names{k})); end
tableValue = table(string(names), string(values), ...
    'VariableNames', {'Parameter', 'Value'});
end

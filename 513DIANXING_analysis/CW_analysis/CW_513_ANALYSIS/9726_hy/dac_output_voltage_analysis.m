function results = dac_output_voltage_analysis(dataFolder, selectedFiles, outputFolder, options)
%DAC_OUTPUT_VOLTAGE_ANALYSIS DC output voltage range and code-to-voltage scale.
%   R = DAC_OUTPUT_VOLTAGE_ANALYSIS() opens a file dialog for point-mode DC
%   step captures (each DAC code held ~0.5 s, returning to code 0000 between
%   steps).  (DATAFOLDER, FILES) analyses the listed MATs without a dialog.
%   Each capture holds one waveform per A/B/C/D channel; the JG labels in
%   the file name map to the present variables in order (same convention as
%   split_dac_isolation_channels).
%
%   Per channel the entry segments the record into DC plateaus, assigns each
%   plateau to its code, and produces:
%     * output voltage range: peak (+FS code), valley (-FS code) and Vpp;
%     * DC scale fit V = k*code + b over the swept signed codes with R2.
%   OPTIONS (all optional):
%     codeListHex   cellstr of swept codes, default {'8000','9FFF','BFFF',
%                   'DFFF','0000','1FFF','3FFF','5FFF','7FFF'} (signed 16-bit:
%                   -FS in quarter steps to 0, then to +FS)
%     edgeThreshold step detection threshold in V, default 0.25
%     minHoldS      minimum plateau duration in s, default 0.05
%     levelTolV     plateau clustering tolerance in V, default 0.02
%     channelLabels cellstr override for the JG labels (else file-name order)

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2 || isempty(selectedFiles), selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4 || isempty(options), options = struct(); end
options = localDefaults(options);

[selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, ...
    selectedFiles, '选择点模式直流扫码MAT（可多选）');
if isempty(selectedFiles)
    results = struct([]);
    return;
end
if isempty(outputFolder), outputFolder = fullfile(dataFolder, 'results'); end
if ~isfolder(outputFolder), mkdir(outputFolder); end
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
runFolder = fullfile(outputFolder, ['run_' stamp '_output_voltage']);
mkdir(runFolder);

allRows = {};
channelResults = [];
for f = 1:numel(selectedFiles)
    srcPath = converter.io.resolveInputPath(dataFolder, selectedFiles{f});
    src = load(srcPath);
    [~, name] = fileparts(srcPath);
    present = {'A', 'B', 'C', 'D'};
    present = present(cellfun(@(v) isfield(src, v), present));
    labels = localLabels(name, present, options.channelLabels);
    fs = 1 / double(src.Tinterval);
    fprintf('%s：%d 路，fs=%.6g Hz，%d 点/路\n', name, numel(present), ...
        fs, numel(src.(present{1})));
    for v = 1:numel(present)
        w = double(src.(present{v})(:));
        r = localAnalyseChannel(w, fs, options);
        r.channel = labels{v};
        r.sourceFile = srcPath;
        if isempty(channelResults)
            channelResults = r;
        else
            channelResults(end+1, 1) = r; %#ok<AGROW>
        end
        localPrintChannel(r);
        allRows{end+1} = localChannelRows(r); %#ok<AGROW>
    end
end

% per-code measurement CSV (every channel x every code)
codeTable = vertcat(allRows{:});
converter.report.writeTable(codeTable, fullfile(runFolder, ...
    'output_voltage_codes.csv'));

% per-channel summary CSV + fitted line figure
summaryRows = repmat(localEmptySummary(), numel(channelResults), 1);
for k = 1:numel(channelResults)
    r = channelResults(k);
    summaryRows(k) = localSummaryRow(r);
    f = localChannelFigure(r);
    converter.report.saveFigure(f, fullfile(runFolder, ...
        ['DA9726_dc_scale_' r.channel]), 180);
    close(f);
end
converter.report.writeTable(struct2table(summaryRows), fullfile(runFolder, ...
    'output_voltage_summary.csv'));

results = struct('channelResults', channelResults, ...
    'codeTable', codeTable, 'outputFolder', runFolder);
fprintf('输出电压范围/直流刻度分析完成：%s\n', runFolder);
end

% -----------------------------------------------------------------------
function r = localAnalyseChannel(w, fs, options)
smoothed = movmedian(w, 201);
edges = find(abs(diff(smoothed)) > options.edgeThreshold);
bounds = [1; edges(:); numel(w)];
keep = diff(bounds) >= round(options.minHoldS * fs);
bounds = [bounds(keep); numel(w) + 1];
plateauStart = bounds(1:end-1);
plateauStop = bounds(2:end) - 1;
medianV = arrayfun(@(a, b) median(smoothed(a:b)), ...
    plateauStart, plateauStop);

% cluster plateau levels, longest member names the level
[medianV, order] = sort(medianV);
plateauStart = plateauStart(order);
plateauStop = plateauStop(order);
levelId = zeros(size(medianV));
levelCount = 0;
for k = 1:numel(medianV)
    if levelCount == 0 || medianV(k) - levels(levelCount) > options.levelTolV
        levelCount = levelCount + 1;
        levels(levelCount) = medianV(k); %#ok<AGROW>
    end
    levelId(k) = levelCount;
end

codes = localSignedCodes(options.codeListHex);
if levelCount ~= numel(codes)
    error('dac:voltage:LevelCountMismatch', ...
        ['检测到%d个直流电平，与%d个扫码不配：%s。' ...
        '请检查edgeThreshold/minHoldS或扫码序列。'], levelCount, ...
        numel(codes), strjoin(string(compose('%.4f', levels)), ', '));
end
levelCodes = codes;  % both ascending: monotonic DC transfer pairing

% per-code median over every sample of its member plateaus
measuredV = NaN(numel(codes), 1);
holdS = NaN(numel(codes), 1);
repeatCount = zeros(numel(codes), 1);
for c = 1:numel(codes)
    members = find(levelId == c);
    samples = [];
    for mIdx = members(:).'
        samples = [samples; smoothed(plateauStart(mIdx):plateauStop(mIdx))]; %#ok<AGROW>
    end
    measuredV(c) = median(samples);
    holdS(c) = sum(plateauStop(members) - plateauStart(members) + 1) / fs;
    repeatCount(c) = numel(members);
end

coefficient = polyfit(levelCodes, measuredV, 1);
fitted = polyval(coefficient, levelCodes);
residual = measuredV - fitted;
r2 = localR2(measuredV, residual);

r.fs = fs;
r.codes = levelCodes;
r.codeHex = options.codeListHex;
r.measuredV = measuredV;
r.holdS = holdS;
r.repeatCount = repeatCount;
r.slopeVPerCode = coefficient(1);
r.interceptV = coefficient(2);
r.fitR2 = r2;
r.peakV = measuredV(end);      % +FS code (7FFF)
r.valleyV = measuredV(1);      % -FS code (8000)
r.vppV = r.peakV - r.valleyV;
r.levelCount = levelCount;
end

function rows = localChannelRows(r)
n = numel(r.codes);
rows = table(string(repmat(r.channel, n, 1)), ...
    string(strrep(r.codeHex(:), ' ', '')), r.codes(:), ...
    r.measuredV(:), r.holdS(:), r.repeatCount(:), ...
    repmat(r.peakV, n, 1), repmat(r.valleyV, n, 1), ...
    repmat(r.vppV, n, 1), repmat(r.slopeVPerCode, n, 1), ...
    repmat(r.interceptV, n, 1), repmat(r.fitR2, n, 1), ...
    string(repmat(r.sourceFile, n, 1)), ...
    'VariableNames', {'channel', 'code_hex', 'code_signed', ...
    'measured_v', 'hold_s', 'plateau_count', 'peak_v', 'valley_v', ...
    'vpp_v', 'slope_v_per_code', 'intercept_v', 'fit_r_squared', ...
    'source_file'});
end

function s = localEmptySummary()
s = struct('channel', "", 'peak_v', NaN, 'valley_v', NaN, 'vpp_v', NaN, ...
    'slope_v_per_code', NaN, 'slope_uv_per_code', NaN, ...
    'intercept_v', NaN, 'fit_r_squared', NaN, 'fs_hz', NaN, ...
    'levels_found', NaN, 'requirement_3v', "");
end

function s = localSummaryRow(r)
s = localEmptySummary();
s.channel = string(r.channel);
s.peak_v = r.peakV;
s.valley_v = r.valleyV;
s.vpp_v = r.vppV;
s.slope_v_per_code = r.slopeVPerCode;
s.slope_uv_per_code = r.slopeVPerCode * 1e6;
s.intercept_v = r.interceptV;
s.fit_r_squared = r.fitR2;
s.fs_hz = r.fs;
s.levels_found = r.levelCount;
s.requirement_3v = string(localRequirementText(r.peakV, r.valleyV));
end

function text = localRequirementText(peakV, valleyV)
limit = 3;
if abs(peakV) <= limit && abs(valleyV) <= limit
    text = '在±3 V内';
else
    text = sprintf('超出±3 V（+%0.3f/-%0.3f）', peakV, abs(valleyV));
end
end

function f = localChannelFigure(r)
f = figure('Visible', 'off', 'Color', 'w');
plot(r.codes, r.measuredV * 1e3, 'ko', 'MarkerFaceColor', [0.1 0.4 0.8]);
grid on; hold on;
x = linspace(min(r.codes), max(r.codes), 100);
plot(x, (r.slopeVPerCode * x + r.interceptV) * 1e3, 'r-', 'LineWidth', 1.2);
for k = 1:numel(r.codes)
    text(r.codes(k), r.measuredV(k) * 1e3 + 40, ...
        sprintf('%s\n%.3f V', r.codeHex{k}, r.measuredV(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 8);
end
xlabel('DAC code (signed)');
ylabel('DC output (mV)');
title(sprintf('DA9726 %s：V = %.4f×10^{-6}×code %+.4f V，R^2 = %.6f', ...
    r.channel, r.slopeVPerCode * 1e6, r.interceptV, r.fitR2), ...
    'Interpreter', 'tex');
legend('测量点', '线性拟合', 'Location', 'southeast');
localLightTheme(f);
end

function localLightTheme(f)
%LOCALLIGHTTHEME Same light-theme normalisation as converter.report.saveFigure
%   (that helper is file-local there and cannot be called directly).
set(f, 'Color', 'w');
if isprop(f, 'InvertHardcopy'), set(f, 'InvertHardcopy', 'off'); end
axesHandles = findall(f, 'Type', 'axes');
for k = 1:numel(axesHandles)
    ax = axesHandles(k);
    if isprop(ax, 'Color'), set(ax, 'Color', 'w'); end
    if isprop(ax, 'XColor'), set(ax, 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k'); end
    if isprop(ax, 'GridColor'), set(ax, 'GridColor', [0.70 0.70 0.70]); end
    if isprop(ax, 'MinorGridColor'), set(ax, 'MinorGridColor', [0.82 0.82 0.82]); end
    if isprop(ax, 'XLabel')
        set(ax.XLabel, 'Color', 'k');
        set(ax.YLabel, 'Color', 'k');
        set(ax.ZLabel, 'Color', 'k');
        set(ax.Title, 'Color', 'k');
    end
end
legendHandles = findall(f, 'Type', 'legend');
for k = 1:numel(legendHandles)
    lg = legendHandles(k);
    if isprop(lg, 'Color'), set(lg, 'Color', 'w'); end
    if isprop(lg, 'TextColor'), set(lg, 'TextColor', 'k'); end
    if isprop(lg, 'EdgeColor'), set(lg, 'EdgeColor', [0.25 0.25 0.25]); end
end
end

function r = localPrintChannel(r)
fprintf(['  %s：波峰(%s)=%+.4f V，波谷(%s)=%+.4f V，Vpp=%.4f V；' ...
    '直流刻度 k=%.4f µV/code，b=%+.4f mV，R²=%.6f\n'], ...
    r.channel, r.codeHex{end}, r.peakV, r.codeHex{1}, r.valleyV, ...
    r.vppV, r.slopeVPerCode * 1e6, r.interceptV * 1e3, r.fitR2);
end

function labels = localLabels(name, presentVariables, explicit)
if ~isempty(explicit)
    labels = cellstr(explicit);
    assert(numel(labels) == numel(presentVariables));
    return;
end
labels = regexp(name, '(?i)JG\d+', 'match');
labels = cellfun(@upper, labels, 'UniformOutput', false);
if numel(labels) ~= numel(presentVariables)
    error('dac:voltage:ChannelMapAmbiguous', ...
        '文件名JG标签数与A/B/C/D波形数不一致：%s', name);
end
end

function codes = localSignedCodes(codeListHex)
raw = cellfun(@hex2dec, cellstr(codeListHex));
codes = raw - 65536 .* (raw >= 32768);
codes = codes(:);
if ~issorted(codes)
    error('dac:voltage:CodeOrder', '扫码序列须按有符号值升序给出。');
end
end

function value = localR2(observed, residual)
centered = observed - mean(observed);
total = sum(centered.^2);
if total == 0, value = NaN; else, value = 1 - sum(residual.^2) / total; end
end

function o = localDefaults(o)
if ~isfield(o, 'codeListHex') || isempty(o.codeListHex)
    o.codeListHex = {'8000', '9FFF', 'BFFF', 'DFFF', '0000', ...
        '1FFF', '3FFF', '5FFF', '7FFF'};
end
if ~isfield(o, 'edgeThreshold') || isempty(o.edgeThreshold)
    o.edgeThreshold = 0.25;
end
if ~isfield(o, 'minHoldS') || isempty(o.minHoldS)
    o.minHoldS = 0.05;
end
if ~isfield(o, 'levelTolV') || isempty(o.levelTolV)
    o.levelTolV = 0.02;
end
if ~isfield(o, 'channelLabels') || isempty(o.channelLabels)
    o.channelLabels = {};
end
end

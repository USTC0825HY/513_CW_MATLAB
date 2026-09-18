function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_BANDWIDTH_ANALYSIS Analyze AD677 input-frequency response.
%   R = ADC_BANDWIDTH_ANALYSIS() opens a multi-select dialog for the sweep
%   CSVs of one AD677 channel. R = ADC_BANDWIDTH_ANALYSIS(DATAFOLDER)
%   auto-scans *.csv in DATAFOLDER; (DATAFOLDER, FILES) analyses the listed
%   files. Both batch forms are fully non-interactive.
%   The ILA captures at 100 MHz but adc_data only updates on the
%   adc_data_vld strobe (column 5, every 1200 ILA cycles on the 20260917
%   captures = 83.333 kS/s). Held rows are dropped and the effective sample
%   rate is derived from the measured strobe spacing. Records spanning
%   fewer than config.minimumRecordCycles input cycles are dropped: a
%   partial-arc sine fit returns a wrong CodePp with an excellent R2
%   (the 100 Hz capture holds only 0.13 cycles). Results default to a
%   "results" folder next to the data folder (same level, not inside it).
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2 || isempty(selectedFiles), selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, ~] = converter.runtime.applyRunOptions( ...
    ad677Config('bandwidth'), runOptions);
if isempty(dataFolder) && isempty(selectedFiles)
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, '选择同一AD677通道的扫频CSV（可多选）');
    if isempty(selectedFiles), results = table; return; end
elseif isempty(selectedFiles)
    selectedFiles = listChannelCsv(dataFolder);
else
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, []);
end
if isempty(selectedFiles)
    error('ad677:NoCsvFiles', '数据目录中没有CSV文件：%s', dataFolder);
end
frequencies = cellfun(@converter.io.parseFrequencyHz, selectedFiles);
if any(~isfinite(frequencies) | frequencies <= 0)
    error('ad677:FrequencyMissing', '文件名须含Hz/kHz/MHz注入频率。');
end
if isempty(outputFolder)
    % By decision the run folder is written next to the data folder, never
    % inside the capture directory and not beside its "raw" parent.
    outputFolder = fullfile(fileparts(dataFolder), 'results');
end
validateattributes(config.ilaClockHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'ilaClockHz');
strobeInfo = readStrobeInfo(dataFolder, selectedFiles, config);
validSampleCounts = strobeInfo.validSampleCounts;
if isfinite(config.sampleRate)
    effectiveSampleRate = config.sampleRate;
    fprintf('使用配置覆盖的采样率：%.9g Hz（未从vld选通重新推导）。\n', ...
        effectiveSampleRate);
else
    effectiveSampleRate = config.ilaClockHz / strobeInfo.strobePeriod;
    fprintf(['ILA记录时钟 %.9g Hz，adc_data_vld 每 %d 个ILA周期选通一次，' ...
        '有效数据率 %.9g Hz（%.6g kS/s），每文件约 %d 个有效样本。\n'], ...
        config.ilaClockHz, strobeInfo.strobePeriod, effectiveSampleRate, ...
        effectiveSampleRate / 1e3, max(validSampleCounts));
end
% A record needs enough input cycles for a phase-robust amplitude fit.
frequencyColumn = frequencies(:);
recordCycles = frequencyColumn .* validSampleCounts / effectiveSampleRate;
cycleLimit = 2;
if isfield(config, 'minimumRecordCycles') && ...
        ~isempty(config.minimumRecordCycles)
    cycleLimit = config.minimumRecordCycles;
end
keepFile = recordCycles >= cycleLimit;
dropIndex = find(~keepFile);
for t = 1:numel(dropIndex)
    k = dropIndex(t);
    fprintf(['剔除：%s 注入频率 %.9g Hz，有效样本 %d 个仅在记录内覆盖 %.2f 个周期' ...
        '（< %g），部分弧段拟合的幅值依赖相位不可靠。\n'], ...
        selectedFiles{k}, frequencyColumn(k), validSampleCounts(k), ...
        recordCycles(k), cycleLimit);
end
nyquistHz = effectiveSampleRate / 2;
exactNyquist = abs(frequencyColumn - nyquistHz) <= effectiveSampleRate * 1e-9;
nyquistIndex = find(exactNyquist);
for t = 1:numel(nyquistIndex)
    k = nyquistIndex(t);
    fprintf(['剔除：%s 注入频率 %.9g Hz 恰在有效奈奎斯特点，采样退化为交替码，' ...
        '幅值不可测。\n'], selectedFiles{k}, frequencyColumn(k));
end
aboveNyquist = frequencyColumn > nyquistHz & ~exactNyquist;
aliasIndex = find(aboveNyquist);
for t = 1:numel(aliasIndex)
    k = aliasIndex(t);
    fprintf(['提示：%s 注入频率 %.9g Hz 超过有效奈奎斯特 %.9g Hz：' ...
        '按文件名频率拟合仍得到真实CodePp，但不参与-3dB带宽计算。\n'], ...
        selectedFiles{k}, frequencyColumn(k), nyquistHz);
end
keepMask = keepFile & ~exactNyquist;                % N-by-1 logical column
selectedFiles = selectedFiles(keepMask.');          % keep the row-cell shape
frequencies = frequencies(keepMask.');
if isempty(selectedFiles)
    error('ad677:AllFilesUnmeasurable', ...
        '剔除周期不足与奈奎斯特点后没有可分析文件。');
end
if numel(unique(frequencies)) ~= numel(frequencies)
    error('ad677:DuplicateFrequency', '请每个频率选择一份CSV，不要混选重复记录。');
end
validateattributes(effectiveSampleRate, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'sampleRate');
% Validate format and coverage before the shared workflow creates outputs.
for k = 1:numel(selectedFiles)
    path = converter.io.resolveInputPath(dataFolder, selectedFiles{k});
    code = converter.io.readAdcCsv(path, config);
    if any(code < -32768 | code > 32767 | code ~= fix(code))
        error('ad677:CodeRange', ...
            'CSV必须包含16 bit有符号整数码（-32768～32767）：%s', path);
    end
end
config.sampleRate = effectiveSampleRate;
results = converter.adc.runBandwidth(config, dataFolder, ...
    selectedFiles, outputFolder);
end

function files = listChannelCsv(dataFolder)
%LISTCHANNELCSV Auto-scan the channel folder; no dialog is ever opened.
listing = dir(fullfile(char(dataFolder), '*.csv'));
files = {listing.name};
if isempty(files)
    return;
end
[~, order] = sort(cellfun(@converter.io.parseFrequencyHz, files));
files = files(order);
end

function strobeInfo = readStrobeInfo(dataFolder, selectedFiles, config)
%READSTROBEINFO Measure the vld strobe period and valid-sample count.
fileCount = numel(selectedFiles);
strobeInfo = struct('strobePeriod', NaN, ...
    'validSampleCounts', NaN(fileCount, 1));
strobePeriod = NaN(fileCount, 1);
for k = 1:fileCount
    path = converter.io.resolveInputPath(dataFolder, selectedFiles{k});
    vld = readValidColumn(path, config.validDataColumn);
    risingEdge = find(vld(2:end) == 1 & vld(1:end - 1) == 0) + 1;
    strobeInfo.validSampleCounts(k) = sum(vld == 1);
    if numel(risingEdge) < 2
        error('ad677:StrobeNotFound', ...
            'vld列缺少足够的选通脉冲，无法推导数据率：%s', path);
    end
    edgeSpacing = diff(risingEdge);
    if min(edgeSpacing) ~= max(edgeSpacing)
        error('ad677:NonUniformStrobe', ...
            'vld选通间隔不均匀（%d～%d），直接抽取会破坏均匀采样假设：%s', ...
            min(edgeSpacing), max(edgeSpacing), path);
    end
    strobePeriod(k) = edgeSpacing(1);
end
if any(strobePeriod ~= strobePeriod(1))
    error('ad677:StrobePeriodMismatch', ...
        '各文件的vld选通周期不一致，请确认来自同一次采集配置。');
end
strobeInfo.strobePeriod = strobePeriod(1);
end

function vld = readValidColumn(path, validColumn)
%READVALIDCOLUMN Read the strobe column, skipping the single ILA header row.
numericTail = dlmread(char(path), ',', 1, validColumn - 1); %#ok<DLMRD>
vld = numericTail(:, 1);
vld = vld(isfinite(vld));
end

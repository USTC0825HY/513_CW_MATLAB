function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_BANDWIDTH_ANALYSIS Fit ADC128 ILA CSV sweeps and find the -3 dB bandwidth.
%   R = ADC_BANDWIDTH_ANALYSIS() opens a multi-select file dialog for the
%   sweep CSVs of one ADC128 channel. R = ADC_BANDWIDTH_ANALYSIS(DATAFOLDER)
%   auto-scans *.csv in DATAFOLDER instead, and (DATAFOLDER, FILES) analyses
%   the listed files; both forms are fully non-interactive.
%   All capture settings are fixed in private/adc128Config.m: ILA record
%   clock 50 MHz, ADC code in column 5, data_128_vld strobe in column 4.
%   The effective sample rate is derived from the strobe spacing
%   (50 MHz / 500 = 100 kS/s on the 20260917 captures); rows between
%   strobes are held codes and are excluded. Files above the effective
%   Nyquist stay in the run and are fitted at the filename frequency,
%   which recovers the true CodePp (the alias of a sine is an exact sine
%   image) while the shared frequency check keeps them out of the -3 dB
%   math. A file exactly at the Nyquist frequency is dropped: its samples
%   degenerate into an alternating code whose fitted amplitude is
%   phase-dependent and numerically singular.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2 || isempty(selectedFiles), selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, ~] = converter.runtime.applyRunOptions(adc128Config(), runOptions);
if config.adcBits ~= 12 || ~strcmpi(config.adcCodeFormat, 'unsigned')
    error('adc128:CodeFormat', '本入口要求12 bit unsigned码，范围0～4095。');
end
if isempty(dataFolder) && isempty(selectedFiles)
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, '选择同一ADC128通道的扫频CSV（可多选）');
    if isempty(selectedFiles), results = table; return; end
elseif isempty(selectedFiles)
    selectedFiles = listChannelCsv(dataFolder);
else
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, []);
end
if isempty(selectedFiles)
    error('adc128:NoCsvFiles', '数据目录中没有CSV文件：%s', dataFolder);
end
frequencies = cellfun(@converter.io.parseFrequencyHz, selectedFiles);
if any(~isfinite(frequencies) | frequencies <= 0)
    error('adc128:FrequencyMissing', '文件名须含Hz/kHz/MHz注入频率，如600Hz、1kHz。');
end
validateattributes(config.ilaClockHz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'ilaClockHz');
if isfinite(config.sampleRate)
    effectiveSampleRate = config.sampleRate;
    fprintf('使用配置覆盖的采样率：%.9g Hz。\n', ...
        effectiveSampleRate);
else
    effectiveSampleRate = deriveStrobeSampleRate(dataFolder, selectedFiles, config);
end
nyquistHz = effectiveSampleRate / 2;
aboveNyquist = frequencies > nyquistHz;
exactNyquist = abs(frequencies - nyquistHz) <= effectiveSampleRate * 1e-9;
for k = find(aboveNyquist(:).')
    fprintf(['提示：%s 注入频率 %.9g Hz 超过有效奈奎斯特 %.9g Hz：' ...
        '按文件名频率拟合仍得到真实CodePp（混叠像是严格正弦，幅值不失真），' ...
        '该点不参与-3dB带宽计算。\n'], ...
        selectedFiles{k}, frequencies(k), nyquistHz);
end
for k = find(exactNyquist(:).')
    fprintf(['剔除：%s 注入频率 %.9g Hz 恰在有效奈奎斯特点，采样退化为交替码，' ...
        '幅值依赖触发相位且正弦拟合数值。\n'], ...
        selectedFiles{k}, frequencies(k));
end
selectedFiles = selectedFiles(~exactNyquist);
frequencies = frequencies(~exactNyquist);
if isempty(selectedFiles)
    error('adc128:AllFilesUnmeasurable', ...
        '全部文件频率恰在有效奈奎斯特点，无可分析数据。');
end
if numel(unique(frequencies)) ~= numel(frequencies)
    error('adc128:DuplicateFrequency', '请每个频率选择一份CSV，不要混选多个通道或重复记录。');
end
validateattributes(effectiveSampleRate, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'sampleRate');
% Channel-dependent source-impedance de-embedding (see adc128Config):
% X11-* inputs see the generator 50 ohm output impedance in series with the
% board 33 ohm resistor, so their bandwidth is de-embedded by (33+50)/33;
% X10 (OP27 buffer drive) keeps factor 1.
scaleFactor = 1;
scaleReason = '默认：无源阻抗去嵌（系数=1）';
if isfield(config, 'bandwidthScaleRules')
    for ruleIndex = 1:numel(config.bandwidthScaleRules)
        rule = config.bandwidthScaleRules{ruleIndex};
        pattern = rule{1};
        hit = cellfun(@(f) ~isempty(strfind(lower(char(f)), ...
            lower(pattern))), selectedFiles);
        if any(hit)
            assert(all(hit), ...
                'adc128:MixedChannelRules', ...
                '所选文件部分匹配 %s，请勿在同一次运行中混合不同输入链路的通道。', pattern);
            scaleFactor = rule{2};
            scaleReason = sprintf(['文件名匹配 %s：源内阻%.0fΩ与板级%.0fΩ串联，' ...
                '带宽×%.4f 去嵌到板级R=%.0fΩ'], pattern, config.sourceROhm, ...
                config.boardSeriesROhm, scaleFactor, config.boardSeriesROhm);
            break;
        end
    end
end
fprintf('带宽源阻抗修正：%s\n', scaleReason);
config.bandwidthScaleFactor = scaleFactor;
config.bandwidthScaleReason = scaleReason;
% Validate format and coverage before the shared workflow creates outputs.
for k = 1:numel(selectedFiles)
    path = converter.io.resolveInputPath(dataFolder, selectedFiles{k});
    code = converter.io.readAdcCsv(path, config);
    if any(code < -2048 | code > 2047 | code ~= fix(code))
        error('adc128:CodeRange', 'CSV必须包含0～4095的整数原始码：%s', path);
    end
end
config.sampleRate = effectiveSampleRate;
results = converter.adc.runBandwidth(config, dataFolder, selectedFiles, outputFolder);
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

function sampleRate = deriveStrobeSampleRate(dataFolder, selectedFiles, config)
%DERIVESTROBESAMPLERATE Derive the uniform data rate from the vld strobe.
strobePeriod = NaN(numel(selectedFiles), 1);
for k = 1:numel(selectedFiles)
    path = converter.io.resolveInputPath(dataFolder, selectedFiles{k});
    vld = readValidColumn(path, config.validDataColumn);
    risingEdge = find(vld(2:end) == 1 & vld(1:end - 1) == 0) + 1;
    if numel(risingEdge) < 2
        error('adc128:StrobeNotFound', ...
            'vld列缺少足够的选通脉冲，无法推导数据率：%s', path);
    end
    edgeSpacing = diff(risingEdge);
    if min(edgeSpacing) ~= max(edgeSpacing)
        error('adc128:NonUniformStrobe', ...
            'vld选通间隔不均匀（%d～%d），直接抽取会破坏均匀采样假设：%s', ...
            min(edgeSpacing), max(edgeSpacing), path);
    end
    strobePeriod(k) = edgeSpacing(1);
end
if any(strobePeriod ~= strobePeriod(1))
    error('adc128:StrobePeriodMismatch', ...
        '各文件的vld选通周期不一致，请确认来自同一次采集配置。');
end
sampleRate = config.ilaClockHz / strobePeriod(1);
fprintf(['ILA记录时钟 %.9g Hz，data_128_vld 每 %d 个ILA周期选通一次，' ...
    '有效数据率 %.9g Hz（%.6g kS/s）。\n'], config.ilaClockHz, ...
    strobePeriod(1), sampleRate, sampleRate / 1e3);
end

function vld = readValidColumn(path, validColumn)
%READVALIDCOLUMN Read the strobe column, skipping the single ILA header row.
numericTail = dlmread(char(path), ',', 1, validColumn - 1); %#ok<DLMRD>
vld = numericTail(:, 1);
vld = vld(isfinite(vld));
end

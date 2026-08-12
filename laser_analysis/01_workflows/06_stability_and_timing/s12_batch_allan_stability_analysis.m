function output = s12_batch_allan_stability_analysis(filePaths, outputFolder)
%s12_batch_allan_stability_analysis - 批量计算频率稳定度
%   OUTPUT = s12_batch_allan_stability_analysis() 打开文件选择框，
%   批量读取频率计 CSV/TXT，并计算 ADEV、MDEV 和目标 tau 稳定度。
%
%   OUTPUT = s12_batch_allan_stability_analysis(filePaths) 处理指定文件。
%   filePaths 可以是字符向量、string 或由完整路径组成的 cell 数组。
%
%   OUTPUT = s12_batch_allan_stability_analysis(filePaths,outputFolder)
%   还指定结果目录；留空时在第一个输入文件旁创建时间戳目录。
%
%   输入频率列统一换算为 Hz。cfg.centerFreq_Hz 是分数频率归一化
%   分母：报告 RF 信号自身稳定度时填 RF 中心频率；报告光学等效
%   稳定度时填 c/lambda。选择错误不会报错，但会按比例改变结果。
%
%   cfg.defaultTau0_s 表示相邻记录间隔，不等同于仪器 gate time。
%   数据包含时间列时可由时间戳估计 tau0；无时间列时必须手动确认。
%   tau=m*tau0，目标 1 s 在 0.1 s 采样下对应 m=10。
%
%   removeLinearDrift 为 true 时同时保留 Raw 和 Detrended 曲线。
%   去漂会改变长 tau 结果，正式报告应说明所用口径。异常点处理不会
%   删除样本后拼接时间轴，而是排除包含异常点的 ADEV/MDEV 窗口。
%
%   默认使用脚本内置重叠 ADEV 和 MDEV。useBuiltinAllanvar 为 true
%   且 ALLANVAR 可用时优先调用工具箱函数；失败后自动回退到内置
%   ADEV。OUTPUT 包含 config、results、summary、dataQuality 和
%   outliers，并保存 CSV、MAT 及稳定度图。
%
%   Example:
%       output = s12_batch_allan_stability_analysis();
%
%   See also allanvar, detrend, readmatrix

if nargin < 1
    filePaths = [];
end
if nargin < 2
    outputFolder = '';
end

clc;

%% ======================= 1. 用户配置区 =======================

cfg = struct();
paths = laser_test_paths();

% GUI 默认打开目录；不存在时自动退回当前目录。
cfg.initialDataFolder = paths.rfReferenceDataRoot;

% 光速
cfg.c = 299792458;

% 归一化中心频率设置
% 二选一：
%   A. 光学等效分数稳定度：cfg.centerFreq_Hz = cfg.c/(cfg.lambda_nm*1e-9);
%   B. RF自身分数稳定度： cfg.centerFreq_Hz = 300e6;
cfg.lambda_nm = 698.0;
cfg.centerFreq_Hz = 100e6;                  % 三路 100 MHz RF 的归一化频率
% cfg.lambda_nm = 1397.0;                   % 若要复现 notebook 的 1397 nm 设置，取消本行注释并同步下一行
% cfg.centerFreq_Hz = cfg.c/(cfg.lambda_nm*1e-9);
% cfg.centerFreq_Hz = 300e6;                % 若报告 300 MHz RF 信号自身稳定度，改用这一行

% 频率计时序。当前按“100 ms 门时间、连续输出、无死区”处理。
cfg.gateTime_s = 0.1;
cfg.deadTime_s = 0;
cfg.defaultTau0_s = 0.1;                    % 相邻 CSV 记录间隔 tau0
cfg.targetTau_s  = 1.0;                     % 自动提取最接近 1 s 的稳定度
cfg.maxTauFraction = 0.10;                  % 正式曲线最长 tau 不超过记录时长的 1/10

% 计算类型：
%   'adev' : 普通 Allan deviation，对应原 .m 脚本
%   'mdev' : Modified Allan deviation，对应 Python notebook 的 allantools.mdev
%   'both' : 两者都算
cfg.calcMode = 'both';

% tau 点选择：
%   'decade' : 按对数间隔取点，适合批量处理和画图；
%   'all'    : 每个 m 都算，和原脚本 m=1:1:N/2 更接近，但慢、长 tau 更密更噪。
cfg.tauGrid = 'decade';

% ADEV 是否优先调用 MATLAB 自带 allanvar
% 如果没有 allanvar，本脚本会自动切换到内置重叠 Allan deviation 算法。
cfg.useBuiltinAllanvar = false;             % 统一使用内置重叠算法，便于处理异常点窗口

% 是否做线性去漂。Raw 和 Detrended 都会输出；该开关控制是否额外计算去漂曲线。
cfg.removeLinearDrift = true;

% 异常点策略：保留全量 Raw 曲线，同时生成排除异常窗口的正式曲线。
% 只排除包含异常点的 ADEV/MDEV 窗口，不删除数据后拼接时间轴。
cfg.detectOutliers = true;
cfg.outlierThreshold_Hz = 1.0;

% 图片/表格输出
cfg.saveFigures = true;
cfg.saveSummaryCsv = true;
cfg.showFigures = true;

% 图像水印，可留空
cfg.watermark = 'HY Allan Stability';

% 数据格式默认值：当前频率计 CSV 为单列 Hz 数据、无时间列。
cfg.defaultFreqCol = 1;
cfg.defaultTimeCol = 0;
cfg.defaultFreqScale = 1;

% 无输入参数时弹出 GUI，支持在同一目录内多选 CSV/TXT。
filePaths = selectInputFiles(filePaths, cfg.initialDataFolder);
if isempty(filePaths)
    fprintf('未选择文件，分析已取消。\n');
    output = struct([]);
    return;
end

[firstFolder, ~, ~] = fileparts(filePaths{1});
cfg.dataFolder = firstFolder;
if isempty(outputFolder)
    cfg.outputFolder = fullfile(firstFolder, ...
        ['allan_results_', datestr(now, 'yyyymmdd_HHMMSS')]);
else
    cfg.outputFolder = char(outputFolder);
end

% 数据配置：每个文件一行 struct
% 字段说明：
%   file       : 数据文件名
%   label      : 图例/汇总表名称
%   freqCol    : 频率所在列。原 .m 通常是第1列；notebook 中示例是第4列
%   timeCol    : 时间所在列；无时间列则填 0，会用 tau0 自动生成时间
%   tau0       : 采样间隔，单位 s；10 Hz 采样填 0.1
%   freqScale  : 频率单位换算；Hz数据填1，kHz填1e3，MHz填1e6
%   startRatio : 截取起点比例，0表示从头开始
%   endRatio   : 截取终点比例，1表示到末尾
%   startTime_s/endTime_s : 若想按时间截取，填具体秒数；不用则 NaN
%
dataConfigs = struct([]);
for iFile = 1:numel(filePaths)
    [~, baseName, ext] = fileparts(filePaths{iFile});
    dataConfigs(iFile).filePath = filePaths{iFile}; %#ok<SAGROW>
    dataConfigs(iFile).file = [baseName, ext]; %#ok<SAGROW>
    dataConfigs(iFile).label = baseName; %#ok<SAGROW>
    dataConfigs(iFile).freqCol = cfg.defaultFreqCol; %#ok<SAGROW>
    dataConfigs(iFile).timeCol = cfg.defaultTimeCol; %#ok<SAGROW>
    dataConfigs(iFile).tau0 = cfg.defaultTau0_s; %#ok<SAGROW>
    dataConfigs(iFile).freqScale = cfg.defaultFreqScale; %#ok<SAGROW>
    dataConfigs(iFile).startRatio = 0.0; %#ok<SAGROW>
    dataConfigs(iFile).endRatio = 1.0; %#ok<SAGROW>
    dataConfigs(iFile).startTime_s = NaN; %#ok<SAGROW>
    dataConfigs(iFile).endTime_s = NaN; %#ok<SAGROW>
end

%% ======================= 2. 主程序 =======================

if ~exist(cfg.outputFolder, 'dir')
    mkdir(cfg.outputFolder);
end

hasAdev = strcmpi(cfg.calcMode, 'adev') || strcmpi(cfg.calcMode, 'both');
hasMdev = strcmpi(cfg.calcMode, 'mdev') || strcmpi(cfg.calcMode, 'both');

if isempty(dataConfigs)
    error('dataConfigs 为空：请至少配置一个数据文件。');
end

fprintf('\n========== Allan/MDEV Batch Analysis ==========\n');
fprintf('Data folder       : %s\n', cfg.dataFolder);
fprintf('Output folder     : %s\n', cfg.outputFolder);
fprintf('Center frequency  : %.12e Hz\n', cfg.centerFreq_Hz);
fprintf('Counter gate time : %.6g s\n', cfg.gateTime_s);
fprintf('Sampling interval : %.6g s\n', cfg.defaultTau0_s);
fprintf('Target tau        : %.6g s\n', cfg.targetTau_s);
fprintf('Calc mode         : %s\n', cfg.calcMode);
fprintf('Tau grid          : %s\n', cfg.tauGrid);
fprintf('Outlier threshold : %.6g Hz\n', cfg.outlierThreshold_Hz);
fprintf('================================================\n\n');

results = struct([]);
summaryRows = cell(0, 14);
qualityRows = cell(0, 10);
outlierRows = cell(0, 6);

for k = 1:numel(dataConfigs)
    dc = fillDefaultDataConfig(dataConfigs(k), cfg);
    filePath = dc.filePath;

    fprintf('[%d/%d] Processing: %s\n', k, numel(dataConfigs), dc.label);
    fprintf('      File: %s\n', filePath);

    try
        [freqFull_Hz, timeFull_s, tau0_s] = readFrequencyCounterFile(filePath, dc, cfg);
        [freq_Hz, time_s, cropInfo] = cropFrequencyData(freqFull_Hz, timeFull_s, dc);

        processed = processFrequencyData(freq_Hz, time_s, tau0_s, cfg);

        mList = makeMList(numel(processed.yRawAll), cfg.tauGrid, ...
            cfg.calcMode, tau0_s, cfg.targetTau_s, cfg.maxTauFraction);

        res = struct();
        res.label = dc.label;
        res.file = dc.file;
        res.N = numel(freq_Hz);
        res.tau0_s = tau0_s;
        res.cropInfo = cropInfo;
        res.driftSlope_HzPerS = processed.driftSlope_HzPerS;
        res.driftIntercept_Hz = processed.driftIntercept_Hz;
        res.freqMean_Hz = finiteMean(freq_Hz(processed.validMask));
        res.freqStd_Hz = finiteStd(freq_Hz(processed.validMask));
        res.outlierCount = processed.outlierCount;

        qualityRows(end+1, :) = {dc.label, dc.file, res.N, ...
            sum(processed.validMask), processed.outlierCount, tau0_s, ...
            cfg.gateTime_s, cfg.deadTime_s, cfg.outlierThreshold_Hz, ...
            processed.freqMedian_Hz}; %#ok<SAGROW>

        badIdx = find(~processed.validMask);
        for j = 1:numel(badIdx)
            idxBad = badIdx(j);
            outlierRows(end+1, :) = {dc.label, dc.file, idxBad, ...
                time_s(idxBad), freq_Hz(idxBad), ...
                freq_Hz(idxBad) - processed.freqMedian_Hz}; %#ok<SAGROW>
        end

        if hasAdev
            [res.adevAllTau_s, res.adevAll] = calcAdevFromFreq( ...
                processed.yRawAll, tau0_s, mList, cfg.useBuiltinAllanvar);
            [res.adevValidTau_s, res.adevValid] = calcAdevFromFreq( ...
                processed.yRawValid, tau0_s, mList, false);
            [res.adevDetrTau_s, res.adevDetrended] = calcAdevFromFreq( ...
                processed.yDetrendedValid, tau0_s, mList, false);

            [tauAt, valAt] = valueAtTau(res.adevValidTau_s, ...
                res.adevValid, cfg.targetTau_s);
            fprintf('      ADEV valid/raw @ %.6g s = %.4e (actual tau %.6g s)\n', ...
                cfg.targetTau_s, valAt, tauAt);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'ADEV', ...
                'Raw_ValidWindows', cfg, res, tauAt, valAt); %#ok<SAGROW>

            [tauAllAt, valAllAt] = valueAtTau(res.adevAllTau_s, ...
                res.adevAll, cfg.targetTau_s);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'ADEV', ...
                'Raw_AllSamples', cfg, res, tauAllAt, valAllAt); %#ok<SAGROW>

            [tauDetrAt, valDetrAt] = valueAtTau(res.adevDetrTau_s, ...
                res.adevDetrended, cfg.targetTau_s);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'ADEV', ...
                'Detrended_ValidWindows', cfg, res, tauDetrAt, valDetrAt); %#ok<SAGROW>
        end

        if hasMdev
            [res.mdevAllTau_s, res.mdevAll] = calcMdevFromFreq( ...
                processed.yRawAll, tau0_s, mList);
            [res.mdevValidTau_s, res.mdevValid] = calcMdevFromFreq( ...
                processed.yRawValid, tau0_s, mList);
            [res.mdevDetrTau_s, res.mdevDetrended] = calcMdevFromFreq( ...
                processed.yDetrendedValid, tau0_s, mList);

            [tauAt, valAt] = valueAtTau(res.mdevValidTau_s, ...
                res.mdevValid, cfg.targetTau_s);
            fprintf('      MDEV valid/raw @ %.6g s = %.4e (actual tau %.6g s)\n', ...
                cfg.targetTau_s, valAt, tauAt);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'MDEV', ...
                'Raw_ValidWindows', cfg, res, tauAt, valAt); %#ok<SAGROW>

            [tauAllAt, valAllAt] = valueAtTau(res.mdevAllTau_s, ...
                res.mdevAll, cfg.targetTau_s);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'MDEV', ...
                'Raw_AllSamples', cfg, res, tauAllAt, valAllAt); %#ok<SAGROW>

            [tauDetrAt, valDetrAt] = valueAtTau(res.mdevDetrTau_s, ...
                res.mdevDetrended, cfg.targetTau_s);
            summaryRows(end+1, :) = makeSummaryRow(dc, 'MDEV', ...
                'Detrended_ValidWindows', cfg, res, tauDetrAt, valDetrAt); %#ok<SAGROW>
        end

        plotTimeDomain(processed, dc, cfg, k);
        if isempty(results)
            results = res;
        else
            results(end+1) = res; %#ok<SAGROW>
        end

        fprintf('      Drift slope: %.4e Hz/s\n', processed.driftSlope_HzPerS);
        fprintf('      Points: %d total, %d valid, %d outliers; tau0 = %.6g s\n', ...
            numel(freq_Hz), sum(processed.validMask), processed.outlierCount, tau0_s);
        fprintf('      Crop: [%d, %d]\n\n', cropInfo.startIndex, cropInfo.endIndex);

    catch ME
        warning('处理失败：%s\n原因：%s', dc.label, ME.message);
        continue;
    end
end

if isempty(results)
    error('没有成功处理的数据，请检查文件路径、列号、采样率和数据格式。');
end

if hasAdev
    plotMetricComparison(results, cfg, 'ADEV');
end
if hasMdev
    plotMetricComparison(results, cfg, 'MDEV');
end

summaryTable = cell2table(summaryRows, 'VariableNames', { ...
    'Label', 'File', 'Metric', 'DataVersion', ...
    'TargetTau_s', 'ActualTau_s', 'Stability', ...
    'DriftSlope_HzPerS', 'DriftIntercept_Hz', ...
    'N', 'Tau0_s', 'CenterFreq_Hz', 'ValidFreqMean_Hz', 'ValidFreqStd_Hz'});

qualityTable = cell2table(qualityRows, 'VariableNames', { ...
    'Label', 'File', 'N_Total', 'N_Valid', 'N_Outliers', ...
    'Tau0_s', 'GateTime_s', 'DeadTime_s', 'OutlierThreshold_Hz', ...
    'FrequencyMedian_Hz'});

outlierTable = cell2table(outlierRows, 'VariableNames', { ...
    'Label', 'File', 'SampleIndex', 'Time_s', 'Frequency_Hz', ...
    'DeviationFromMedian_Hz'});

disp(' ');
disp('========== Summary ==========');
disp(summaryTable);

if cfg.saveSummaryCsv
    summaryPath = fullfile(cfg.outputFolder, 'allan_summary.csv');
    writetable(summaryTable, summaryPath);
    writetable(qualityTable, fullfile(cfg.outputFolder, 'data_quality_summary.csv'));
    writetable(outlierTable, fullfile(cfg.outputFolder, 'outlier_events.csv'));
    fprintf('\nSummary saved: %s\n', summaryPath);
end

output = struct();
output.config = cfg;
output.results = results;
output.summary = summaryTable;
output.dataQuality = qualityTable;
output.outliers = outlierTable;
save(fullfile(cfg.outputFolder, 'allan_analysis_result.mat'), 'output');

fprintf('\nDone. Output folder: %s\n', cfg.outputFolder);
if usejava('desktop')
    msgbox(sprintf('分析完成。\n结果目录：\n%s', cfg.outputFolder), ...
        'Allan stability analysis');
end
end

%% ======================= 3. 本脚本局部函数 =======================

function filePaths = selectInputFiles(filePaths, initialFolder)
    %selectInputFiles - 规范化显式路径或通过 GUI 多选数据文件
    if ~isempty(filePaths)
        if ischar(filePaths)
            filePaths = {filePaths};
        elseif isstring(filePaths)
            filePaths = cellstr(filePaths(:));
        elseif ~iscell(filePaths)
            error('filePaths 必须是字符向量、字符串数组或 cell 数组。');
        end
        filePaths = filePaths(:)';
    else
        if ~usejava('desktop')
            error(['当前 MATLAB 无桌面 GUI，无法弹出文件选择窗口。', ...
                '请通过 filePaths 参数传入 CSV 文件路径。']);
        end
        if ~exist(initialFolder, 'dir')
            initialFolder = pwd;
        end
        defaultPattern = fullfile(initialFolder, '*.csv');
        [fileNames, selectedFolder] = uigetfile( ...
            {'*.csv;*.txt', '频率计数据 (*.csv, *.txt)'; ...
             '*.csv', 'CSV 文件 (*.csv)'; ...
             '*.*', '所有文件 (*.*)'}, ...
            '选择一个或多个频率计数据文件', defaultPattern, ...
            'MultiSelect', 'on');
        if isequal(fileNames, 0)
            filePaths = {};
            return;
        end
        if ischar(fileNames)
            fileNames = {fileNames};
        end
        filePaths = cellfun(@(name) fullfile(selectedFolder, name), ...
            fileNames, 'UniformOutput', false);
    end

    for i = 1:numel(filePaths)
        filePaths{i} = char(filePaths{i});
        if ~exist(filePaths{i}, 'file')
            error('找不到输入文件：%s', filePaths{i});
        end
    end
end

function dc = fillDefaultDataConfig(dc, cfg)
    %fillDefaultDataConfig - 为单文件配置补齐列号、单位和截取范围
    if ~isfield(dc, 'file'), error('dataConfigs 缺少 file 字段。'); end
    if ~isfield(dc, 'filePath') || isempty(dc.filePath)
        dc.filePath = fullfile(cfg.dataFolder, dc.file);
    end
    if ~isfield(dc, 'label') || isempty(dc.label), dc.label = dc.file; end
    if ~isfield(dc, 'freqCol') || isempty(dc.freqCol), dc.freqCol = cfg.defaultFreqCol; end
    if ~isfield(dc, 'timeCol') || isempty(dc.timeCol), dc.timeCol = cfg.defaultTimeCol; end
    if ~isfield(dc, 'tau0') || isempty(dc.tau0), dc.tau0 = cfg.defaultTau0_s; end
    if ~isfield(dc, 'freqScale') || isempty(dc.freqScale), dc.freqScale = cfg.defaultFreqScale; end
    if ~isfield(dc, 'startRatio') || isempty(dc.startRatio), dc.startRatio = 0; end
    if ~isfield(dc, 'endRatio') || isempty(dc.endRatio), dc.endRatio = 1; end
    if ~isfield(dc, 'startTime_s') || isempty(dc.startTime_s), dc.startTime_s = NaN; end
    if ~isfield(dc, 'endTime_s') || isempty(dc.endTime_s), dc.endTime_s = NaN; end
end

function [freq_Hz, time_s, tau0_s] = readFrequencyCounterFile(filePath, dc, cfg)
    %readFrequencyCounterFile - 读取频率列、时间列并确定采样间隔
    if ~exist(filePath, 'file')
        error('找不到数据文件：%s', filePath);
    end

    data = readmatrix(filePath);

    if isempty(data)
        error('readmatrix 未读到有效数值数据：%s', filePath);
    end

    % 去掉全 NaN 行/列，尽量兼容带表头的 csv
    data = data(:, any(isfinite(data), 1));
    data = data(any(isfinite(data), 2), :);

    if dc.freqCol > size(data, 2)
        error('freqCol=%d 超出数据列数=%d。', dc.freqCol, size(data, 2));
    end

    freq_Hz = data(:, dc.freqCol) * dc.freqScale;

    if dc.timeCol > 0
        if dc.timeCol > size(data, 2)
            error('timeCol=%d 超出数据列数=%d。', dc.timeCol, size(data, 2));
        end
        time_s = data(:, dc.timeCol);
        validTime = isfinite(time_s);
        freq_Hz = freq_Hz(validTime);
        time_s = time_s(validTime);
        time_s = time_s - time_s(1);

        dt = diff(time_s);
        dt = dt(isfinite(dt) & dt > 0);
        if isempty(dt)
            tau0_s = dc.tau0;
            warning('时间列无法推断采样间隔，改用 tau0=%.6g s。', tau0_s);
        else
            tau0_s = finiteMedian(dt);
            if ~isempty(dt) && max(abs(dt - tau0_s)) > max(1e-9, 1e-3 * tau0_s)
                warning('时间列采样间隔不完全均匀，将使用 median(diff(time))=%.6g s 近似。', tau0_s);
            end
        end
    else
        tau0_s = dc.tau0;
        time_s = (0:numel(freq_Hz)-1)' * tau0_s;
    end

    if isempty(freq_Hz) || sum(isfinite(freq_Hz)) < 10
        error('有效频率数据点过少。');
    end

    if tau0_s <= 0 || ~isfinite(tau0_s)
        tau0_s = cfg.defaultTau0_s;
        warning('tau0 非法，改用默认 tau0=%.6g s。', tau0_s);
    end
end

function [freqSeg_Hz, timeSeg_s, cropInfo] = cropFrequencyData(freqFull_Hz, timeFull_s, dc)
    %cropFrequencyData - 按比例或时间范围截取连续记录
    N = numel(freqFull_Hz);

    if ~isnan(dc.startTime_s) || ~isnan(dc.endTime_s)
        t0 = dc.startTime_s;
        t1 = dc.endTime_s;
        if isnan(t0), t0 = -Inf; end
        if isnan(t1), t1 = Inf; end

        mask = (timeFull_s >= t0) & (timeFull_s <= t1);
        idx = find(mask);
        if isempty(idx)
            error('按时间截取后没有数据，请检查 startTime_s/endTime_s。');
        end
        startIndex = idx(1);
        endIndex = idx(end);
    else
        startRatio = min(max(dc.startRatio, 0), 1);
        endRatio = min(max(dc.endRatio, 0), 1);
        if endRatio <= startRatio
            error('endRatio 必须大于 startRatio。');
        end
        startIndex = max(1, floor(N * startRatio) + 1);
        endIndex = min(N, floor(N * endRatio));
        if endIndex <= startIndex
            error('比例截取后数据点过少，请调整 startRatio/endRatio。');
        end
    end

    freqSeg_Hz = freqFull_Hz(startIndex:endIndex);
    timeSeg_s = timeFull_s(startIndex:endIndex);
    timeSeg_s = timeSeg_s - timeSeg_s(1);

    cropInfo = struct();
    cropInfo.startIndex = startIndex;
    cropInfo.endIndex = endIndex;
    cropInfo.NFull = N;
end

function processed = processFrequencyData(freqRaw_Hz, time_s, tau0_s, cfg)
    %processFrequencyData - 归一化分数频率并标记漂移和异常窗口
    freqRaw_Hz = freqRaw_Hz(:);
    time_s = time_s(:);

    % 使用中位数作为数值中心，避免孤立失锁值污染归一化前的中心化。
    freqMean_Hz = finiteMean(freqRaw_Hz);
    freqMedian_Hz = finiteMedian(freqRaw_Hz);
    validMask = isfinite(freqRaw_Hz) & isfinite(time_s);
    if cfg.detectOutliers && isfinite(cfg.outlierThreshold_Hz)
        validMask = validMask & ...
            abs(freqRaw_Hz - freqMedian_Hz) <= cfg.outlierThreshold_Hz;
    end
    if sum(validMask) < 10
        error('排除无效值/异常点后，有效频率数据少于 10 点。');
    end

    yRawAll = (freqRaw_Hz - freqMedian_Hz) / cfg.centerFreq_Hz;
    yRawValid = yRawAll;
    yRawValid(~validMask) = NaN;

    % 漂移拟合只使用有效点；异常点仍保留在 Raw_AllSamples 曲线中。
    if cfg.removeLinearDrift
        p = polyfit(time_s(validMask), freqRaw_Hz(validMask), 1);
        freqDriftFit_Hz = polyval(p, time_s);
        freqDetrended_Hz = freqRaw_Hz - freqDriftFit_Hz;
        driftSlope_HzPerS = p(1);
        driftIntercept_Hz = p(2);
    else
        freqDriftFit_Hz = freqMedian_Hz * ones(size(freqRaw_Hz));
        freqDetrended_Hz = freqRaw_Hz - freqMedian_Hz;
        driftSlope_HzPerS = 0;
        driftIntercept_Hz = freqMedian_Hz;
    end

    freqDetrendedValid_Hz = freqDetrended_Hz;
    freqDetrendedValid_Hz(~validMask) = NaN;
    yDetrendedValid = freqDetrendedValid_Hz / cfg.centerFreq_Hz;

    processed = struct();
    processed.time_s = time_s;
    processed.tau0_s = tau0_s;
    processed.freqRaw_Hz = freqRaw_Hz;
    processed.freqMean_Hz = freqMean_Hz;
    processed.freqMedian_Hz = freqMedian_Hz;
    processed.freqDriftFit_Hz = freqDriftFit_Hz;
    processed.freqDetrended_Hz = freqDetrended_Hz;
    processed.freqDetrendedValid_Hz = freqDetrendedValid_Hz;
    processed.validMask = validMask;
    processed.outlierCount = sum(~validMask);
    processed.yRawAll = yRawAll;
    processed.yRawValid = yRawValid;
    processed.yDetrendedValid = yDetrendedValid;
    processed.driftSlope_HzPerS = driftSlope_HzPerS;
    processed.driftIntercept_Hz = driftIntercept_Hz;
end

function mList = makeMList(N, tauGrid, calcMode, tau0_s, targetTau_s, maxTauFraction)
    %makeMList - 根据记录长度和 tau 策略生成平均因子 m
    if strcmpi(calcMode, 'adev')
        estimatorLimit = floor(N / 2);
    else
        estimatorLimit = floor(N / 3);
    end

    confidenceLimit = floor(N * maxTauFraction);
    mMax = min(estimatorLimit, confidenceLimit);
    mMax = max(1, mMax);

    if strcmpi(tauGrid, 'all')
        mList = 1:mMax;
    else
        nTau = min(80, mMax);
        if mMax == 1
            mList = 1;
        else
            mList = unique(round(logspace(0, log10(mMax), nTau)));
        end
    end

    % 强制包含目标 tau。100 ms 采样时，m=10 精确对应 1 s。
    targetM = round(targetTau_s / tau0_s);
    if targetM >= 1 && targetM <= mMax
        mList = unique([mList, targetM]);
    end
    mList = mList(:)';
end

function [taus_s, adev] = calcAdevFromFreq(y, tau0_s, mList, useBuiltinAllanvar)
    %calcAdevFromFreq - 用工具箱或内置算法计算重叠 ADEV
    y = y(:);

    if useBuiltinAllanvar && all(isfinite(y)) && exist('allanvar', 'file') == 2
        try
            [avar, taus_s] = allanvar(y, mList, 1/tau0_s);
            adev = sqrt(avar(:));
            taus_s = taus_s(:);
            valid = isfinite(taus_s) & isfinite(adev) & adev > 0;
            taus_s = taus_s(valid);
            adev = adev(valid);
            return;
        catch ME
            warning('%s', sprintf( ...
                '调用 MATLAB allanvar 失败，改用脚本内置重叠 ADEV。原因：%s', ...
                ME.message));
        end
    end

    [taus_s, adev] = localOverlappingAdevFromFreq(y, tau0_s, mList);
end

function [taus_s, adev] = localOverlappingAdevFromFreq(y, tau0_s, mList)
    %localOverlappingAdevFromFreq - 由相邻 m 点均值差计算重叠 ADEV
    % 对每个 m，先计算长度 m 的滑动平均 ybar，再使用
    % avar=0.5*mean((ybar(k+m)-ybar(k))^2)。含 NaN/异常点的完整
    % 2m 窗口被排除，但原时间索引不拼接，因此不会制造假连续数据。
    y = y(:);
    N = numel(y);
    validSample = isfinite(y);
    ySafe = y;
    ySafe(~validSample) = 0;
    csum = [0; cumsum(ySafe)];
    invalidCsum = [0; cumsum(~validSample)];

    taus_s = [];
    adev = [];

    for m = mList
        K = N - 2*m + 1;
        if K < 1
            continue;
        end

        avgCount = N - m + 1;
        idx = (1:avgCount)';
        ybar = (csum(idx + m) - csum(idx)) / m;

        windowStart = (1:K)';
        validTerms = invalidCsum(windowStart + 2*m) - ...
            invalidCsum(windowStart) == 0;
        if ~any(validTerms)
            continue;
        end

        d = ybar(windowStart + m) - ybar(windowStart);
        avar = 0.5 * mean(d(validTerms).^2);

        taus_s(end+1, 1) = m * tau0_s; %#ok<AGROW>
        adev(end+1, 1) = sqrt(avar); %#ok<AGROW>
    end
end

function [taus_s, mdev] = calcMdevFromFreq(y, tau0_s, mList)
    %calcMdevFromFreq - 由积分相位二阶差分计算 MDEV
    % 基于频率数据 y 的 Modified Allan deviation。
    % 方法：先积分得到等效时间误差 x(t)=∫y(t)dt，再用 MDEV 的二阶差分滑动平均公式。
    %
    % 对 m=1，MDEV 与 ADEV 一致；m>1 时，MDEV 等效于对频率数据做额外平均，
    % 更适合区分白相位噪声、闪烁相位噪声等高频相位噪声贡献。
    y = y(:);
    N = numel(y);
    validSample = isfinite(y);
    ySafe = y;
    ySafe(~validSample) = 0;
    invalidCsum = [0; cumsum(~validSample)];

    % x 的单位为秒量纲的等效时间误差；y 为无量纲分数频率。
    x = [0; cumsum(ySafe) * tau0_s];
    Lx = numel(x);

    taus_s = [];
    mdev = [];

    for m = mList
        if Lx - 3*m < 1
            continue;
        end

        % 二阶差分 d_i = x_{i+2m} - 2x_{i+m} + x_i
        d = x((1+2*m):Lx) - 2*x((1+m):(Lx-m)) + x(1:(Lx-2*m));

        % 对 d_i 再做长度为 m 的滑动求和
        L = numel(d) - m + 1;
        if L < 1
            continue;
        end

        csumD = [0; cumsum(d)];
        idx = (1:L)';
        sumD = csumD(idx + m) - csumD(idx);
        validTerms = invalidCsum(idx + 3*m - 1) - ...
            invalidCsum(idx) == 0;
        termCount = sum(validTerms);
        if termCount < 1
            continue;
        end

        tau_s = m * tau0_s;
        mvar = sum(sumD(validTerms).^2) / ...
            (2 * m^2 * tau_s^2 * termCount);

        taus_s(end+1, 1) = tau_s; %#ok<AGROW>
        mdev(end+1, 1) = sqrt(mvar); %#ok<AGROW>
    end

    valid = isfinite(taus_s) & isfinite(mdev) & mdev > 0;
    taus_s = taus_s(valid);
    mdev = mdev(valid);
end

function [actualTau_s, value] = valueAtTau(taus_s, values, targetTau_s)
    %valueAtTau - 返回最接近目标 tau 的有效稳定度
    if isempty(taus_s) || isempty(values)
        actualTau_s = NaN;
        value = NaN;
        return;
    end

    valid = isfinite(taus_s) & isfinite(values) & values > 0;
    taus_s = taus_s(valid);
    values = values(valid);

    if isempty(taus_s)
        actualTau_s = NaN;
        value = NaN;
        return;
    end

    [~, idx] = min(abs(taus_s - targetTau_s));
    actualTau_s = taus_s(idx);
    value = values(idx);
end

function row = makeSummaryRow(dc, metric, versionName, cfg, res, actualTau_s, value)
    %makeSummaryRow - 组装一行 ADEV/MDEV 汇总记录
    row = { ...
        dc.label, dc.file, metric, versionName, ...
        cfg.targetTau_s, actualTau_s, value, ...
        res.driftSlope_HzPerS, res.driftIntercept_Hz, ...
        res.N, res.tau0_s, cfg.centerFreq_Hz, res.freqMean_Hz, res.freqStd_Hz};
end

function plotTimeDomain(processed, dc, cfg, k)
    %plotTimeDomain - 保存原始频率、漂移和去漂时域图
    fig = figure('Name', ['Time Domain - ', dc.label], 'Position', [50 50 1200 760]);

    subplot(2,1,1);
    plot(processed.time_s, processed.freqRaw_Hz, '-', 'LineWidth', 1.0, ...
        'DisplayName', 'Raw frequency'); hold on;
    plot(processed.time_s, processed.freqDriftFit_Hz, '--', 'LineWidth', 2.0, ...
        'DisplayName', sprintf('Valid-point drift: %.3e Hz/s', ...
        processed.driftSlope_HzPerS));
    badIdx = find(~processed.validMask);
    if ~isempty(badIdx)
        plot(processed.time_s(badIdx), processed.freqRaw_Hz(badIdx), ...
            'rx', 'LineWidth', 1.8, 'MarkerSize', 8, ...
            'DisplayName', sprintf('Excluded outliers (%d)', numel(badIdx)));
    end
    grid on;
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(['Raw frequency and linear drift fit - ', dc.label], 'Interpreter', 'none');
    legend('show', 'Location', 'best', 'Interpreter', 'none');

    subplot(2,1,2);
    plot(processed.time_s, processed.freqDetrendedValid_Hz, '-', 'LineWidth', 1.0);
    grid on;
    xlabel('Time (s)');
    ylabel('\Delta Frequency after detrend (Hz)');
    title('Detrended frequency (valid samples only)', 'Interpreter', 'none');

    addWatermark(cfg.watermark);
    set(findall(fig, 'Type', 'axes'), 'FontSize', 11);

    if cfg.saveFigures
        safeName = safeFileName(sprintf('%02d_time_%s', k, dc.label));
        saveFigureSafe(fig, fullfile(cfg.outputFolder, safeName));
    end

    if ~cfg.showFigures
        close(fig);
    end
end

function plotMetricComparison(results, cfg, metricName)
    %plotMetricComparison - 保存所有文件 Raw/Detrended 稳定度对比图
    fig = figure('Name', [metricName, ' comparison'], 'Position', [80 80 1200 820]);
    ax = axes(fig); hold(ax, 'on');

    colors = lines(numel(results));

    for k = 1:numel(results)
        res = results(k);
        color = colors(k, :);

        switch upper(metricName)
            case 'ADEV'
                tauValid = res.adevValidTau_s;
                valValid = res.adevValid;
                tauDetr = res.adevDetrTau_s;
                valDetr = res.adevDetrended;
                yLabelText = 'Allan deviation \sigma_y(\tau)';
            case 'MDEV'
                tauValid = res.mdevValidTau_s;
                valValid = res.mdevValid;
                tauDetr = res.mdevDetrTau_s;
                valDetr = res.mdevDetrended;
                yLabelText = 'Modified Allan deviation mod \sigma_y(\tau)';
            otherwise
                error('未知 metricName。');
        end

        if ~isempty(tauValid)
            loglog(ax, tauValid, valValid, '-o', 'Color', color, ...
                'LineWidth', 1.6, 'MarkerSize', 4, ...
                'DisplayName', [res.label, ' Raw valid']);
        end

        if ~isempty(tauDetr)
            loglog(ax, tauDetr, valDetr, '--', 'Color', color, ...
                'LineWidth', 1.2, 'DisplayName', [res.label, ' Detrended valid']);
        end

        if ~isempty(tauValid)
            [tauAt, valAt] = valueAtTau(tauValid, valValid, cfg.targetTau_s);
            if isfinite(tauAt) && isfinite(valAt)
                plot(ax, tauAt, valAt, 's', 'Color', color, 'MarkerSize', 8, ...
                    'LineWidth', 1.5, 'HandleVisibility', 'off');
                text(ax, tauAt, valAt, sprintf('  %.3g s: %.2e', tauAt, valAt), ...
                    'Color', color, 'FontSize', 9, 'Interpreter', 'none');
            end
        end
    end

    grid(ax, 'on');
    set(ax, 'XScale', 'log', 'YScale', 'log');
    xlabel(ax, '\tau (s)');
    ylabel(ax, yLabelText);
    title(ax, [metricName, ' comparison'], 'Interpreter', 'none');
    legend(ax, 'Location', 'best', 'Interpreter', 'none');

    addWatermark(cfg.watermark);
    set(ax, 'FontSize', 12);

    if cfg.saveFigures
        saveFigureSafe(fig, fullfile(cfg.outputFolder, lower([metricName, '_comparison'])));
    end

    if ~cfg.showFigures
        close(fig);
    end
end

function addWatermark(textStr)
    %addWatermark - 在当前图窗添加可选实验水印
    if isempty(textStr)
        return;
    end
    try
        annotation('textbox', [0.30 0.45 0.45 0.12], ...
            'String', textStr, ...
            'FontSize', 22, ...
            'Color', [0.65 0.65 0.65], ...
            'EdgeColor', 'none', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Rotation', 25, ...
            'FitBoxToText', 'on');
    catch
        % 某些旧版 MATLAB 不支持 annotation Rotation；水印失败不影响数据处理。
    end
end

function saveFigureSafe(fig, basePath)
    %saveFigureSafe - 优先 exportgraphics，失败时回退到 saveas
    pngPath = [basePath, '.png'];
    figPath = [basePath, '.fig'];

    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, pngPath, 'Resolution', 300);
        else
            saveas(fig, pngPath);
        end
        savefig(fig, figPath);
        fprintf('      Figure saved: %s\n', pngPath);
    catch ME
        warning('%s', sprintf('保存图片失败：%s', ME.message));
    end
end


function m = finiteMean(x)
    %finiteMean - 计算有限元素均值，无有效值时返回 NaN
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = mean(x);
    end
end

function s = finiteStd(x)
    %finiteStd - 计算有限元素标准差，无有效值时返回 NaN
    x = x(isfinite(x));
    if numel(x) < 2
        s = NaN;
    else
        s = std(x);
    end
end

function m = finiteMedian(x)
    %finiteMedian - 计算有限元素中位数，无有效值时返回 NaN
    x = x(isfinite(x));
    if isempty(x)
        m = NaN;
    else
        m = median(x);
    end
end

function name = safeFileName(name)
    %safeFileName - 将标签转换为可用作文件名的文本
    name = regexprep(name, '[<>:"/\\|?*\s]+', '_');
    name = regexprep(name, '_+', '_');
    name = regexprep(name, '^_|_$', '');
    if isempty(name)
        name = 'figure';
    end
end

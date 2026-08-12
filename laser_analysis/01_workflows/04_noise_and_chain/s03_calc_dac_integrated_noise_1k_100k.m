%s03_calc_dac_integrated_noise_1k_100k - 计算 DAC 带内积分噪声
%   s03_calc_dac_integrated_noise_1k_100k 批量读取 cfg.files 中的 MAT，
%   计算指定频段内的 DAC 输出 RMS 噪声，并与限值比较。
%
%   MAT 必须包含电压向量 A，以及 Tinterval 或 fs。A 的单位应为 V。
%   若 A 位于放大器或衰减器之后，cfg.gain 应填写“测量值/目标输出值”
%   的增益；脚本通过 A/cfg.gain 折算到 DAC 输出参考面。
%
%   计算关系为：
%       noiseVariance = integral(PSD(f),fStart,fEnd)
%       noiseRms = sqrt(noiseVariance)
%   PSD 的单位为 V^2/Hz，积分结果为 V^2，开方后为 Vrms。不能直接
%   对 ASD 积分。cfg.bandHz 上限必须小于等于 fs/2，否则无法评估。
%
%   首次使用时修改 cfg.outputDir、cfg.bandHz、cfg.limit_uVrms、
%   cfg.gain 和 cfg.files。脚本输出汇总 CSV 和可复现 MAT，不绘图。
%
%   Example:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       s03_calc_dac_integrated_noise_1k_100k
%
%   See also s02_analyze_pico_psd_asd, pwelch, trapz
%
%   Note: pwelch 需要 Signal Processing Toolbox

clc;

%% ======================== 用户配置区：通常只改这里 ========================

paths = laser_test_paths();
dacDataDir = fullfile(paths.dac9726DataRoot, '20260703_DAC_9726');
cfg.outputDir = fullfile(dacDataDir, 'integrated_noise_1k_100k_result');
cfg.bandHz = [1e3, 100e3];
cfg.limit_uVrms = 120;

% 如果 A 已经是 DAC 输出端电压，gain = 1。
% 如果 A 是经过放大/衰减后的电压，用 A / gain 折算到 DAC 输出端。
cfg.gain = 1;

cfg.removeMean = true;

% Welch 参数：用于稳定估计宽带噪声。
cfg.welch.numSegments = 100;
cfg.welch.overlapRatio = 0.5;

cfg.files = struct([]);
cfg.files(1).name = 'DA9726 JG2 1';
cfg.files(1).path = fullfile(dacDataDir, 'JG2', 'JG2_1s_10MSPS', 'JG2_1s_10MSPS_1.mat');

cfg.files(2).name = 'DA9726 JG2 2';
cfg.files(2).path = fullfile(dacDataDir, 'JG2', 'JG2_1s_10MSPS', 'JG2_1s_10MSPS_2.mat');

cfg.files(3).name = 'DA9726 JG3';
cfg.files(3).path = fullfile(dacDataDir, 'JG3', 'JG3_1s_10MSPS.mat');

cfg.files(4).name = 'DA9726 JG32';
cfg.files(4).path = fullfile(dacDataDir, 'JG32', 'JG32_1s_10MSPS.mat');

%% ======================== 主流程 ========================

if ~exist(cfg.outputDir, 'dir')
    mkdir(cfg.outputDir);
end

resultTable = table();

for k = 1:numel(cfg.files)
    item = cfg.files(k);
    fprintf('\n========== %s ==========\n', item.name);
    result = localComputeIntegratedNoise(item, cfg);
    resultTable = [resultTable; struct2table(result)]; %#ok<AGROW>

    fprintf('fs              : %.12g Hz\n', result.Fs_Hz);
    fprintf('N               : %d\n', result.N);
    fprintf('Welch window    : %d samples\n', result.WelchWindow);
    fprintf('Welch overlap   : %d samples\n', result.WelchOverlap);
    fprintf('Band            : %.6g Hz to %.6g Hz\n', result.BandStartHz, result.BandEndHz);
    fprintf('Integrated noise: %.6f uVrms\n', result.NoiseRms_uVrms);
    fprintf('Limit           : %.6f uVrms\n', result.Limit_uVrms);
    fprintf('Judgment        : %s\n', result.Judgment);
end

csvFile = fullfile(cfg.outputDir, 'dac_integrated_noise_1k_100k_summary.csv');
matFile = fullfile(cfg.outputDir, 'dac_integrated_noise_1k_100k_summary.mat');
writetable(resultTable, csvFile);
save(matFile, 'cfg', 'resultTable');

fprintf('\nAll done.\n');
fprintf('Summary CSV: %s\n', csvFile);
fprintf('Summary MAT: %s\n', matFile);

%% ======================== 本地函数 ========================

function result = localComputeIntegratedNoise(item, cfg)
%localComputeIntegratedNoise - 计算单个 MAT 的 Welch PSD 和带内 RMS
if ~exist(item.path, 'file')
    error('找不到 MAT 文件：%s', item.path);
end

fileVars = who('-file', item.path);
loadVars = {'A'};
if ismember('Tinterval', fileVars)
    loadVars{end + 1} = 'Tinterval';
end
if ismember('fs', fileVars)
    loadVars{end + 1} = 'fs';
end

data = load(item.path, loadVars{:});
if ~isfield(data, 'A')
    error('MAT 文件中没有变量 A：%s', item.path);
end

fs = localGetSampleRate(data);
if cfg.bandHz(2) > fs / 2
    error('积分频段上限 %.6g Hz 超过 Nyquist 频率 %.6g Hz：%s', ...
        cfg.bandHz(2), fs / 2, item.path);
end

y = data.A(:);
clear data;

y = y(isfinite(y));
y = y ./ cfg.gain;

if cfg.removeMean
    y = y - mean(y);
end

n = numel(y);
if n < 16
    error('有效数据点太少：%s', item.path);
end

[win, winLen, overlap] = localMakeWelchWindow(n, cfg.welch);
[psd, freqHz] = pwelch(y, win, overlap, [], fs);

bandMask = freqHz >= cfg.bandHz(1) & freqHz <= cfg.bandHz(2);
if ~any(bandMask)
    error('频率轴没有覆盖积分频段：%s', item.path);
end

noiseVar_V2 = trapz(freqHz(bandMask), psd(bandMask));
noiseRms_V = sqrt(noiseVar_V2);
noiseRms_uVrms = noiseRms_V * 1e6;

if noiseRms_uVrms < cfg.limit_uVrms
    judgment = "PASS";
else
    judgment = "FAIL";
end

result = struct();
result.Name = string(item.name);
result.File = string(item.path);
result.Fs_Hz = fs;
result.N = n;
result.Gain = cfg.gain;
result.WelchWindow = winLen;
result.WelchOverlap = overlap;
result.BandStartHz = cfg.bandHz(1);
result.BandEndHz = cfg.bandHz(2);
result.NoiseRms_V = noiseRms_V;
result.NoiseRms_uVrms = noiseRms_uVrms;
result.Limit_uVrms = cfg.limit_uVrms;
result.Judgment = judgment;
end

function fs = localGetSampleRate(data)
%localGetSampleRate - 从 Tinterval 或 fs 元数据读取采样率
if isfield(data, 'Tinterval') && ~isempty(data.Tinterval)
    fs = 1 / data.Tinterval(1);
elseif isfield(data, 'fs') && ~isempty(data.fs)
    fs = data.fs(1);
else
    error('MAT 文件中没有 Tinterval 或 fs，无法确定采样率。');
end

if ~isfinite(fs) || fs <= 0
    error('采样率无效。');
end
end

function [win, winLen, overlap] = localMakeWelchWindow(n, welchCfg)
%localMakeWelchWindow - 根据样本数、分段数和重叠率生成 Hann 窗
if ~isfinite(welchCfg.numSegments) || welchCfg.numSegments <= 0
    error('cfg.welch.numSegments 必须是正数。');
end
if ~isfinite(welchCfg.overlapRatio) || welchCfg.overlapRatio < 0 || welchCfg.overlapRatio >= 1
    error('cfg.welch.overlapRatio 必须满足 0 <= overlapRatio < 1。');
end

winLen = max(8, floor(n / welchCfg.numSegments));
winLen = min(winLen, n);
overlap = min(floor(winLen * welchCfg.overlapRatio), winLen - 1);
win = hanning(winLen);
end

function [signalA, fs] = load_pico_data(hardware_gain, filename)
% LOAD_PICO_DATA 加载并预处理Pico数据
% 输入:
%   hardware_gain - 硬件增益系数 (必需)
%   filename      - 文件路径 (可选，若不输入则弹出选择框)
% 输出:
%   signalA       - 预处理后的信号向量
%   fs            - 采样率 (Hz)

    % 1. 判断并获取文件路径
    if nargin < 2 || isempty(filename)
        % 如果没有输入文件名，弹出对话框
        [fileName, filePath] = uigetfile('*.mat', '选择 .mat 数据文件');
        if isequal(fileName, 0)
            warning('未选择文件，函数已退出。');
            signalA = []; fs = [];
            return;
        end
        fullPath = fullfile(filePath, fileName);
    else
        % 如果输入了文件名，直接使用
        fullPath = filename;
        if ~exist(fullPath, 'file')
            error('找不到指定的文件: %s', fullPath);
        end
    end

    % 2. 加载与清洗数据
    fprintf('正在处理: %s\n', fullPath);
    
    % 使用结构体方式加载，防止变量不存在导致崩溃
    data = load(fullPath, 'A', 'Tinterval');
    if ~isfield(data, 'A') || ~isfield(data, 'Tinterval')
        error('文件中缺少必要的变量 "A" 或 "Tinterval"');
    end
    
    A = data.A;
    Tinterval = data.Tinterval;

    % 物理参数计算
    fs = 1 / Tinterval; % 采样率
    
    % 数据处理流
    signalA = double(A) / hardware_gain;
    signalA = signalA(isfinite(signalA));   % 剔除 INF/NaN
    signalA = detrend(signalA, 'constant'); % 去直流 (均值中心化)
    fprintf('Done\n')
end
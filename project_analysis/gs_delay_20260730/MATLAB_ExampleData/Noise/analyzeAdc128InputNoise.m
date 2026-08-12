function results = analyzeAdc128InputNoise
%analyzeAdc128InputNoise - 计算ADC128输入等效噪声
%   RESULTS = analyzeAdc128InputNoise 弹出CSV文件选择窗口，读取一个或
%   多个ILA CSV文件，将ADC码转换为电压，并输出LSB RMS、V RMS、
%   mV RMS、峰峰值和指标符合性。函数返回全部文件的汇总表RESULTS。
%
%   使用方法：
%   1. 根据硬件修改下方“用户参数配置”；
%   2. 在MATLAB命令窗口输入 analyzeAdc128InputNoise；
%   3. 在弹出的窗口中选择一个或多个ILA CSV；
%   4. 在命令窗口和结果图中查看输入等效噪声。

%% 用户参数配置：正式测试前主要修改此区域
% ADC分辨率。ADC128若为12 bit则保持12；其他型号按实际位数修改。
adcBits = 12;

% ADC芯片引脚处的模拟输入范围，单位V。
% 当前按图中0～3 V单极性输入配置。
adcInputMinV = 0;
adcInputMaxV = 3.0;

% 被测外部输入到ADC引脚的模拟传递增益：
%     Vadc = frontEndGain * Vin
% ADC直接测量外部输入时设为1；
% 二分之一分压时设为0.5；前端放大10倍时设为10。
% 程序会用ADC引脚噪声除以该增益，折算到外部输入端。
frontEndGain = 1.0;

% 输入等效噪声验收门限，单位V RMS。
% 1e-3 V即1 mV，对应测试细则“输入等效噪声 < 1 mVrms”。
noiseLimitVrms = 1e-3;

% 丢弃每个文件开头的样点数。
% 用于避开刚启动采集、MUX刚切换或ADC尚未稳定的数据。
% 如果CSV已经全部是稳定数据，可以改为0。
discardStartSamples = 100;

% ADC数据所在列。设置为0表示自动读取CSV最后一列；
% 如果ADC数据明确在第4列，则改为4。
adcDataColumn = 0;

% 多通道轮询数据筛选配置：
% false：CSV已经只包含一个通道，不做筛选；
% true ：CSV包含多个交织通道，按channelColumn和selectedChannel筛选。
useChannelFilter = false;

% useChannelFilter=true时才使用下面两个参数。
% channelColumn为通道号所在列；selectedChannel为需要分析的通道号。
channelColumn = 1;       %#ok<NASGU> % 关闭筛选时暂不使用
selectedChannel = 0;     %#ok<NASGU> % 关闭筛选时暂不使用

%% 检查参数是否合理
if adcBits < 1 || adcBits ~= floor(adcBits)
    error('adcBits must be a positive integer.');
end
if adcInputMaxV <= adcInputMinV
    error('adcInputMaxV must be greater than adcInputMinV.');
end
if frontEndGain <= 0
    error('frontEndGain must be greater than zero.');
end
if noiseLimitVrms <= 0
    error('noiseLimitVrms must be greater than zero.');
end
if discardStartSamples < 0 || discardStartSamples ~= floor(discardStartSamples)
    error('discardStartSamples must be a nonnegative integer.');
end

%% 弹出GUI，选择一个或多个ILA CSV文件
initialPath = fileparts(mfilename('fullpath'));
[fileNames, pathName] = uigetfile( ...
    fullfile(initialPath, '*.csv'), ...
    'Select ADC128 ILA CSV file(s)', ...
    'MultiSelect', 'on');

if isequal(fileNames, 0)
    fprintf('No file selected. Analysis cancelled.\n');
    results = table;
    return;
end

if ~iscell(fileNames)
    fileNames = {fileNames};
end

fileCount = numel(fileNames);
fileNameResult = strings(fileCount, 1);
sampleCountResult = zeros(fileCount, 1);
meanAdcVoltageResult = zeros(fileCount, 1);
noiseLsbResult = zeros(fileCount, 1);
noiseVrmsResult = zeros(fileCount, 1);
noiseMillivoltResult = zeros(fileCount, 1);
noisePeakToPeakResult = zeros(fileCount, 1);
passResult = false(fileCount, 1);

adcCodeCount = 2^adcBits;
adcCodeMinimum = 0;
adcCodeMaximum = adcCodeCount - 1;
voltsPerCode = (adcInputMaxV - adcInputMinV) / adcCodeCount;

fprintf('\nADC128 equivalent input noise analysis\n');
fprintf('========================================\n');
fprintf('ADC resolution: %d bit\n', adcBits);
fprintf('ADC input range: %.6f V to %.6f V\n', ...
    adcInputMinV, adcInputMaxV);
fprintf('ADC scale: %.6f mV/LSB\n', voltsPerCode * 1e3);
fprintf('Front-end gain: %.6g V/V\n', frontEndGain);
fprintf('Noise requirement: < %.3f mV RMS\n', ...
    noiseLimitVrms * 1e3);
fprintf('========================================\n');

%% 逐个分析所选CSV文件
for fileIndex = 1:fileCount
    fileName = fileNames{fileIndex};
    filePath = fullfile(pathName, fileName);
    numericData = readmatrix(filePath);

    if isempty(numericData)
        error('No numeric data found in file: %s', filePath);
    end

    if adcDataColumn == 0
        resolvedAdcColumn = size(numericData, 2);
    else
        resolvedAdcColumn = adcDataColumn;
    end

    if resolvedAdcColumn < 1 || resolvedAdcColumn > size(numericData, 2)
        error('ADC data column is outside the CSV column range: %s', ...
            filePath);
    end

    adcCode = numericData(:, resolvedAdcColumn);
    validMask = isfinite(adcCode);

    if useChannelFilter
        if channelColumn < 1 || channelColumn > size(numericData, 2) %#ok<UNRCH>
            error('Channel column is outside the CSV column range: %s', ...
                filePath);
        end
        channelValue = numericData(:, channelColumn);
        validMask = validMask & isfinite(channelValue) & ...
            channelValue == selectedChannel;
    end

    adcCode = double(adcCode(validMask));

    if numel(adcCode) <= discardStartSamples
        error(['File %s contains only %d valid samples; this is not ' ...
            'enough to discard %d start samples.'], ...
            fileName, numel(adcCode), discardStartSamples);
    end

    adcCode = adcCode(discardStartSamples + 1:end);

    outOfRangeMask = adcCode < adcCodeMinimum | ...
        adcCode > adcCodeMaximum;
    if any(outOfRangeMask)
        error(['File %s contains %d codes outside the valid range ' ...
            '%d to %d. Check the selected column and ADC coding.'], ...
            fileName, nnz(outOfRangeMask), ...
            adcCodeMinimum, adcCodeMaximum);
    end

    % 将无符号、单极性的ADC码转换为ADC芯片引脚处电压。
    % 换算关系：
    %     Vadc = adcInputMinV + code * voltsPerCode
    adcVoltageV = adcInputMinV + adcCode * voltsPerCode;
    meanAdcVoltageV = mean(adcVoltageV);

    % 输入等效噪声只关心相对平均值的波动，因此先去除直流平均值。
    % 再除以前端增益，将ADC引脚处噪声折算回外部被测输入端。
    adcNoiseV = adcVoltageV - meanAdcVoltageV;
    equivalentInputNoiseV = adcNoiseV / frontEndGain;

    % RMS定义：所有去直流后的输入等效噪声平方求均值，再开平方。
    noiseVrmsV = sqrt(mean(equivalentInputNoiseV.^2));
    noiseVrmsMillivolt = noiseVrmsV * 1e3;

    % 峰峰值仅用于观察异常尖峰，不作为“<1 mVrms”的直接判据。
    noisePeakToPeakMillivolt = ...
        (max(equivalentInputNoiseV) - ...
        min(equivalentInputNoiseV)) * 1e3;

    % ADC码标准差，便于判断噪声相当于多少个LSB。
    noiseLsbRms = std(adcCode, 1);

    % 严格按小于门限判为通过。
    isPass = noiseVrmsV < noiseLimitVrms;

    fileNameResult(fileIndex) = string(fileName);
    sampleCountResult(fileIndex) = numel(adcCode);
    meanAdcVoltageResult(fileIndex) = meanAdcVoltageV;
    noiseLsbResult(fileIndex) = noiseLsbRms;
    noiseVrmsResult(fileIndex) = noiseVrmsV;
    noiseMillivoltResult(fileIndex) = noiseVrmsMillivolt;
    noisePeakToPeakResult(fileIndex) = noisePeakToPeakMillivolt;
    passResult(fileIndex) = isPass;

    if isPass
        complianceText = 'PASS';
    else
        complianceText = 'FAIL';
    end

    fprintf('\nFile: %s\n', fileName);
    fprintf('Valid samples: %d\n', numel(adcCode));
    fprintf('Mean ADC-pin voltage: %.6f V\n', meanAdcVoltageV);
    fprintf('Code noise: %.4f LSB RMS\n', noiseLsbRms);
    fprintf('Equivalent input noise: %.6e V RMS\n', noiseVrmsV);
    fprintf('Equivalent input noise: %.4f mV RMS\n', ...
        noiseVrmsMillivolt);
    fprintf('Equivalent input noise peak-to-peak: %.4f mVpp\n', ...
        noisePeakToPeakMillivolt);
    fprintf('Requirement: < %.4f mV RMS\n', noiseLimitVrms * 1e3);
    fprintf('Result: %s\n', complianceText);

    %% 绘制输入等效噪声时域曲线和ADC码直方图
    figure('Color', 'w', 'Position', [100, 100, 1100, 720], ...
        'Name', ['ADC128 Noise - ' fileName], ...
        'NumberTitle', 'off');
    layout = tiledlayout(2, 1, 'TileSpacing', 'compact', ...
        'Padding', 'compact');
    title(layout, sprintf( ...
        '%s | Equivalent Input Noise = %.4f mV RMS | %s', ...
        fileName, noiseVrmsMillivolt, complianceText), ...
        'Interpreter', 'none');

    nexttile;
    plot(equivalentInputNoiseV * 1e3, 'b-', 'LineWidth', 0.8);
    hold on;
    yline(noiseVrmsMillivolt, 'r--', '+1 RMS');
    yline(-noiseVrmsMillivolt, 'r--', '-1 RMS');
    hold off;
    grid on;
    xlabel('Sample Index');
    ylabel('Input-Referred Noise (mV)');
    title('Equivalent Input Noise versus Sample Index');

    nexttile;
    histogram(adcCode, 'BinMethod', 'integers');
    grid on;
    xlabel('ADC Code');
    ylabel('Count');
    title(sprintf('ADC Code Histogram | Mean ADC Voltage = %.6f V', ...
        meanAdcVoltageV));
end

%% 生成并显示全部文件的汇总表
results = table( ...
    fileNameResult, ...
    sampleCountResult, ...
    meanAdcVoltageResult, ...
    noiseLsbResult, ...
    noiseVrmsResult, ...
    noiseMillivoltResult, ...
    noisePeakToPeakResult, ...
    passResult, ...
    'VariableNames', { ...
    'FileName', ...
    'SampleCount', ...
    'MeanAdcVoltageV', ...
    'NoiseLsbRms', ...
    'NoiseVrmsV', ...
    'NoiseVrmsMillivolt', ...
    'NoisePeakToPeakMillivolt', ...
    'Pass'});

fprintf('\n========================================\n');
fprintf('ADC128 analysis summary\n');
disp(results);
end

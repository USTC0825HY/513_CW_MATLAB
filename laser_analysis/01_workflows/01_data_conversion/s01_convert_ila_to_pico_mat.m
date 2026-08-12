function s01_convert_ila_to_pico_mat()
%s01_convert_ila_to_pico_mat - 将 ILA CSV 转换为电压 MAT
%   s01_convert_ila_to_pico_mat() 打开文件选择框，读取一个或多个
%   Vivado ILA CSV，把 ADC 原始码转换为差分输入电压，并输出
%   s02_analyze_pico_psd_asd 可直接读取的 MAT 文件。
%
%   输入 CSV 可以包含普通表头和可选的 Radix 行。dataCol 指定 ADC
%   数据列，validCol 指定有效标志列；validCol 为空时使用全部数据行。
%   当前解析器按十六进制读取 ADC 字，修改 CSV 格式时应同时检查
%   parseHexColumn 和首行识别规则。
%
%   输出 MAT 的核心变量为：
%       A         - 已换算的 ADC 差分输入电压，单位 V
%       Tinterval - 相邻样本时间间隔，单位 s
%       fs        - 采样率，单位 Hz
%   每个输入文件还会生成逐点码值 CSV；mergeOutput 为 true 时，
%   所有记录按选择顺序拼接为 merged_ltc2208_ila.mat。
%
%   电压换算使用 inputRangeVpp/2^adcBits。inputRangeVpp 必须来自
%   实际 ADC 参考电压、PGA 状态和硬件配置，不能只按文件名猜测。
%   A 已经是电压，交给 s02 后不要再次除以 ADC 满量程或差分系数。
%
%   Example:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       setup_laser_analysis
%       s01_convert_ila_to_pico_mat
%
%   See also s02_analyze_pico_psd_asd, readcell, save


clc;

%% ======================== 1. 参数区：通常只改这里 ========================

paths = laser_test_paths();
initialDir = paths.codeRoot;
outFolderName = 'ltc2208_pico_mat_simple';

dataCol = 4;        % 截图中目标数据在第 4 列 D。
validCol = [];      % 没有 valid 列就留空；有 valid 列时填列号，例如 5。
fs = 100e6;         % LTC2208 有效采样率。若 ADC ENC 为 100 MHz 且未抽点/降采样，这里就是 100e6。

adcBits = 16;
inputRangeVpp = 2.5;          % SENSE 接 VREF_2V5 为外部 2.5V 参考；PGA=0: 2.25 Vpp，PGA=1: 改成 1.50。
outputCoding = 'offset_binary'; % 原理图 MODE 通过 1k 拉 GND：offset binary。

% outputCoding 可选：
%   'offset_binary'   : MODE=0 或 MODE=1/3 VDD。0x8000 对应 0 V 差分输入。
%   'twos_complement' : MODE=2/3 VDD 或 MODE=VDD。0x0000 对应 0 V 差分输入。

mergeOutput = true;
mergedMatName = 'merged_ltc2208_ila.mat';

%% ======================== 2. 找文件 ========================

[files, dataDir] = selectCsvFiles(initialDir);
outDir = fullfile(dataDir, outFolderName);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fprintf('Found %d input file(s).\n', numel(files));
fprintf('Output directory: %s\n', outDir);
fprintf('1 LSB = %.6g V\n\n', inputRangeVpp / 2^adcBits);

%% ======================== 3. 逐文件转换 ========================

allA = {};
manifestRows = {};
Tinterval = 1 / fs;

for k = 1:numel(files)
    inPath = fullfile(files(k).folder, files(k).name);
    [~, stem, ~] = fileparts(inPath);
    outMat = fullfile(outDir, [stem '.mat']);

    raw = readIlaFile(inPath);
    firstDataRow = getFirstDataRow(raw);

    rawWords = raw(firstDataRow:end, dataCol);
    unsignedCode = parseHexColumn(rawWords, adcBits);

    if ~isempty(validCol)
        validValues = raw(firstDataRow:end, validCol);
        validMask = parseDecimalColumn(validValues) == 1;
    else
        validMask = true(size(unsignedCode));
    end

    validMask = validMask & isfinite(unsignedCode);
    unsignedCode = unsignedCode(validMask);

    signedCode = codeToSigned(unsignedCode, adcBits, outputCoding);
    A = signedCode * (inputRangeVpp / 2^adcBits);

    save(outMat, 'A', 'Tinterval', 'fs', 'unsignedCode', 'signedCode');
    allA{end+1, 1} = A; %#ok<AGROW>

    pointCsv = fullfile(outDir, [stem '_point_codes.csv']);
    pointTable = table((1:numel(A)).', unsignedCode(:), signedCode(:), A(:), ...
        'VariableNames', {'point_index', 'unsigned_code', 'signed_code', 'voltage_v'});
    writetable(pointTable, pointCsv, 'Encoding', 'UTF-8');

    manifestRows(end+1, :) = {files(k).name, outMat, pointCsv, numel(A), ...
        min(A), max(A), mean(A), std(A)}; %#ok<AGROW>

    fprintf('OK: %s -> %s, samples=%d\n', files(k).name, outMat, numel(A));
end

%% ======================== 4. 合并输出 ========================

if mergeOutput && ~isempty(allA)
    A = vertcat(allA{:});
    mergedMat = fullfile(outDir, mergedMatName);
    save(mergedMat, 'A', 'Tinterval', 'fs');
    fprintf('\nMerged MAT: %s, samples=%d\n', mergedMat, numel(A));
end

manifest = cell2table(manifestRows, 'VariableNames', { ...
    'input_file', 'mat_path', 'point_csv_path', 'sample_count', ...
    'A_min', 'A_max', 'A_mean', 'A_std'});
writetable(manifest, fullfile(outDir, 'manifest.csv'), 'Encoding', 'UTF-8');

disp(manifest);
end

%% ======================== 小工具函数 ========================

function [files, dataDir] = selectCsvFiles(initialDir)
%selectCsvFiles - 选择一个或多个 ILA CSV，并返回统一文件结构
[fileNames, dataDir] = uigetfile({'*.csv', 'Vivado ILA CSV files (*.csv)'}, ...
    '请选择一个或多个 ILA CSV 文件', initialDir, 'MultiSelect', 'on');

if isequal(fileNames, 0)
    error('已取消文件选择，未处理任何 ILA CSV 文件。');
end

if ischar(fileNames) || isstring(fileNames)
    fileNames = cellstr(fileNames);
end

files = repmat(struct('folder', dataDir, 'name', ''), numel(fileNames), 1);
for i = 1:numel(fileNames)
    files(i).name = fileNames{i};
end
end

function raw = readIlaFile(filePath)
%readIlaFile - 以单元格形式读取 CSV，保留十六进制文本内容
[~, ~, ext] = fileparts(filePath);
if strcmpi(ext, '.csv')
    raw = readcell(filePath, 'Delimiter', ',');
else
    raw = readcell(filePath);
end
end

function firstDataRow = getFirstDataRow(raw)
%getFirstDataRow - 跳过表头及可选 Radix 行，定位首个数据行
% Vivado 原始 CSV 第 2 行通常是 Radix；Excel 另存后第 2 行通常就是数据。
firstDataRow = 2;
if size(raw, 1) >= 2 && ~isCellMissing(raw{2, 1})
    textValue = strtrim(char(raw{2, 1}));
    if strncmpi(textValue, 'Radix', 5)
        firstDataRow = 3;
    end
end
end

function code = parseHexColumn(values, adcBits)
%parseHexColumn - 将混合类型十六进制单元格解析为无符号 ADC 码
code = NaN(numel(values), 1);
for i = 1:numel(values)
    if isCellMissing(values{i})
        continue;
    end

    if isnumeric(values{i}) || islogical(values{i})
        textValue = sprintf('%.0f', double(values{i}));
    else
        textValue = strtrim(char(values{i}));
    end

    textValue = regexprep(textValue, '\s+', '');
    if startsWith(lower(textValue), '0x')
        textValue = textValue(3:end);
    end
    if isempty(textValue) || ~all(isstrprop(textValue, 'xdigit'))
        continue;
    end

    code(i) = mod(hex2dec(textValue), 2^adcBits);
end
end

function values = parseDecimalColumn(rawValues)
%parseDecimalColumn - 将 valid 等十进制列转换为 double 列向量
values = NaN(numel(rawValues), 1);
for i = 1:numel(rawValues)
    if isCellMissing(rawValues{i})
        continue;
    end
    if isnumeric(rawValues{i}) || islogical(rawValues{i})
        values(i) = double(rawValues{i});
    else
        values(i) = str2double(strtrim(char(rawValues{i})));
    end
end
end

function signedCode = codeToSigned(unsignedCode, adcBits, outputCoding)
%codeToSigned - 按 ADC 输出码型把无符号码映射为有符号码
switch lower(outputCoding)
    case 'twos_complement'
        signedCode = double(unsignedCode);
        wrapMask = signedCode >= 2^(adcBits - 1);
        signedCode(wrapMask) = signedCode(wrapMask) - 2^adcBits;
    case 'offset_binary'
        signedCode = double(unsignedCode) - 2^(adcBits - 1);
    otherwise
        error('outputCoding must be twos_complement or offset_binary.');
end
end

function tf = isCellMissing(value)
%isCellMissing - 统一判断空单元格、missing 字符串和数值 NaN
try
    tf = ismissing(value);
    tf = all(tf(:));
catch
    tf = false;
end
end

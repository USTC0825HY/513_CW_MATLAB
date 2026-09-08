function result = dac_scale_hex_analysis(dataFolder, selectedFiles, outputFolder)
%DAC_SCALE_HEX_ANALYSIS Run the DA766 scale analysis for hexadecimal codes.
%   This device adapter keeps the calculation in converter.dac.runScale,
%   while fixing the DA766 capture naming and code interpretation:
%       raw hexadecimal code -> signed 16-bit decimal code
%       CodePp = 2 * abs(signed code)
%
%   The adapter is intentionally separate from dac_scale_analysis so the
%   original DA766 entry point keeps its existing defaults.

if nargin < 1 || isempty(dataFolder)
    dataFolder = fullfile('F:', filesep, '01_Laser', ...
        '0_20260727_513test', 'CW_Data', '513_CW_DATA', 'DA766', '06_scale');
end
dataFolder = char(dataFolder);
if ~isfolder(dataFolder)
    error('cw513:DataFolderMissing', 'DA766刻度数据目录不存在：%s', dataFolder);
end
if nargin < 2, selectedFiles = {}; end
if nargin < 3, outputFolder = []; end

bootstrapRuntime();
if isempty(selectedFiles)
    [selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, [], ...
        '选择本次 DA766 十六进制刻度 MAT（可多选；不要选历史 CH2）');
end
if isempty(selectedFiles)
    result = struct([]);
    return;
end
if ischar(selectedFiles) || isstring(selectedFiles)
    selectedFiles = cellstr(selectedFiles);
end

configOverride = struct( ...
    'codeNameFormat', 'hex_unsigned', ...
    'codeVppDefinition', 'twice_abs_signed_code', ...
    'codeConversionRule', ...
        'raw 16-bit hex >= 0x8000: signed = raw - 0x10000; otherwise signed = raw', ...
    'toneFrequencyHz', 1525, ...
    'hardwareGain', 1, ...
    'minimumFitR2', 0.98, ...
    'minimumCodeVpp', 512, ...
    'maximumCodeVpp', 2^16, ...
    'formalEnabled', false, ...
    'referencePlane', ...
        'DA766 output; PicoScope A voltage waveform; termination not recorded', ...
    'calibrationSource', ...
        'PicoScope MAT A/Tinterval; CODE token interpreted as unsigned 16-bit hex');

% Keep run_info.sampleRate tied to measured evidence.  The measurements
% table still records the actual rate for every capture independently.
firstFile = localFirstFile(dataFolder, selectedFiles{1});
firstCapture = converter.io.loadPicoMat(firstFile, '', 1, true);
configOverride.sampleRate = firstCapture.sampleRateHz;
configOverride.sampleRateSource = ...
    'first selected MAT Tinterval; per-file sample_rate_hz retained in table';

result = dac_scale_analysis(dataFolder, selectedFiles, outputFolder, configOverride);
end

function filePath = localFirstFile(dataFolder, selectedFile)
if isfile(selectedFile)
    filePath = char(selectedFile);
else
    filePath = fullfile(dataFolder, char(selectedFile));
end
if ~isfile(filePath)
    error('cw513:ScaleFileMissing', '选定的DA766刻度文件不存在：%s', filePath);
end
end

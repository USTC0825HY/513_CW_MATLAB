function result = dac_scale_hex_analysis(dataFolder, selectedFiles, outputFolder, toneFrequencyHz)
%DAC_SCALE_HEX_ANALYSIS Run the DA766 scale analysis for hexadecimal codes.
%   This device adapter keeps the calculation in converter.dac.runScale,
%   while fixing the DA766 capture naming and code interpretation:
%       raw hexadecimal code -> signed 16-bit decimal code
%       CodePp = 2 * abs(signed code)
%
%   TONEFREQUENCYHZ optionally overrides the assumed 1525 Hz tone: the
%   20260924 retest captures (FTW_2 at the 250 kS/s PICO setting) generate
%   1525.88 Hz, and a fixed-frequency fit at 1525 Hz degrades R2 below the
%   quality gate.  Refine the tone from a capture (e.g. via
%   converter.adc.refineSineFrequency) and pass it here when the batch's
%   actual tone differs.
%
%   The adapter is intentionally separate from dac_scale_analysis so the
%   original DA766 entry point keeps its existing defaults.

if nargin < 1 || isempty(dataFolder)
    dataFolder = fullfile('I:', filesep, '513_CW_test', 'CW_Data', ...
        '513_CW_DATA_jianding', 'DA766', '06_scale');
end
dataFolder = char(dataFolder);
if nargin < 2, selectedFiles = {}; end
if nargin < 3, outputFolder = []; end
if nargin < 4, toneFrequencyHz = []; end

bootstrapRuntime();
[selectedFiles, dataFolder] = converter.io.selectMatFiles(dataFolder, selectedFiles, ...
        '选择本次 DA766 十六进制刻度 MAT（可多选；标准批次和 CH2 批次不要混选）');
if isempty(selectedFiles)
    result = struct([]);
    return;
end
if ischar(selectedFiles) || isstring(selectedFiles)
    selectedFiles = cellstr(selectedFiles);
end
localValidateCaptureSet(selectedFiles);

% The 20260918 jiaqiang batch names the code as AMP_<hex> in files like
% X7-FS_19.5MS-AMP_7FFF-FTW_0002.mat instead of CODE_<hex>.  Pick the code
% token set from the actual file names so both batches run unchanged.
% NOTE: probe per file on a CHAR scalar.  regexpi on string/cell arrays
% returns "" scalars for non-matches in recent releases, and
% isempty("") is false, which would make hasCodeToken always true.
names = cellstr(string(selectedFiles(:)));
hasCodeToken = false;
hasAmpToken = false;
for probeIndex = 1:numel(names)
    probe = char(names{probeIndex});
    if ~isempty(regexpi(probe, '(?:code|coade)[_-]?[0-9a-f]+', 'once'))
        hasCodeToken = true;
    elseif ~isempty(regexpi(probe, 'amp[_-]?[0-9a-f]+', 'once'))
        hasAmpToken = true;
    end
end

if hasCodeToken && hasAmpToken
    error('cw513:MixedScaleNaming', ...
        'CODE/COADE批次和AMP批次请分开选择，避免混合码值定义或采集条件。');
end
configOverride = struct( ...
    'version', '0.1.1', ...
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
        'DA766 output; actual PicoScope channel recorded per measurement; termination not recorded', ...
    'calibrationSource', ...
        'PicoScope MAT waveform/Tinterval; hex code token interpreted as unsigned 16-bit');
if hasAmpToken
    configOverride.codeNameTokens = {'amp'};
    configOverride.calibrationSource = ...
        'PicoScope MAT waveform/Tinterval; AMP token interpreted as unsigned 16-bit hex';
    fprintf('DA766 加强件刻度命名：码值取自 AMP_<hex> 标记。\n');
end

% Keep run_info.sampleRate tied to measured evidence.  The measurements
% table still records the actual rate for every capture independently.
firstFile = localFirstFile(dataFolder, selectedFiles{1});
firstCapture = converter.io.loadPicoMat(firstFile, '', 1, true);
configOverride.sampleRate = firstCapture.sampleRateHz;
configOverride.sampleRateSource = ...
    'first selected MAT Tinterval; per-file sample_rate_hz retained in table';
if ~isempty(toneFrequencyHz)
    validateattributes(toneFrequencyHz, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        'dac_scale_hex_analysis', 'toneFrequencyHz');
    configOverride.toneFrequencyHz = double(toneFrequencyHz);
    configOverride.toneFrequencySource = ...
        sprintf('caller-provided refined tone %.9g Hz', double(toneFrequencyHz));
end

result = dac_scale_analysis(dataFolder, selectedFiles, outputFolder, configOverride);
end

function localValidateCaptureSet(selectedFiles)
names = string(selectedFiles(:));
isCh2 = ~cellfun('isempty', regexpi(cellstr(names), '_CH2\.mat$'));
if any(isCh2) && any(~isCh2)
    error('cw513:MixedScaleCaptureSets', ...
        ['DA766 标准 A 通道文件与历史 CH2/B 通道文件不能在同一次刻度中混选。' ...
         '请只选择其中一批。']);
end
end

function filePath = localFirstFile(dataFolder, selectedFile)
filePath = converter.io.resolveInputPath(dataFolder, selectedFile);
if ~isfile(filePath)
    error('cw513:ScaleFileMissing', '选定的DA766刻度文件不存在：%s', filePath);
end
end

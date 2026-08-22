%S08_CALIBRATE_DAC_MULTI_SINE Compatibility adapter for CW_513_ANALYSIS.
%   The historical implementation is archived under
%   archive/legacy_20260816_cw513_pre_refactor.  This entry only builds a
%   configuration and delegates the calculation to the portable library.

workflowFolder = fileparts(mfilename('fullpath'));
laserAnalysisFolder = fileparts(fileparts(workflowFolder));
cwRoot = fullfile(fileparts(laserAnalysisFolder), '513DIANXING_analysis', ...
    'CW_analysis', 'CW_513_ANALYSIS');
if ~isfolder(cwRoot)
    error('cw513:LibraryMissing', ...
        '需要先添加 CW_513_ANALYSIS 分析库路径：%s', cwRoot);
end
addpath(fullfile(cwRoot, '_shared'));
addpath(fullfile(cwRoot, '9726_hy'));

dataFolder = getenv('S08_DAC_DATA_DIR');
if isempty(dataFolder)
    dataFolder = uigetdir(pwd, '选择DAC刻度MAT目录');
end
if isequal(dataFolder, 0)
    error('cw513:SelectionCancelled', '已取消数据目录选择。');
end
outputFolder = fullfile(char(dataFolder), 'results');
outputText = getenv('S08_OUTPUT_DIR');
if ~isempty(outputText)
    outputFolder = char(outputText);
end

% Preserve the historical defaults, while allowing measured acquisition
% parameters and the current hexadecimal MAT naming convention to be
% supplied by the compatibility caller.  The calculation remains in the
% portable CW_513_ANALYSIS library.
override = struct('toneFrequencyHz', 1e3, 'hardwareGain', 1);
toneText = getenv('S08_TONE_FREQUENCY_HZ');
if ~isempty(toneText)
    toneValue = str2double(toneText);
    if isfinite(toneValue) && toneValue > 0
        override.toneFrequencyHz = toneValue;
    else
        error('cw513:InvalidToneFrequency', ...
            'S08_TONE_FREQUENCY_HZ必须为正数：%s', toneText);
    end
end
sampleRateText = getenv('S08_SAMPLE_RATE_HZ');
if ~isempty(sampleRateText)
    sampleRateValue = str2double(sampleRateText);
    if isfinite(sampleRateValue) && sampleRateValue > 0
        override.sampleRate = sampleRateValue;
    else
        error('cw513:InvalidSampleRate', ...
            'S08_SAMPLE_RATE_HZ必须为正数：%s', sampleRateText);
    end
end
codeFormatText = getenv('S08_CODE_NAME_FORMAT');
if ~isempty(codeFormatText)
    override.codeNameFormat = char(codeFormatText);
end
codeVppText = getenv('S08_CODE_VPP_DEFINITION');
if ~isempty(codeVppText)
    override.codeVppDefinition = char(codeVppText);
end
excludedText = getenv('S08_EXCLUDED_SIGNED_CODES');
if ~isempty(excludedText)
    override.excludedSignedCodes = sscanf(strrep(excludedText, ',', ' '), '%f').';
end
result = dac_scale_analysis(dataFolder, {}, outputFolder, override);
results = result.measurements;
summary = result.summary;
cfg = result.config;
outputDir = result.outputFolder;
fprintf('CW_513_ANALYSIS刻度适配完成：%s\n', outputDir);

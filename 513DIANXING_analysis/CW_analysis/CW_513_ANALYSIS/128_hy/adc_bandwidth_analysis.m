function results = adc_bandwidth_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_BANDWIDTH_ANALYSIS Fit ADC128 unipolar CSV sweeps and find -3 dB bandwidth.
%   R = ADC_BANDWIDTH_ANALYSIS(D, FILES, OUT, struct('sampleRate', FS))
%   uses the rate of the samples stored in CSV (Hz). Default data column is
%   4, containing unsigned decimal codes 0..4095. Each filename must contain
%   its injected frequency, e.g. ADC128_1kHz.csv. Keep input Vpp constant.
%   With no arguments, select files and enter the capture rate and column.
%   Positive DC offset is fitted independently of sine peak-to-peak size.
bootstrapRuntime();
interactive = nargin == 0;
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, ~] = converter.runtime.applyRunOptions(adc128Config(), runOptions);
if interactive
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, '选择同一ADC128通道的扫频CSV');
    if isempty(selectedFiles), results = table; return; end
    answer = inputdlg({'CSV相邻样点采样率 / Hz（按实际采集设置）', ...
        'ADC码值列号（1起始）'}, 'ADC128采集参数', 1, {'', '4'});
    if isempty(answer), results = table; return; end
    config.sampleRate = str2double(answer{1});
    config.adcDataColumn = str2double(answer{2});
end
validateattributes(config.sampleRate, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, mfilename, 'sampleRate');
validateattributes(config.adcDataColumn, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, mfilename, 'adcDataColumn');
if config.adcBits ~= 12 || ~strcmpi(config.adcCodeFormat, 'unsigned')
    error('adc128:CodeFormat', '本入口要求12 bit unsigned码，范围0～4095。');
end
% Validate format and coverage before the shared workflow creates outputs.
[selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
    dataFolder, selectedFiles, '选择同一ADC128通道的扫频CSV');
if isempty(selectedFiles), results = table; return; end
frequencies = cellfun(@converter.io.parseFrequencyHz, selectedFiles);
if any(~isfinite(frequencies) | frequencies <= 0 | frequencies >= config.sampleRate / 2)
    error('adc128:FrequencyRange', ...
        '文件名须含Hz/kHz/MHz频率，且输入频率必须低于所填采样率的一半。');
end
if numel(unique(frequencies)) ~= numel(frequencies)
    error('adc128:DuplicateFrequency', '请每个频率选择一份CSV，不要混选多个通道或重复记录。');
end
for k = 1:numel(selectedFiles)
    path = converter.io.resolveInputPath(dataFolder, selectedFiles{k});
    code = converter.io.readAdcCsv(path, config);
    if any(code < -2048 | code > 2047 | code ~= fix(code))
        error('adc128:CodeRange', 'CSV必须包含0～4095的整数原始码：%s', path);
    end
end
results = converter.adc.runBandwidth(config, dataFolder, selectedFiles, outputFolder);
end

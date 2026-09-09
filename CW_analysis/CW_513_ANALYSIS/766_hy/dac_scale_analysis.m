function result = dac_scale_analysis(dataFolder, selectedFiles, outputFolder, configOverride)
%DAC_SCALE_ANALYSIS Select DA766 MAT captures and run the existing scale core.
%   Empty files opens a chooser. Explicit files/config.inputFiles suppress UI.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
defaultFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'DA766', '06_scale');
[config, cancelled] = converter.io.prepareDacInputs( ...
    da766Config('scale'), dataFolder, selectedFiles, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
localRequireMatchingEntry(config);
result = converter.dac.runScale(config);
end

function localRequireMatchingEntry(config)
if ~strcmpi(config.codeNameFormat, 'signed_decimal')
    return;
end
names = cellstr(config.inputFiles);
isSignedDecimal = ~cellfun('isempty', regexp(names, ...
    '(?i)code_-?\d+(?=[_-]|\.mat$)', 'once'));
if any(~isSignedDecimal)
    error('cw513:UseHexScaleEntry', ...
        ['所选DA766文件使用CODE/COADE十六进制命名。请改为运行 ' ...
         'dac_scale_hex_analysis，并且不要混选标准A批次与_CH2/B批次。']);
end
end

function result = dac_isolation_analysis(dataFolder, pairManifest, outputFolder, configOverride)
%DAC_ISOLATION_ANALYSIS Select a reference/victim MAT pair with explicit conditions.
%   Explicit struct/table/CSV pairs run without dialogs; each row declares
%   driven/victim files, variables, labels, frequency and reference_plane.
bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2, pairManifest = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, configOverride = struct(); end
defaultFolder = fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'DA9726', '05_Isolation');
[config, cancelled] = converter.io.prepareDacIsolation( ...
    da9726Config('isolation'), dataFolder, pairManifest, ...
    outputFolder, configOverride, defaultFolder);
if cancelled, result = struct([]); return; end
result = converter.dac.runIsolation(config);
end

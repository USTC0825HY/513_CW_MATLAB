function result = dac_isolation_analysis(dataFolder, pairManifest, outputFolder, configOverride)
%DAC_ISOLATION_ANALYSIS Analyze one driven output against multiple victims.
%   With no manifest, select one driven MAT and then all victim MAT files.
%   Interface, waveform variable, tone frequency, and gain are automatic.
%   Explicit struct/table/CSV pair manifests remain supported without UI.
%   Use split_dac_isolation_channels first for a multi-channel Pico MAT.
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

function results = adc_power_scale_analysis(dataFolder, selectedFiles, outputFolder, runOptions)
%ADC_POWER_SCALE_ANALYSIS Run the fixed AD9245 CodePp-to-Vpp analysis.
%   RESULTS = ADC_POWER_SCALE_ANALYSIS() prompts for a data directory and
%   CSV files, then writes a new timestamped result directory.
%   RESULTS = ADC_POWER_SCALE_ANALYSIS(DATAFOLDER) auto-scans *.csv in
%   DATAFOLDER without any dialog; pass (DATAFOLDER, FILES) for an explicit
%   selection. Filename setpoints may be dBm- or Vpp-labelled.

bootstrapRuntime();
if nargin < 1, dataFolder = []; end
if nargin < 2 || isempty(selectedFiles), selectedFiles = []; end
if nargin < 3, outputFolder = []; end
if nargin < 4, runOptions = []; end
[config, runOptions] = converter.runtime.applyRunOptions( ...
    ad9245Config('power_scale'), runOptions);
if isempty(dataFolder) && isempty(selectedFiles)
    [selectedFiles, dataFolder] = converter.io.selectCsvFiles( ...
        dataFolder, selectedFiles, '选择AD9245功率刻度CSV（可多选）');
    if isempty(selectedFiles), results = table; return; end
elseif isempty(selectedFiles)
    listing = dir(fullfile(char(dataFolder), '*.csv'));
    selectedFiles = sort({listing.name});
    if isempty(selectedFiles)
        error('ad9245:NoCsvFiles', '数据目录中没有CSV文件：%s', dataFolder);
    end
end
% Calibration safety and report layout are fixed at the formal AD9245
% entrypoint.  The shared kernel determines the last available non-clipped
% power point and rejects every near-rail capture from the fit; the report
% figure contains only the inverse Vpp-to-CodePp panel.
config.autoSelectPowerRangeFromUnclipped = true;
config.powerScalePlotMode = 'inverse';
results = converter.adc.runPowerScale(config, dataFolder, selectedFiles, ...
    outputFolder, runOptions);
end

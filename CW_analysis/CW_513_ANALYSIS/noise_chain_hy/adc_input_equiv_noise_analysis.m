function result = adc_input_equiv_noise_analysis(runConfig)
%ADC_INPUT_EQUIV_NOISE_ANALYSIS Formal CW_513_ANALYSIS 1 Hz input-equivalent ASD.
%   S_in(f) = S_PICO(f) * (k_ADC/(abs(G_FPGA)*k_DAC))^2.
%   k_ADC and k_DAC are Vpp/CodePp calibration slopes.  The default
%   baseline mode is 'none': PICO/DAC baseline is intentionally not removed.

bootstrapFormalRuntime();
if nargin < 1 || isempty(runConfig)
    runConfig = localDefaultConfig();
else
    runConfig = localMergeDefaults(localDefaultConfig(), runConfig);
end

runFolder = localCreateRunFolder(runConfig.outputRoot, runConfig.analysisId);
runConfig.outputFolder = runFolder;
mkdir(runFolder);
calibration = localLoadCalibration(runConfig);
rows = repmat(localEmptyRow(), numel(runConfig.entries), 1);
manifest = localManifestSeed(runConfig, calibration);

for k = 1:numel(runConfig.entries)
    entry = runConfig.entries(k);
    row = localEmptyRow();
    row.device = string(entry.device);
    row.interface = string(entry.interface);
    row.input_file = string(entry.matFile);
    row.input_path = string(entry.matFile);
    row.baseline_mode = string(runConfig.baselineMode);
    row.fpga_gain = runConfig.fpgaGain;
    row.reference_plane = string(runConfig.referencePlane);
    row.calibration_workbook = string(runConfig.calibrationWorkbook);
    row.dac_calibration_source = string(calibration.dacSummaryPath);
    row.k_dac_v_per_code = calibration.kDac;
    row.dac_intercept_v = calibration.dacIntercept;
    row.dac_r2 = calibration.dacR2;
    adcCalibration = localFindAdcCalibration(calibration.adcRows, ...
        entry.device, entry.interface);
    row.k_adc_v_per_code = adcCalibration.slope;
    row.adc_intercept_v = adcCalibration.intercept;
    row.adc_r2 = adcCalibration.r2;
    row.calibration_data_group = string(adcCalibration.dataGroup);
    row.scale_adc_in_per_dac_out = adcCalibration.slope / ...
        (abs(runConfig.fpgaGain) * calibration.kDac);
    row.band = "0-Nyquist";
    row.analysis_band = "0-Nyquist";

    if ~isfile(entry.matFile)
        row.formal_state = "暂不能判定";
        row.note = "原始 MAT 文件不存在。";
        rows(k) = row;
        manifest(end + 1) = localManifestRow(entry.matFile, "missing", ""); %#ok<AGROW>
        continue;
    end

    fileInfo = dir(entry.matFile);
    row.file_size_bytes = fileInfo.bytes;
    row.source_sha256 = string(converter.runtime.sha256File(entry.matFile));
    manifest(end + 1) = localManifestRow(entry.matFile, "raw", row.source_sha256); %#ok<AGROW>
    [complete, integrityNote] = localCheckMatCompleteness(entry.matFile);
    if ~complete
        row.formal_state = "暂不能判定";
        row.note = string(integrityNote);
        rows(k) = row;
        continue;
    end

    try
        capture = converter.io.loadPicoMat(entry.matFile, 'A', 1, true);
        [frequencyHz, psdPico, asdPico, setup] = localWelch( ...
            capture.voltage, capture.sampleRateHz, runConfig.welch);
        psdInput = psdPico .* (row.scale_adc_in_per_dac_out ^ 2);
        asdInput_nV = sqrt(max(psdInput, 0)) * 1e9;
        [actualHz, idx] = localNearestBin(frequencyHz, runConfig.asdCheckHz);
        segmentAsd = localSegmentAsdAtBin(capture.voltage, ...
            capture.sampleRateHz, setup, idx, row.scale_adc_in_per_dac_out);

        row.sample_rate_hz = capture.sampleRateHz;
        row.nyquist_hz = capture.sampleRateHz / 2;
        row.sample_count = capture.sampleCount;
        row.duration_s = capture.sampleCount / capture.sampleRateHz;
        row.welch_window_samples = setup.windowLength;
        row.welch_overlap_samples = setup.overlapLength;
        row.welch_nfft = setup.nfft;
        row.frequency_resolution_hz = setup.resolutionHz;
        row.welch_segment_count = setup.segmentCount;
        row.asd_check_requested_hz = runConfig.asdCheckHz;
        row.asd_check_actual_hz = actualHz;
        row.pico_asd_at_check_v_per_sqrt_hz = asdPico(idx);
        row.input_asd_at_check_n_v_per_sqrt_hz = asdInput_nV(idx);
        row.segment_asd_min_n_v_per_sqrt_hz = min(segmentAsd, [], 'omitnan');
        row.segment_asd_mean_n_v_per_sqrt_hz = mean(segmentAsd, 'omitnan');
        row.segment_asd_max_n_v_per_sqrt_hz = max(segmentAsd, [], 'omitnan');
        row.segment_asd_cv = std(segmentAsd, 'omitnan') / ...
            mean(segmentAsd, 'omitnan');
        row.formal_state = "未测试";
        row.note = "按校准斜率折算；未扣除 PICO/DAC 本底。";

        safeStem = regexprep(sprintf('%s_%s', char(entry.device), ...
            char(entry.interface)), '[^A-Za-z0-9_-]', '_');
        spectrumPath = fullfile(runFolder, [safeStem '_full_PSD_ASD.csv']);
        band = repmat("0-Nyquist", numel(frequencyHz), 1);
        spectrumTable = table(frequencyHz, psdPico, asdPico, psdInput, ...
            asdInput_nV, band, 'VariableNames', {'frequency_hz', ...
            'pico_psd_v2_per_hz', 'pico_asd_v_per_sqrt_hz', ...
            'input_equiv_psd_v2_per_hz', 'input_equiv_asd_nV_per_sqrt_hz', ...
            'analysis_band'});
        converter.report.writeTable(spectrumTable, spectrumPath);
        row.spectrum_file = string(spectrumPath);

        plotStem = fullfile(runFolder, [safeStem '_input_equiv_ASD']);
        plotConfig = struct();
        interfaceLabel = strrep(char(entry.interface), '_', '/');
        plotConfig.titleText = sprintf('%s | ADC input-equivalent ASD', ...
            interfaceLabel);
        % Keep the low-frequency ADC input-equivalent plot on the same
        % visual/axis contract as the current DA9726 noise figures.  This
        % profile permits the x-axis to begin at 10^-1 Hz when the capture
        % contains sub-hertz bins; it does not alter the numerical method.
        plotConfig.styleProfile = 'da9726_legacy_visual_adapter';
        % Show the full low-frequency decade down to 10^-1 Hz.  The first
        % measured bin is 0.2 Hz; the 0.1 Hz lower axis limit is only a
        % plotting extent and must not be interpreted as measured data.
        plotConfig.xLim = [0.1, max(frequencyHz(2:end))];
        plotConfig.yLabel = 'ADC input-equivalent ASD (µV/√Hz)';
        plotConfig.lineLabel = 'ASD';
        plotConfig.limitValue = 10;
        plotConfig.limitLabel = '10 µV/√Hz';
        plotConfig.showLimitLabel = true;
        plotConfig.showLegend = false;
        plotConfig.checkFrequencyHz = actualHz;
        plotConfig.checkValue = asdInput_nV(idx) / 1e3;
        plotConfig.checkValueLabel = sprintf('1 Hz: %.3f µV/√Hz', ...
            asdInput_nV(idx) / 1e3);
        plotConfig.annotationText = '';
        converter.report.plotSpectrum(frequencyHz(2:end), ...
            asdInput_nV(2:end) / 1e3, ...
            plotStem, plotConfig);
        row.asd_plot_file = string([plotStem '.png']);

        psdStem = fullfile(runFolder, [safeStem '_input_equiv_PSD']);
        plotConfig = struct();
        plotConfig.titleText = sprintf('%s | %s | input-equivalent PSD', ...
            entry.device, entry.interface);
        plotConfig.yLabel = 'ADC input-equivalent PSD (V^2/Hz)';
        plotConfig.lineLabel = '输入等效 PSD';
        plotConfig.limitValue = (10000e-9)^2;
        plotConfig.limitLabel = '1 Hz ASD 限值对应 PSD';
        plotConfig.checkFrequencyHz = actualHz;
        plotConfig.checkValue = psdInput(idx);
        plotConfig.checkLabel = '实测 1 Hz';
        converter.report.plotSpectrum(frequencyHz(2:end), psdInput(2:end), ...
            psdStem, plotConfig);
        row.psd_plot_file = string([psdStem '.png']);
    catch exception
        row.formal_state = "暂不能判定";
        row.note = "MAT 可读性或频谱计算失败：" + string(exception.message);
    end
    rows(k) = row;
end

summary = struct2table(rows);
converter.report.writeTable(summary, fullfile(runFolder, 'input_equiv_noise_summary.csv'));
converter.report.writeTable(localParametersTable(runConfig, calibration), ...
    fullfile(runFolder, 'analysis_parameters.csv'));
converter.report.writeTable(struct2table(manifest), ...
    fullfile(runFolder, 'source_manifest.csv'));
localWriteReadme(runFolder, runConfig, calibration, summary);
save(fullfile(runFolder, 'adc_input_equiv_noise_result.mat'), ...
    'runConfig', 'calibration', 'summary', 'manifest', '-v7.3');
localWriteRunInfo(runFolder, runConfig, summary);
result = struct('runFolder', runFolder, 'summary', summary, ...
    'calibration', calibration, 'manifest', manifest, 'config', runConfig);
save(fullfile(runFolder, 'result.mat'), 'result', '-v7.3');
fprintf('Saved ADC input-equivalent noise bundle: %s\n', runFolder);
end

function cfg = localDefaultConfig()
cfg = struct();
cfg.analysisId = 'adc_input_equiv_noise';
cfg.version = '1.2.0';
cfg.outputRoot = fullfile('F:', '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA', 'results');
cfg.baselineMode = 'none';
cfg.fpgaGain = 128;
cfg.asdCheckHz = 1;
cfg.referencePlane = 'ADC external board input';
cfg.plotDpi = 180;
cfg.calibrationWorkbook = fullfile('F:', '01_Laser', ...
    '0_20260727_513test', 'CW_Data', '513_CW_DATA', ...
    'CW_513_ANALYSIS_AD2208_AD9245_刻度参数_20260822.xlsx');
cfg.dacSummaryPath = '';
cfg.welch = struct('targetResolutionHz', 0.2, 'overlapRatio', 0.5, ...
    'windowType', 'hann');
root = fullfile('F:', '01_Laser', '0_20260727_513test', ...
    'CW_Data', '513_CW_DATA');
cfg.entries = [ ...
    localEntry('AD9245', 'X1G', fullfile(root, 'AD9245', '01_noise', ...
        'X1G', 'X1G_100KSPS_CH1_G128.mat')); ...
    localEntry('AD9245', 'X2G', fullfile(root, 'AD9245', '01_noise', ...
        'X2G', 'X2G_100KSPS_CH1_G128.mat')); ...
    localEntry('AD9245', 'X3G', fullfile(root, 'AD9245', '01_noise', ...
        'X3G', 'X3G_100KSPS_CH1_G128.mat')); ...
    localEntry('AD9245', 'X4G', fullfile(root, 'AD9245', '01_noise', ...
        'X4G', 'X4G_100KSPS_CH1_G128.mat')); ...
    localEntry('AD2208', 'ADC6_JG24', fullfile(root, 'AD2208', ...
        '06_Noise', '02_1Hz_PICO', 'ADC6_JG24', 'raw', ...
        'JG24_128_250ksps_20s_2Vdiv.mat'))];
end

function entry = localEntry(device, interfaceName, matFile)
entry = struct('device', device, 'interface', interfaceName, 'matFile', matFile);
end

function cfg = localMergeDefaults(defaults, override)
cfg = defaults;
names = fieldnames(override);
for k = 1:numel(names)
    cfg.(names{k}) = override.(names{k});
end
end

function calibration = localLoadCalibration(cfg)
if ~isfile(cfg.calibrationWorkbook)
    error('cw513:CalibrationMissing', '刻度工作簿不存在：%s', cfg.calibrationWorkbook);
end
cells = readcell(cfg.calibrationWorkbook, 'Sheet', '刻度参数');
adcRows = struct('device', {}, 'interface', {}, 'slope', {}, ...
    'intercept', {}, 'r2', {}, 'dataGroup', {});
for r = 3:size(cells, 1)
    if isempty(cells{r, 1}) || isempty(cells{r, 2})
        continue;
    end
    adcRows(end + 1) = struct( ...
        'device', char(string(cells{r, 1})), ...
        'interface', char(string(cells{r, 2})), ...
        'slope', double(cells{r, 4}), ...
        'intercept', double(cells{r, 5}), ...
        'r2', double(cells{r, 6}), ...
        'dataGroup', char(string(cells{r, 3}))); %#ok<AGROW>
end
if isfield(cfg, 'kDacVPerCodePp') && ~isempty(cfg.kDacVPerCodePp)
    % A task-specific entry may intentionally pin k_DAC when the requested
    % analysis must use a supplied value instead of locating a CSV summary.
    kDac = double(cfg.kDacVPerCodePp);
    if ~isscalar(kDac) || ~isfinite(kDac) || kDac <= 0
        error('cw513:InvalidFixedDacCalibration', ...
            'kDacVPerCodePp 必须是有限的正标量，单位为 V/CodePp。');
    end
    if isfield(cfg, 'dacCalibrationSource') && ...
            strlength(string(cfg.dacCalibrationSource)) > 0
        dacSource = char(string(cfg.dacCalibrationSource));
    else
        dacSource = sprintf('Fixed configuration: k_DAC = %.15g V/CodePp', kDac);
    end
    dacSourceSha256 = '';
    dacIntercept = NaN;
    dacR2 = NaN;
else
    if isempty(cfg.dacSummaryPath)
        base = fileparts(cfg.calibrationWorkbook);
        candidates = [dir(fullfile(base, 'DA9726', 'sin_scale', ...
            'DAC1_JG18', 'result', 'run_*_scale', 'dac_scale_summary.csv')); ...
            dir(fullfile(base, 'DA9726', 'sin_scale', ...
            'DAC1_JG18', 'results', 'run_*_scale', 'dac_scale_summary.csv'))];
        if isempty(candidates)
            error('cw513:DacCalibrationMissing', '未找到 DA9726 JG18 刻度汇总。');
        end
        [~, order] = sort([candidates.datenum], 'descend');
        cfg.dacSummaryPath = fullfile(candidates(order(1)).folder, ...
            candidates(order(1)).name);
    end
    dacTable = readtable(cfg.dacSummaryPath, 'TextType', 'string');
    dacSource = cfg.dacSummaryPath;
    dacSourceSha256 = converter.runtime.sha256File(cfg.dacSummaryPath);
    kDac = double(dacTable.slope_v_per_code_vpp(1));
    dacIntercept = double(dacTable.intercept_v(1));
    dacR2 = double(dacTable.fit_r_squared(1));
end
calibration = struct('adcRows', adcRows, ...
    'workbookPath', cfg.calibrationWorkbook, ...
    'workbookSha256', converter.runtime.sha256File(cfg.calibrationWorkbook), ...
    'dacSummaryPath', dacSource, ...
    'dacSummarySha256', dacSourceSha256, ...
    'kDac', kDac, ...
    'dacIntercept', dacIntercept, ...
    'dacR2', dacR2);
end

function row = localFindAdcCalibration(rows, device, interfaceName)
mask = strcmp({rows.device}, device) & strcmp({rows.interface}, interfaceName);
matches = rows(mask);
if numel(matches) ~= 1
    error('cw513:AdcCalibrationAmbiguous', ...
        '刻度工作簿中 %s/%s 匹配到 %d 行。', device, interfaceName, numel(matches));
end
row = matches(1);
end

function [complete, note] = localCheckMatCompleteness(matFile)
complete = true; note = "";
try
    info = whos('-file', matFile);
    a = info(strcmp({info.name}, 'A'));
    if isempty(a)
        complete = false; note = "MAT 文件没有 A 通道变量。"; return;
    end
    fileInfo = dir(matFile);
    if fileInfo.bytes < a.bytes
        complete = false;
        note = sprintf('MAT 文件疑似截断：文件 %.0f bytes，小于 A 变量声明 %.0f bytes。', ...
            fileInfo.bytes, a.bytes);
    end
catch exception
    complete = false;
    note = "MAT 文件完整性检查失败：" + string(exception.message);
end
end

function [frequencyHz, psd, asd, setup] = localWelch(y, fs, cfg)
n = numel(y);
windowLength = max(16, min(n, floor(fs / cfg.targetResolutionHz)));
overlap = min(floor(windowLength * cfg.overlapRatio), windowLength - 1);
window = hann(windowLength, 'periodic');
nfft = windowLength;
[psd, frequencyHz] = pwelch(y, window, overlap, nfft, fs);
step = windowLength - overlap;
setup = struct('windowLength', windowLength, 'overlapLength', overlap, ...
    'nfft', nfft, 'resolutionHz', fs / nfft, ...
    'segmentCount', 1 + floor((n - windowLength) / step));
asd = sqrt(max(psd, 0));
end

function [actualHz, index] = localNearestBin(frequencyHz, requestedHz)
[~, index] = min(abs(frequencyHz - requestedHz));
actualHz = frequencyHz(index);
end

function values = localSegmentAsdAtBin(y, fs, setup, index, scale)
step = setup.windowLength - setup.overlapLength;
starts = 1:step:(numel(y) - setup.windowLength + 1);
window = hann(setup.windowLength, 'periodic');
values = NaN(numel(starts), 1);
for k = 1:numel(starts)
    segment = y(starts(k):starts(k) + setup.windowLength - 1);
    segment = segment - mean(segment);
    [p, ~] = periodogram(segment, window, setup.nfft, fs);
    values(k) = sqrt(max(p(index), 0)) * scale * 1e9;
end
end

function row = localEmptyRow()
row = struct('device', "", 'interface', "", 'input_file', "", ...
    'input_path', "", 'file_size_bytes', NaN, 'source_sha256', "", ...
    'calibration_workbook', "", 'calibration_data_group', "", ...
    'k_adc_v_per_code', NaN, 'adc_intercept_v', NaN, 'adc_r2', NaN, ...
    'dac_calibration_source', "", 'k_dac_v_per_code', NaN, ...
    'dac_intercept_v', NaN, 'dac_r2', NaN, 'fpga_gain', NaN, ...
    'scale_adc_in_per_dac_out', NaN, 'reference_plane', "", ...
    'sample_rate_hz', NaN, 'nyquist_hz', NaN, 'sample_count', NaN, ...
    'duration_s', NaN, 'welch_window_samples', NaN, ...
    'welch_overlap_samples', NaN, 'welch_nfft', NaN, ...
    'frequency_resolution_hz', NaN, 'welch_segment_count', NaN, ...
    'asd_check_requested_hz', NaN, 'asd_check_actual_hz', NaN, ...
    'pico_asd_at_check_v_per_sqrt_hz', NaN, ...
    'input_asd_at_check_n_v_per_sqrt_hz', NaN, ...
    'segment_asd_min_n_v_per_sqrt_hz', NaN, ...
    'segment_asd_mean_n_v_per_sqrt_hz', NaN, ...
    'segment_asd_max_n_v_per_sqrt_hz', NaN, 'segment_asd_cv', NaN, ...
    'baseline_mode', "", 'formal_state', "", 'note', "", ...
    'spectrum_file', "", 'asd_plot_file', "", 'psd_plot_file', "", ...
    'band', "", 'analysis_band', "");
end

function manifest = localManifestSeed(cfg, calibration)
manifest = localManifestRow(cfg.calibrationWorkbook, ...
    "calibration_workbook", calibration.workbookSha256);
if strlength(string(calibration.dacSummarySha256)) > 0
    manifest(end + 1) = localManifestRow(calibration.dacSummaryPath, ...
        "dac_calibration_summary", calibration.dacSummarySha256);
end
end

function row = localManifestRow(path, sourceType, sha256)
row = struct('source_type', string(sourceType), 'path', string(path), ...
    'size_bytes', NaN, 'sha256', string(sha256));
if isfile(path)
    info = dir(path); row.size_bytes = info.bytes;
end
end

function tableValue = localParametersTable(cfg, calibration)
parameter = ["analysis_id"; "version"; "formula"; "baseline_mode"; ...
    "fpga_gain"; "reference_plane"; "asd_check_hz"; ...
    "welch_target_resolution_hz"; "welch_overlap_ratio"; ...
    "calibration_workbook"; "calibration_workbook_sha256"; ...
    "dac_calibration_summary"; "dac_summary_sha256"; ...
    "k_dac_v_per_code"; "dac_intercept_v"; "dac_fit_r2"];
value = [string(cfg.analysisId); string(cfg.version); ...
    "S_in=S_PICO*(k_ADC/(abs(G_FPGA)*k_DAC))^2"; string(cfg.baselineMode); ...
    string(cfg.fpgaGain); string(cfg.referencePlane); string(cfg.asdCheckHz); ...
    string(cfg.welch.targetResolutionHz); string(cfg.welch.overlapRatio); ...
    string(cfg.calibrationWorkbook); string(calibration.workbookSha256); ...
    string(calibration.dacSummaryPath); string(calibration.dacSummarySha256); ...
    string(calibration.kDac); string(calibration.dacIntercept); ...
    string(calibration.dacR2)];
tableValue = table(parameter, value);
end

function localWriteReadme(folder, cfg, calibration, summary)
fileId = fopen(fullfile(folder, 'README.md'), 'w');
fprintf(fileId, '# CW 513 ADC 输入等效噪声 ASD 结果\n\n');
fprintf(fileId, '- 正式入口：`%s`\n', mfilename('fullpath'));
fprintf(fileId, '- 参考面：%s；FPGA 增益 G=%g。\n', cfg.referencePlane, cfg.fpgaGain);
fprintf(fileId, '- 公式：`S_in(f)=S_PICO(f)*(k_ADC/(abs(G_FPGA)*k_DAC))^2`。\n');
fprintf(fileId, '- 本次明确不扣除 PICO/DAC 本底；结果是总测量链路的 ADC 输入等效 ASD。\n');
fprintf(fileId, '- Welch：Hann 窗、50%% 重叠、目标分辨率约 %.6g Hz、去均值。\n', ...
    cfg.welch.targetResolutionHz);
fprintf(fileId, '- AD 斜率/R² 来自 `%s`；DA JG18 斜率 %.12g Vpp/CodePp，R² %.12g，来源 `%s`。\n', ...
    cfg.calibrationWorkbook, calibration.kDac, calibration.dacR2, calibration.dacSummaryPath);
fprintf(fileId, '\n## 数据完整性\n\n');
for k = 1:height(summary)
    fprintf(fileId, '- %s/%s：%s。%s\n', summary.device(k), ...
        summary.interface(k), summary.formal_state(k), summary.note(k));
end
fprintf(fileId, '\n截断或无法读取的 MAT 文件只保留审计记录，不进入正式 ASD 数值。\n');
fclose(fileId);
end

function localWriteRunInfo(folder, cfg, summary)
fileId = fopen(fullfile(folder, 'run_info.txt'), 'w');
fprintf(fileId, 'Analysis: %s\nVersion: %s\nStartedAt: %s\n', ...
    cfg.analysisId, cfg.version, datestr(now, 31));
fprintf(fileId, 'OutputFolder: %s\nFormula: S_in=S_PICO*(k_ADC/(abs(G_FPGA)*k_DAC))^2\n', folder);
fprintf(fileId, 'BaselineMode: %s\n', cfg.baselineMode);
fclose(fileId);
fileId = fopen(fullfile(folder, 'STATUS_SUCCESS.txt'), 'w');
fprintf(fileId, 'CompletedAt: %s\nSuccessful captures: %d/%d\n', ...
    datestr(now, 31), sum(summary.formal_state ~= "暂不能判定"), height(summary));
fclose(fileId);
end

function localSaveWhiteFigure(fig, stem, dpi)
% Export report figures with a deterministic white canvas and axes.
% Headless MATLAB renderers may otherwise apply a dark theme to axes even
% when the figure/axes Color properties are set to white.
set(fig, 'Color', [1 1 1], 'InvertHardcopy', 'on');
axesHandles = findall(fig, 'Type', 'axes');
for idx = 1:numel(axesHandles)
    ax = axesHandles(idx);
    set(ax, 'Color', [1 1 1], 'XColor', [0 0 0], 'YColor', [0 0 0], ...
        'ZColor', [0 0 0], 'GridColor', [0.70 0.70 0.70], ...
        'MinorGridColor', [0.85 0.85 0.85]);
    children = findall(ax);
    for childIdx = 1:numel(children)
        if isprop(children(childIdx), 'Color')
            tag = get(children(childIdx), 'Tag');
            if strcmpi(tag, 'legend')
                set(children(childIdx), 'Color', [1 1 1], ...
                    'TextColor', [0 0 0]);
            end
        end
    end
end
pngPath = [stem '.png'];
try
    exportgraphics(fig, pngPath, 'Resolution', dpi, ...
        'BackgroundColor', 'white');
catch
    % Fallback for older MATLAB releases without exportgraphics.
    print(fig, pngPath, '-dpng', sprintf('-r%d', dpi), '-opengl');
end
savefig(fig, [stem '.fig']);
end

function folder = localCreateRunFolder(root, analysisId)
if ~isfolder(root), mkdir(root); end
stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<DATST,TNOW1>
folder = fullfile(root, ['run_' stamp '_' lower(analysisId)]);
suffix = 1;
while isfolder(folder)
    folder = fullfile(root, sprintf('run_%s_%s_%02d', stamp, ...
        lower(analysisId), suffix));
    suffix = suffix + 1;
end
end

function bootstrapFormalRuntime()
thisFolder = fileparts(mfilename('fullpath'));
formalRoot = fileparts(thisFolder);
addpath(fullfile(formalRoot, '_shared'));
end

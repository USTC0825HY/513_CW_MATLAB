function result = runScale(config)
%RUNSCALE Analyze DAC code-to-output Vpp scale from Pico MAT files.
converter.runtime.validateConfig(config, ...
    {'deviceId', 'analysisId', 'version', 'dataFolder', 'outputFolder'});
files = localFiles(config);
if isempty(files), error('converter:dac:NoInputFiles', '没有找到刻度MAT文件。'); end
fileNames = arrayfun(@(f) fullfile(f.folder, f.name), files, 'UniformOutput', false);
runContext = converter.runtime.createRun(config, config.dataFolder, ...
    fileNames, config.outputFolder);
try
rows = repmat(localEmptyRow(), numel(files), 1);
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    codeInfo = localCodeFromName(files(k).name, config);
    capture = converter.io.loadPicoMat(path, localVariable(config, k), ...
        config.hardwareGain, true);
    fit = converter.dac.fitTone(capture.voltage, capture.sampleRateHz, ...
        config.toneFrequencyHz);
    rows(k).input_file = string(files(k).name);
    rows(k).input_path = string(path);
    rows(k).source_sha256 = string(converter.runtime.sha256File(path));
    rows(k).variable = string(capture.variableName);
    rows(k).raw_code = codeInfo.rawCode;
    rows(k).signed_code = codeInfo.signedCode;
    rows(k).code_vpp = codeInfo.codeVpp;
    rows(k).code_vpp_definition = string(codeInfo.codeVppDefinition);
    rows(k).sample_rate_hz = capture.sampleRateHz;
    rows(k).duration_s = capture.sampleCount / capture.sampleRateHz;
    rows(k).output_vpp_v = fit.vppV;
    rows(k).fit_r_squared = fit.rSquared;
    rows(k).fit_residual_rms_v = fit.residualRmsV;
    rows(k).included_in_fit = false;
    rows(k).exclusion_reason = "";
end
measurements = struct2table(rows);
fitMask = measurements.fit_r_squared >= config.minimumFitR2 & ...
    measurements.code_vpp >= config.minimumCodeVpp & ...
    measurements.code_vpp <= config.maximumCodeVpp;
if isfield(config, 'excludedSignedCodes') && ~isempty(config.excludedSignedCodes)
    fitMask = fitMask & ~ismember(measurements.signed_code, ...
        double(config.excludedSignedCodes));
end
measurements.included_in_fit = fitMask;
measurements.exclusion_reason(~fitMask) = "质量或码值范围不满足拟合门槛";
valid = fitMask & isfinite(measurements.code_vpp) & ...
    isfinite(measurements.output_vpp_v);
if nnz(valid) >= 2
    coefficient = polyfit(measurements.code_vpp(valid), ...
        measurements.output_vpp_v(valid), 1);
    fitted = polyval(coefficient, measurements.code_vpp(valid));
    residual = measurements.output_vpp_v(valid) - fitted;
    fitR2 = localR2(measurements.output_vpp_v(valid), residual);
    status = "已计算";
else
    coefficient = [NaN, NaN]; fitR2 = NaN; status = "未测试";
end
summary = table(string(config.deviceId), string(config.analysisId), ...
    coefficient(1), coefficient(2), fitR2, nnz(valid), string(status), ...
    'VariableNames', {'device','analysis','slope_v_per_code_vpp', ...
    'intercept_v','fit_r_squared','fit_point_count','status'});
converter.report.writeTable(measurements, fullfile(runContext.folder, ...
    'dac_scale_measurements.csv'));
converter.report.writeTable(summary, fullfile(runContext.folder, ...
    'dac_scale_summary.csv'));
converter.report.writeTable(localParameters(config), fullfile(runContext.folder, ...
    'analysis_parameters.csv'));
figureHandle = figure('Visible', 'off', 'Color', 'w');
plot(measurements.code_vpp, measurements.output_vpp_v, 'ko', ...
    'MarkerFaceColor', [0.1 0.4 0.8]); grid on; hold on;
if nnz(valid) >= 2
    x = linspace(min(measurements.code_vpp(valid)), ...
        max(measurements.code_vpp(valid)), 200);
    plot(x, polyval(coefficient, x), 'r-', 'LineWidth', 1.2);
    legend('测量点', '线性拟合', 'Location', 'best');
end
xlabel('DAC code Vpp (code)'); ylabel('Output Vpp (V)');
title(sprintf('%s DAC scale', config.deviceId), 'Interpreter', 'none');
converter.report.saveFigure(figureHandle, fullfile(runContext.folder, ...
    'dac_scale_fit'), 180); close(figureHandle);
result = struct('config', config, 'measurements', measurements, ...
    'summary', summary, 'outputFolder', runContext.folder);
save(fullfile(runContext.folder, 'dac_scale_result.mat'), 'result');
converter.runtime.finishRun(runContext, true, 'DA刻度分析完成');
catch exception
    converter.runtime.finishRun(runContext, false, exception.message);
    rethrow(exception);
end
end

function files = localFiles(config)
if isfield(config, 'inputFiles') && ~isempty(config.inputFiles)
    names = cellstr(config.inputFiles); files = struct([]);
    for k = 1:numel(names)
        item = dir(converter.io.resolveInputPath(config.dataFolder, names{k}));
        if isempty(item), error('converter:dac:InputMissing', ...
                '输入文件不存在：%s', names{k}); end
        files = [files; item]; %#ok<AGROW>
    end
else
    files = dir(fullfile(config.dataFolder, config.filePattern));
end
end

function variable = localVariable(config, index)
if isfield(config, 'dataVariables') && ~isempty(config.dataVariables)
    values = cellstr(config.dataVariables); variable = values{min(index, numel(values))};
else
    variable = '';
end
end

function codeInfo = localCodeFromName(fileName, config)
bits = config.dacCodeBits;
formatName = 'signed_decimal';
if isfield(config, 'codeNameFormat') && ~isempty(config.codeNameFormat)
    formatName = char(config.codeNameFormat);
end
switch lower(formatName)
    case 'hex_unsigned'
        % Read the first hexadecimal token immediately after CODE/COADE.
        % Acquisition metadata may follow it, for example _JG18_CH1 or
        % _CH2.  Requiring a separator (or the extension) after the token
        % prevents a partial match such as reading CODE7FFF as decimal 7.
        token = regexp(fileName, ...
            '(?i)(?:code|coade)[_-]?([0-9a-f]+)(?=[_-]|\.mat$)', ...
            'tokens', 'once');
        if isempty(token)
            error('converter:dac:CodeMissing', ...
                '文件名必须包含CODE/COADE十六进制码值：%s', fileName);
        end
        rawCode = hex2dec(token{1});
        fullScale = 2^bits;
        if rawCode >= fullScale
            error('converter:dac:CodeInvalid', ...
                '十六进制码值超出配置位数：%s', fileName);
        end
        if rawCode >= 2^(bits - 1)
            signedCode = rawCode - fullScale;
        else
            signedCode = rawCode;
        end
    case 'signed_decimal'
        token = regexp(fileName, '(?i)code_(-?\d+)', 'tokens', 'once');
        if isempty(token)
            error('converter:dac:CodeMissing', ...
                '文件名必须包含code_有符号十进制整数：%s', fileName);
        end
        signedCode = str2double(token{1});
        if abs(signedCode) > 2^(bits - 1)
            error('converter:dac:CodeInvalid', ...
                '码值超出配置位数：%s', fileName);
        end
        fullScale = 2^bits;
        rawCode = mod(signedCode, fullScale);
    otherwise
        error('converter:dac:CodeFormatInvalid', ...
            '不支持的DAC码值文件名格式：%s', formatName);
end

definition = 'twice_abs_signed_code';
if isfield(config, 'codeVppDefinition') && ~isempty(config.codeVppDefinition)
    definition = char(config.codeVppDefinition);
end
switch lower(definition)
    case 'twice_abs_signed_code'
        codeVpp = 2 * abs(signedCode);
    case 'raw_unsigned_code'
        codeVpp = rawCode;
    otherwise
        error('converter:dac:CodeVppDefinitionInvalid', ...
            '不支持的DAC CodeVpp定义：%s', definition);
end
codeInfo = struct('rawCode', rawCode, 'signedCode', signedCode, ...
    'codeVpp', codeVpp, 'codeVppDefinition', definition);
end

function value = localR2(observed, residual)
centered = observed - mean(observed); total = sum(centered.^2);
if total == 0, value = NaN; else, value = 1 - sum(residual.^2) / total; end
end

function row = localEmptyRow()
row = struct('input_file', "", 'input_path', "", 'source_sha256', "", ...
    'variable', "", 'raw_code', NaN, 'signed_code', NaN, 'code_vpp', NaN, ...
    'code_vpp_definition', "", ...
    'sample_rate_hz', NaN, 'duration_s', NaN, 'output_vpp_v', NaN, ...
    'fit_r_squared', NaN, 'fit_residual_rms_v', NaN, ...
    'included_in_fit', false, 'exclusion_reason', "");
end

function tableValue = localParameters(config)
names = fieldnames(config); values = cell(numel(names), 1);
for k = 1:numel(names), values{k} = converter.runtime.valueToText(config.(names{k})); end
tableValue = table(string(names), string(values), ...
    'VariableNames', {'Parameter', 'Value'});
end

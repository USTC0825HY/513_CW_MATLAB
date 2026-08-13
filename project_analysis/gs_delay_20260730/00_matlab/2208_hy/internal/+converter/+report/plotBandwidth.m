function plotBandwidth(results, ~, outputFolder, config)
%PLOTBANDWIDTH Plot fitted code amplitude and normalized response.

if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 频率响应', 'NumberTitle', 'off');
valid = results.ValidForBandwidth;
if isfield(config, 'bandwidthFrequencySource') && ...
        strcmpi(config.bandwidthFrequencySource, 'file')
    plotFrequencyHz = results.FileFrequencyHz;
else
    plotFrequencyHz = results.FrequencyHz;
end
subplot(2, 1, 1);
validHandle = semilogx(plotFrequencyHz(valid), results.CodePp(valid), ...
    'bo-', 'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
invalidHandle = [];
if any(~valid)
    invalidHandle = semilogx(plotFrequencyHz(~valid), ...
        results.CodePp(~valid), 'rx', 'LineWidth', 1.5, 'MarkerSize', 9);
end
referenceHandle = semilogx(plotFrequencyHz(results.ReferencePoint), ...
    results.CodePp(results.ReferencePoint), 'ks', 'LineWidth', 1.2, ...
    'MarkerSize', 8);
hold off;
grid on;
xlabel('输入频率 (Hz)'); ylabel('拟合 Code_{pp} (LSB)');
title(sprintf('ADC 码值峰峰值响应，Fs = %.3f MHz', config.sampleRate / 1e6));
if isempty(invalidHandle)
    legend([validHandle referenceHandle], {'有效数据', '0 dB参考点'}, ...
        'Location', 'best');
else
    legend([validHandle invalidHandle referenceHandle], ...
        {'有效数据', '异常/削顶数据', '0 dB参考点'}, 'Location', 'best');
end

subplot(2, 1, 2);
responseHandle = semilogx(plotFrequencyHz(valid), results.RelativeDb(valid), ...
    'ro-', 'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
currentXLim = xlim;
validRelativeDb = results.RelativeDb(valid);
lowerYLimit = 5 * floor((min([validRelativeDb; ...
    -config.minimumStopbandAttenuationDb]) - 2) / 5);
ylim([lowerYLimit 5]);
stopbandLimitHandle = plot(currentXLim, ...
    -config.minimumStopbandAttenuationDb * [1 1], '--', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 1.2);
text(2e6, -config.minimumStopbandAttenuationDb, '-40 dB', ...
    'Color', [0.85 0.33 0.10], 'VerticalAlignment', 'bottom');
hold off;
grid on;
xlabel('输入频率 (Hz)'); ylabel('相对幅度 (dB)');
title('归一化幅频响应');
legend([responseHandle stopbandLimitHandle], ...
    {'实测响应', '-40 dB 参考线'}, ...
    'Location', 'southwest');
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_bandwidth_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end


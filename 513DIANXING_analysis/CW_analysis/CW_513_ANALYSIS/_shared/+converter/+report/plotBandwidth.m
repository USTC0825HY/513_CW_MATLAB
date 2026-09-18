function plotBandwidth(results, bandwidthHz, outputFolder, config)
%PLOTBANDWIDTH Plot fitted code amplitude and normalized response.

if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
% Display the sampling rate and the -3 dB cutoff in kHz below 1 MHz so
% slow ADC chains do not read as "0.083 MHz"; MHz chains are unchanged.
if config.sampleRate < 1e6
    fsLabelText = sprintf('Fs = %.3f kHz', config.sampleRate / 1e3);
else
    fsLabelText = sprintf('Fs = %.3f MHz', config.sampleRate / 1e6);
end
% Plot the measured injection frequencies directly: the figure must
% reflect the test as performed. Any source-impedance conversion of the
% cutoff frequency is done by the engineer, not in this figure.
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
xlabel('输入频率 (Hz)'); ...
    ylabel('拟合 Code_{pp} (LSB)');
title(['ADC 码值峰峰值响应，' fsLabelText]);
if isempty(invalidHandle)
    legend([validHandle referenceHandle], {'有效数据', '0 dB参考点'}, ...
        'Location', 'best');
else
    legend([validHandle invalidHandle referenceHandle], ...
        {'有效数据', '异常/削顶数据', '0 dB参考点'}, 'Location', 'best');
end

subplot(2, 1, 2);
semilogx(plotFrequencyHz(valid), results.RelativeDb(valid), ...
    'ro-', 'LineWidth', 1.2, 'MarkerFaceColor', 'r');
hold on;
currentXLim = xlim;
plot(currentXLim, [-3 -3], '--k');
if isfinite(bandwidthHz)
    currentYLim = ylim;
    plot([bandwidthHz bandwidthHz], currentYLim, '--g');
    % Anchor the annotation to the left of the marker when the crossing
    % sits in the right half of the axis so the text stays inside the box.
    if bandwidthHz > 0.35 * currentXLim(2)
        textX = bandwidthHz / 1.03;
        align = 'right';
    else
        textX = bandwidthHz * 1.03;
        align = 'left';
    end
    text(textX, mean(currentYLim), ...
        sprintf('-3 dB 带宽 %.4f kHz', bandwidthHz / 1e3), ...
        'Color', [0 0.5 0], 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', align);
end
hold off;
grid on;
xlabel('输入频率 (Hz)'); ylabel('相对幅度 (dB)');
title('归一化幅频响应');
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_bandwidth_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

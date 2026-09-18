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
% Optional source-impedance de-embedding display: with a factor other than
% 1 the frequency axis is drawn de-embedded (measured frequency x factor)
% so the -3 dB marker lands on the corrected board-only bandwidth, and the
% axis label states the applied factor.
bandwidthScaleFactor = 1;
if isfield(config, 'bandwidthScaleFactor') && ...
        ~isempty(config.bandwidthScaleFactor)
    bandwidthScaleFactor = double(config.bandwidthScaleFactor);
end
scaleNote = '';
if bandwidthScaleFactor ~= 1
    scaleNote = sprintf('，×%.4f 源阻抗去嵌', bandwidthScaleFactor);
end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 频率响应', 'NumberTitle', 'off');
valid = results.ValidForBandwidth;
if isfield(config, 'bandwidthFrequencySource') && ...
        strcmpi(config.bandwidthFrequencySource, 'file')
    plotFrequencyHz = results.FileFrequencyHz;
else
    plotFrequencyHz = results.FrequencyHz;
end
plotFrequencyHz = plotFrequencyHz * bandwidthScaleFactor;
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
xlabel(sprintf('输入频率 (Hz)%s', scaleNote)); ...
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
        sprintf('-3 dB 带宽 %.4f kHz%s', bandwidthHz / 1e3, scaleNote), ...
        'Color', [0 0.5 0], 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', align);
end
hold off;
grid on;
xlabel(sprintf('输入频率 (Hz)%s', scaleNote)); ylabel('相对幅度 (dB)');
title('归一化幅频响应');
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_bandwidth_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

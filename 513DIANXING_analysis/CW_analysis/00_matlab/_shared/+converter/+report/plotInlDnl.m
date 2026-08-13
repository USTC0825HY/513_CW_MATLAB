function plotInlDnl(details, outputFolder, config)
%PLOTINLDNL Plot probability, DNL, INL, and fit summary.

curve = details.curveTable;
if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC INL DNL', 'NumberTitle', 'off');
subplot(2, 2, 1);
plot(curve.Code, curve.MeasuredProbability, 'b-', 'LineWidth', 1.0);
hold on;
plot(curve.Code, curve.TheoreticalProbability, 'r--', 'LineWidth', 1.0);
hold off; grid on;
xlabel('ADC Code'); ylabel('Probability');
title(sprintf('%s Code Probability, %.6g Hz', ...
    details.channelName, details.frequencyHz));
legend('Measured', 'Sine model', 'Location', 'best');

subplot(2, 2, 2);
plot(curve.Code, curve.DNL_LSB, 'm-', 'LineWidth', 1.0);
hold on; plot([curve.Code(1) curve.Code(end)], [0 0], 'k--'); hold off;
grid on; xlabel('ADC Code'); ylabel('DNL (LSB)');
title(sprintf('DNL max = %.4f LSB', details.maxAbsDnl));

subplot(2, 2, 3);
plot(curve.Code, curve.INL_LSB, 'r-', 'LineWidth', 1.0);
hold on; plot([curve.Code(1) curve.Code(end)], [0 0], 'k--'); hold off;
grid on; xlabel('ADC Code'); ylabel('INL (LSB)');
title(sprintf('INL max = %.4f LSB', details.maxAbsInl));

subplot(2, 2, 4); axis off;
text(0.02, 0.90, sprintf('Channel: %s', details.channelName), ...
    'Units', 'normalized', 'FontSize', 11);
text(0.02, 0.75, sprintf('Frequency = %.6g Hz', details.frequencyHz), ...
    'Units', 'normalized', 'FontSize', 11);
text(0.02, 0.60, sprintf('Fit R^2 = %.6f', details.fitR2), ...
    'Units', 'normalized', 'FontSize', 11);
text(0.02, 0.45, sprintf('DNL max = %.4f LSB', details.maxAbsDnl), ...
    'Units', 'normalized', 'FontSize', 11);
text(0.02, 0.30, sprintf('INL max = %.4f LSB', details.maxAbsInl), ...
    'Units', 'normalized', 'FontSize', 11);
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_inl_dnl_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end


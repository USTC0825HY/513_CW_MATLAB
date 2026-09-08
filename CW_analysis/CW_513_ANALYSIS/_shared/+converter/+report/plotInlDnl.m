function plotInlDnl(details, outputFolder, config)
%PLOTINLDNL Plot probability, DNL, INL, and per-record diagnostics.

curve = details.curveTable;
if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
if isempty(curve)
    plotCaptureDiagnostics(details, outputFolder, config, visibility);
    return;
end

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
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
text(0.02, 0.75, sprintf('Frequency = %.6g Hz', details.frequencyHz), ...
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
text(0.02, 0.60, sprintf('Fit R^2 = %.6f', details.fitR2), ...
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
text(0.02, 0.45, sprintf('DNL max = %.4f LSB', details.maxAbsDnl), ...
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
text(0.02, 0.30, sprintf('INL max = %.4f LSB', details.maxAbsInl), ...
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
text(0.02, 0.15, sprintf('Captures = %d/%d; glitches = %d', ...
    details.validCaptureCount, details.fileCount, details.totalGlitchSamples), ...
    'Units', 'normalized', 'FontSize', 11, 'Color', 'k');
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_inl_dnl_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
plotCaptureDiagnostics(details, outputFolder, config, visibility);
end

function plotCaptureDiagnostics(details, outputFolder, config, visibility)
capture = details.captureTable;
[xAxis, xLabel] = captureXAxis(capture);
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC INL DNL Capture Diagnostics', 'NumberTitle', 'off');

subplot(2, 2, 1);
plot(xAxis, capture.FrequencyDriftHz, 'o-', 'LineWidth', 1.0);
grid on; xlabel(xLabel); ylabel('Frequency drift (Hz)');
title(sprintf('Frequency median = %.9g Hz', details.frequencyHz));

subplot(2, 2, 2);
yyaxis left;
plot(xAxis, capture.AmplitudeCode, 'o-', 'LineWidth', 1.0);
ylabel('Amplitude (code)');
yyaxis right;
plot(xAxis, capture.OffsetCode, 's-', 'LineWidth', 1.0);
ylabel('Offset (code)');
grid on; xlabel(xLabel); title('Amplitude and offset stability');

subplot(2, 2, 3);
yyaxis left;
plot(xAxis, capture.FitR2, 'o-', 'LineWidth', 1.0);
ylabel('Sine-fit R^2');
yyaxis right;
plot(xAxis, capture.ResidualRmsCode, 's-', 'LineWidth', 1.0);
ylabel('Residual RMS (code)');
grid on; xlabel(xLabel); title('Fit quality');

subplot(2, 2, 4);
yyaxis left;
stem(xAxis, capture.GlitchCount, 'filled');
ylabel('Residual glitch count');
yyaxis right;
plot(xAxis, capture.MaxAbsSecondDifferenceCode, 'o-');
ylabel('Max |second difference| (code)');
grid on; xlabel(xLabel);
title(sprintf('%s; valid captures %d/%d', ...
    details.status, details.validCaptureCount, details.fileCount), ...
    'Interpreter', 'none');

if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_inl_dnl_capture_diagnostics'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

function [xAxis, xLabel] = captureXAxis(capture)
if ismember('ModifiedElapsedSeconds', capture.Properties.VariableNames) && ...
        all(isfinite(capture.ModifiedElapsedSeconds))
    xAxis = capture.ModifiedElapsedSeconds / 60;
    xLabel = 'File-modified elapsed time (min)';
else
    xAxis = (1:height(capture))';
    xLabel = 'Record index';
end
end

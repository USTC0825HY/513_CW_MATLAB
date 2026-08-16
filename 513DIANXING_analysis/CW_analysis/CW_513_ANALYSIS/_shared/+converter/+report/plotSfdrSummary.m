function plotSfdrSummary(results, outputFolder, config)
%PLOTSFDRSUMMARY Plot dynamic metrics and ENOB for all selected files.

if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'SFDR 汇总', 'NumberTitle', 'off');
labels = cell(height(results), 1);
for labelIndex = 1:height(results)
    labels{labelIndex} = formatFrequencyLabel( ...
        results.FundamentalFrequencyHz(labelIndex));
end
subplot(2, 1, 1);
metricHandles = bar(1:height(results), ...
    [results.SFDR results.SNR results.SINAD results.THD], 'grouped');
grid on;
ylabel('动态指标 (dB)');
set(gca, 'XTick', 1:height(results), 'XTickLabel', labels);
legend(metricHandles, {'SFDR', 'SNR', 'SINAD', 'THD'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal');
subplot(2, 1, 2);
plot(1:height(results), results.ENOB, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
grid on;
ylabel('ENOB (bit)');
xlabel('实际基波频率');
set(gca, 'XTick', 1:height(results), 'XTickLabel', labels);
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_SFDR_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

function label = formatFrequencyLabel(frequencyHz)
if frequencyHz >= 1e9
    label = sprintf('%.4g GHz', frequencyHz / 1e9);
elseif frequencyHz >= 1e6
    label = sprintf('%.4g MHz', frequencyHz / 1e6);
elseif frequencyHz >= 1e3
    label = sprintf('%.4g kHz', frequencyHz / 1e3);
else
    label = sprintf('%.4g Hz', frequencyHz);
end
end


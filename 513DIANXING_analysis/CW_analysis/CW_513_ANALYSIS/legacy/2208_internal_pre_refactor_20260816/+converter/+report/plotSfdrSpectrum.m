function plotSfdrSpectrum(metrics, fileName, outputFolder, config)
%PLOTSFDRSPECTRUM Plot and optionally save one ADC spectrum.

visibility = figureVisibility(config.showFigures);
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', ['SFDR - ' fileName], 'NumberTitle', 'off');
frequencyMHz = metrics.spectrum.frequencyHz / 1e6;
levelDbfs = metrics.spectrum.levelDb - ...
    metrics.spectrum.fundamentalLevelDb + metrics.dynamic.signalAmplitudeDbfs;
plot(frequencyMHz, levelDbfs, 'r-', 'LineWidth', 0.8);
hold on;
fundamentalIndex = metrics.spectrum.fundamentalIndex;
spurIndex = metrics.spectrum.largestSpurIndex;
plot(frequencyMHz(fundamentalIndex), levelDbfs(fundamentalIndex), ...
    'ko', 'MarkerFaceColor', 'y');
plot(frequencyMHz(spurIndex), levelDbfs(spurIndex), ...
    'ko', 'MarkerFaceColor', 'c');
currentXLim = xlim;
plot(currentXLim, [levelDbfs(spurIndex) levelDbfs(spurIndex)], '--g');
hold off;
grid on;
xlabel('频率 (MHz)');
ylabel('幅度 (dBFS)');
title(sprintf('%s | 基波 %.6f MHz', fileName, ...
    metrics.spectrum.fundamentalFrequencyHz / 1e6), 'Interpreter', 'none');
legend('频谱', '基波', '最大杂散', '杂散电平', 'Location', 'northwest');
ylim([-140 0]);
text(0.70, 0.96, sprintf(['SFDR = %.2f dB\nSNR = %.2f dB\n' ...
    'SINAD = %.2f dB\nTHD = %.2f dB\nENOB = %.2f bit'], ...
    metrics.dynamic.SFDR, metrics.dynamic.SNR, metrics.dynamic.SINAD, ...
    metrics.dynamic.THD, metrics.dynamic.ENOB), ...
    'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'w');
if config.saveFigures
    [~, fileStem] = fileparts(fileName);
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, [fileStem '_spectrum']), 180);
end
closeIfHidden(figureHandle, config.showFigures);
end

function visibility = figureVisibility(showFigures)
if showFigures, visibility = 'on'; else, visibility = 'off'; end
end

function closeIfHidden(figureHandle, showFigures)
if ~showFigures, close(figureHandle); end
end


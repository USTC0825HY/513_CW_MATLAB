function plotIsolation(results, drivenChannel, frequencyHz, outputFolder, config)
%PLOTISOLATION Plot the four-channel isolation matrix.

allChannels = ["X1G"; "X2G"; "X3G"; "X4G"];
isolationMatrix = NaN(4, 4);
drivenIndex = find(allChannels == string(drivenChannel), 1);
for rowIndex = 1:height(results)
    quietIndex = find(allChannels == results.QuietChannel(rowIndex), 1);
    isolationMatrix(drivenIndex, quietIndex) = results.IsolationDb(rowIndex);
end
if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 隔离度', 'NumberTitle', 'off');
imageHandle = imagesc(isolationMatrix);
set(imageHandle, 'AlphaData', isfinite(isolationMatrix));
axis equal tight;
colormap(parula); colorbar;
set(gca, 'XTick', 1:4, 'YTick', 1:4, ...
    'XTickLabel', cellstr(allChannels), 'YTickLabel', cellstr(allChannels), ...
    'Color', [0.88 0.88 0.88]);
xlabel('安静通道'); ylabel('激励通道');
title(sprintf('ADC %.3f MHz 隔离度，要求 >= %.1f dB', ...
    frequencyHz / 1e6, config.minimumIsolationDb));
for rowIndex = 1:4
    for columnIndex = 1:4
        if isfinite(isolationMatrix(rowIndex, columnIndex))
            text(columnIndex, rowIndex, sprintf('%.2f', ...
                isolationMatrix(rowIndex, columnIndex)), ...
                'HorizontalAlignment', 'center', ...
                'Color', 'w', 'FontWeight', 'bold');
        else
            text(columnIndex, rowIndex, '-', 'HorizontalAlignment', 'center');
        end
    end
end
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_isolation_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end


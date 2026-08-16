function plotIsolation(results, drivenChannel, frequencyHz, outputFolder, config, fileNames)
%PLOTISOLATION Plot isolation values using the selected CSV file names.

if nargin < 6 || isempty(fileNames)
    fileNames = cellstr(string(results.QuietChannel));
end
fileNames = cellstr(string(fileNames));
labels = cell(size(fileNames));
for index = 1:numel(fileNames)
    [~, labels{index}] = fileparts(fileNames{index});
end
quietRows = results.QuietChannel ~= string(drivenChannel);
quietResults = results(quietRows, :);
drivenToken = regexp(char(drivenChannel), 'JG(\d+)', 'tokens', 'once');
isDrivenFile = false(size(labels));
if ~isempty(drivenToken)
    for index = 1:numel(labels)
        isDrivenFile(index) = ~isempty(regexp(labels{index}, ...
            ['^JG' drivenToken{1} '-'], 'once'));
    end
end
quietLabels = labels(~isDrivenFile);
if numel(quietLabels) ~= height(quietResults)
    quietLabels = labels(1:height(quietResults));
end
if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 隔离度', 'NumberTitle', 'off');
bar(quietResults.IsolationDb, 'FaceColor', [0.20 0.45 0.70]);
hold on;
yline(config.minimumIsolationDb, 'r--', '阈值');
hold off;
grid on;
set(gca, 'XTick', 1:numel(quietLabels), 'XTickLabel', quietLabels);
xlabel('CSV 文件名'); ylabel('隔离度 (dB)');
title(sprintf('%s 激励，%.3f MHz 隔离度，要求 > %.1f dB', ...
    char(drivenChannel), frequencyHz / 1e6, config.minimumIsolationDb));
for rowIndex = 1:numel(quietResults.IsolationDb)
    text(rowIndex, quietResults.IsolationDb(rowIndex), sprintf('%.2f', ...
        quietResults.IsolationDb(rowIndex)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');
end
if isempty(quietLabels)
    text(1, 0, '无安静通道', 'HorizontalAlignment', 'center');
end
if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_isolation_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

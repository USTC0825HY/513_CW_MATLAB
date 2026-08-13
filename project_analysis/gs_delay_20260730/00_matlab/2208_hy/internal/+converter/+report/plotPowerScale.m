function plotPowerScale(results, details, outputFolder, config)
%PLOTPOWERSCALE Plot code and dBFS responses versus input power.

if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC 输入功率标定', 'NumberTitle', 'off');
fitPowerDbm = linspace(config.powerRangeDbm(1), config.powerRangeDbm(2), 100);
fitDbfs = polyval(details.coefficient, fitPowerDbm);
fitCodeRms = details.adcFullScalePeakCode * 10.^(fitDbfs / 20);

subplot(2, 1, 1);
plotPowerPanel(results, fitPowerDbm, fitCodeRms * 2 * sqrt(2), ...
    config.powerRangeDbm, 'CodePp');
title(sprintf('%s ADC 码值响应', char(details.channelName)));
ylabel('拟合 Code_{pp} (LSB)');

subplot(2, 1, 2);
plotPowerPanel(results, fitPowerDbm, fitDbfs, ...
    config.powerRangeDbm, 'CodeRmsDbfs');
title(sprintf('dBFS 响应：斜率 %.3f dB/dBm，R^2 %.5f', ...
    details.coefficient(1), details.calibrationR2));
ylabel('ADC RMS 幅度 (dBFS)');

if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_power_scale_result'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

function plotPowerPanel(results, fitPowerDbm, fitValue, powerRangeDbm, valueField)
measuredValue = results.(valueField);
hMeasured = plot(results.InputPowerDbm, measuredValue, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
hClipping = [];
hPlateau = [];
if any(results.ClippingFlag)
    hClipping = plot(results.InputPowerDbm(results.ClippingFlag), ...
        measuredValue(results.ClippingFlag), 'rx', ...
        'LineWidth', 1.8, 'MarkerSize', 10);
end
if any(results.PlateauFlag)
    hPlateau = plot(results.InputPowerDbm(results.PlateauFlag), ...
        measuredValue(results.PlateauFlag), 'ks', ...
        'LineWidth', 1.4, 'MarkerSize', 8);
end
hFit = plot(fitPowerDbm, fitValue, 'g-', 'LineWidth', 1.2);
currentYLim = ylim;
plot([powerRangeDbm(1) powerRangeDbm(1)], currentYLim, ...
    '--k', 'HandleVisibility', 'off');
plot([powerRangeDbm(2) powerRangeDbm(2)], currentYLim, ...
    '--k', 'HandleVisibility', 'off');
hRange = plot(nan, nan, '--k');
hold off;
grid on; xlabel('输入功率 (dBm)');
handles = hMeasured; labels = {'测量值'};
if ~isempty(hClipping), handles(end+1) = hClipping; labels{end+1} = '削顶风险'; end
if ~isempty(hPlateau), handles(end+1) = hPlateau; labels{end+1} = '平台点'; end
handles(end+1) = hFit; labels{end+1} = '线性标定';
handles(end+1) = hRange; labels{end+1} = '标定范围';
legend(handles, labels, 'Location', 'best');
end


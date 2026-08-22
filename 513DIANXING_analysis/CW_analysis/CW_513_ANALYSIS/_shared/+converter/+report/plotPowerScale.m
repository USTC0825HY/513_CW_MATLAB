function plotPowerScale(results, details, outputFolder, config)
%PLOTPOWERSCALE Plot the CodePp-to-Vpp calibration and its inverse.

if config.showFigures, visibility = 'on'; else, visibility = 'off'; end
figureHandle = figure('Color', 'w', 'Visible', visibility, ...
    'Name', 'ADC CodePp-Vpp 标定', 'NumberTitle', 'off');
fitVppRange = details.calibrationVppRange;
fitCodePpRange = (fitVppRange - details.coefficient(2)) / ...
    details.coefficient(1);
fitCodePp = linspace(fitCodePpRange(1), fitCodePpRange(2), 100);
fitVpp = polyval(details.coefficient, fitCodePp);

subplot(2, 1, 1);
plotForwardPanel(results, fitCodePp, fitVpp, ...
    fitCodePpRange);
title(sprintf('%s ADC CodePp-Vpp 响应：斜率 %.9g Vpp/CodePp，R^2 %.5f', ...
    char(details.channelName), details.coefficient(1), details.calibrationR2));

subplot(2, 1, 2);
plotInversePanel(results, fitVpp, fitCodePp, details);

if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_vpp_codepp_result'), 180);
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_vpp_codepp_fit'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

function plotForwardPanel(results, fitCodePp, fitVpp, calibrationCodePpRange)
measuredValue = results.InputVoltageVpp;
hMeasured = plot(results.CodePp, measuredValue, 'bo-', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
hExcluded = [];
if any(~results.CalibrationIncluded)
    hExcluded = plot(results.CodePp(~results.CalibrationIncluded), ...
        measuredValue(~results.CalibrationIncluded), 'rx', ...
        'LineWidth', 1.8, 'MarkerSize', 10);
end
hFit = plot(fitCodePp, fitVpp, 'g-', 'LineWidth', 1.2);
currentYLim = ylim;
plot([calibrationCodePpRange(1) calibrationCodePpRange(1)], currentYLim, ...
    '--k', 'HandleVisibility', 'off');
plot([calibrationCodePpRange(2) calibrationCodePpRange(2)], currentYLim, ...
    '--k', 'HandleVisibility', 'off');
hRange = plot(nan, nan, '--k');
hold off;
grid on;
xlabel('拟合 Code_{pp} (LSB)');
ylabel('输入电压 V_{pp} (V)');
handles = hMeasured;
labels = {'测量值'};
if ~isempty(hExcluded)
    handles(end+1) = hExcluded;
    labels{end+1} = '未纳入标定';
end
handles(end+1) = hFit;
labels{end+1} = 'CodePp-Vpp 线性标定';
handles(end+1) = hRange;
labels{end+1} = '标定范围';
legend(handles, labels, 'Location', 'best');
end

function plotInversePanel(results, fitVpp, fitCodePp, details)
included = results.CalibrationIncluded;
hMeasured = plot(results.CodePp, results.InputVoltageVpp, 'bo', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
hExcluded = [];
if any(~included)
    hExcluded = plot(results.CodePp(~included), ...
        results.InputVoltageVpp(~included), 'rx', ...
        'LineWidth', 1.8, 'MarkerSize', 10);
end
hFit = plot(fitCodePp, fitVpp, 'g-', 'LineWidth', 1.2);
hold off;
grid on;
xlabel('拟合 Code_{pp} (LSB)');
ylabel('输入电压 V_{pp} (V)');
title(sprintf('V_{pp} → Code_{pp}：%s', ...
    details.inverseFormulaVppToCodePp));
handles = [hMeasured hFit];
labels = {'测量值', 'V_{pp}→Code_{pp} 标定'};
if ~isempty(hExcluded)
    handles = [hMeasured hExcluded hFit];
    labels = {'测量值', '未纳入标定', 'V_{pp}→Code_{pp} 标定'};
end
legend(handles, labels, 'Location', 'best');
end

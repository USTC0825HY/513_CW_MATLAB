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

% Inverse-only report figures keep clipped
% captures out of the figure and matches the requested report layout while
% retaining the two-panel plot as the default for other devices.
plotMode = 'both';
if isfield(config, 'powerScalePlotMode') && ~isempty(config.powerScalePlotMode)
    plotMode = lower(char(config.powerScalePlotMode));
end
if strcmp(plotMode, 'inverse')
    set(figureHandle, 'Position', [100 100 1400 800]);
    plotInversePanel(results, fitVpp, fitCodePp, details);
else
    subplot(2, 1, 1);
    plotForwardPanel(results, fitCodePp, fitVpp, ...
        fitCodePpRange, details);
    title(sprintf('%s ADC CodePp-Vpp 响应：斜率 %.9g Vpp/CodePp，R^2 %.5f', ...
        char(details.channelName), details.coefficient(1), details.calibrationR2), ...
        'Interpreter', 'none');

    subplot(2, 1, 2);
    plotInversePanel(results, fitVpp, fitCodePp, details);
end

if config.saveFigures
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_vpp_codepp_result'), 180);
    converter.report.saveFigure(figureHandle, ...
        fullfile(outputFolder, 'ADC_vpp_codepp_fit'), 180);
end
if ~config.showFigures, close(figureHandle); end
end

function plotForwardPanel(results, fitCodePp, fitVpp, calibrationCodePpRange, details)
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
[criticalHandles, criticalLabels] = addCriticalInputEstimate(details);
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
handles = [handles criticalHandles];
labels = [labels criticalLabels];
legend(handles, labels, 'Location', 'best');
end

function plotInversePanel(results, fitVpp, fitCodePp, details)
included = results.CalibrationIncluded;
% Only calibrationIncluded points are valid calibration evidence.  In
% particular, do not draw excluded/clipped captures as red crosses: showing
% them makes the report look as if they were part of the calibration set.
hMeasured = plot(results.CodePp(included), results.InputVoltageVpp(included), 'bo', ...
    'LineWidth', 1.2, 'MarkerFaceColor', 'b');
hold on;
hFit = plot(fitCodePp, fitVpp, 'g-', 'LineWidth', 1.2);
[criticalHandles, criticalLabels] = addCriticalInputEstimate(details);
hold off;
grid on;
xlabel('拟合 CodePp (LSB)', 'Interpreter', 'none');
ylabel('输入电压 Vpp (V)', 'Interpreter', 'none');
title(sprintf('%s  Vpp → CodePp：%s', char(details.channelName), ...
    details.inverseFormulaVppToCodePp), 'Interpreter', 'none');
handles = [hMeasured hFit criticalHandles];
labels = [{'测量值', 'Vpp→CodePp 标定'} criticalLabels];
legend(handles, labels, 'Location', 'best');
end

function [handles, labels] = addCriticalInputEstimate(details)
%ADDCRITICALINPUTESTIMATE Mark the 99% point with axis guide lines.

handles = [];
labels = {};
if ~isfield(details, 'criticalInput') || ~details.criticalInput.available
    return;
end

critical = details.criticalInput;
criticalColor = [1 0 0];

markerLabel = buildCriticalLegendLabel(critical);
hCritical = plot(critical.criticalCodePp, critical.criticalInputVpp, 'x', ...
    'Color', criticalColor, 'MarkerSize', 11, 'LineWidth', 2.2);

expandAxesForCritical(critical.criticalCodePp, critical.criticalInputVpp);
currentXLim = xlim;
currentYLim = ylim;
plot([critical.criticalCodePp critical.criticalCodePp], ...
    [currentYLim(1) critical.criticalInputVpp], '--', ...
    'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
plot([currentXLim(1) critical.criticalCodePp], ...
    [critical.criticalInputVpp critical.criticalInputVpp], '--', ...
    'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');

handles = hCritical;
labels = {markerLabel};
end

function expandAxesForCritical(criticalCodePp, criticalInputVpp)
currentXLim = xlim;
currentYLim = ylim;
if criticalCodePp >= currentXLim(2)
    currentXLim(2) = criticalCodePp + ...
        0.06 * max(criticalCodePp - currentXLim(1), eps);
end
if criticalInputVpp >= currentYLim(2)
    currentYLim(2) = criticalInputVpp + ...
        0.08 * max(criticalInputVpp - currentYLim(1), eps);
end
xlim(currentXLim);
ylim(currentYLim);
end

function label = buildCriticalLegendLabel(critical)
%BUILDCRITICALLEGENDLABEL Put the full-scale voltage/power in the legend.

if isfinite(critical.criticalInputDbm)
    valueText = sprintf('%+.3f dBm / %.3f Vpp', ...
        critical.criticalInputDbm, critical.criticalInputVpp);
else
    valueText = sprintf('%.3f Vpp', critical.criticalInputVpp);
end
label = sprintf('99%% 临界满量程：%s', valueText);
end

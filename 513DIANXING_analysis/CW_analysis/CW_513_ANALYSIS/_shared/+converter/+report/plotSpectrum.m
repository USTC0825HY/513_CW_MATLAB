function plotFile = plotSpectrum(frequencyHz, values, outputStem, config)
%PLOTSPECTRUM Shared CW_513_ANALYSIS ASD/PSD report plot style.
%   The DAC ASD workflows and the ADC input-equivalent noise workflows use
%   this same renderer.  The config structure only supplies units, title,
%   optional requirement lines, and optional focus-band annotations.  The
%   da9726_legacy_visual_adapter profile reproduces the historical DA9726
%   report appearance without importing its numerical algorithm.

if nargin < 4 || ~isstruct(config)
    error('converter:report:PlotConfigMissing', ...
        'plotSpectrum requires a configuration structure.');
end

frequencyHz = frequencyHz(:);
values = values(:);
valid = isfinite(frequencyHz) & isfinite(values) & frequencyHz > 0 & values > 0;
frequencyHz = frequencyHz(valid);
values = values(valid);
if isempty(frequencyHz)
    error('converter:report:EmptySpectrum', ...
        '没有可绘制的正频率谱线。');
end

styleProfile = localField(config, 'styleProfile', 'current');
isDa9726Style = strcmpi(char(styleProfile), 'da9726_legacy_visual_adapter');
figurePosition = [80 80 1280 780];
if isDa9726Style
    figurePosition = [100 100 1200 800];
end
figureHandle = figure('Visible', 'off', 'Color', 'w', ...
    'InvertHardcopy', 'off', 'Position', figurePosition);
axisHandle = axes('Parent', figureHandle, 'Color', 'w');
hold(axisHandle, 'on');
set(axisHandle, 'XScale', 'log', 'YScale', 'log', 'XColor', 'k', ...
    'YColor', 'k', 'GridColor', [0.72 0.72 0.72], ...
    'MinorGridColor', [0.86 0.86 0.86]);

xMinimum = max(min(frequencyHz), 1);
if isDa9726Style
    xMinimum = max(min(frequencyHz), 0.1);
end
xLimits = localField(config, 'xLim', [xMinimum, max(frequencyHz)]);
yLimits = localField(config, 'yLim', localLogLimits(values));
limitValue = localField(config, 'limitValue', NaN);
if isfinite(limitValue) && limitValue > 0
    yLimits = localIncludeLimit(yLimits, limitValue);
end
xlim(axisHandle, xLimits);
ylim(axisHandle, yLimits);

focusBand = localField(config, 'focusBandHz', []);
if numel(focusBand) == 2 && all(isfinite(focusBand)) && ...
        focusBand(1) > 0 && focusBand(2) > focusBand(1)
    if isDa9726Style
        % The DA9726-compatible visual adapter uses only black dashed
        % frequency guides; it deliberately omits the yellow fill.
        plot(axisHandle, [focusBand(1) focusBand(1)], yLimits, '--k', ...
            'LineWidth', 0.9, 'HandleVisibility', 'off');
        plot(axisHandle, [focusBand(2) focusBand(2)], yLimits, '--k', ...
            'LineWidth', 0.9, 'HandleVisibility', 'off');
        focusLabelY = 10 ^ (log10(yLimits(2)) - ...
            0.08 * (log10(yLimits(2)) - log10(yLimits(1))));
        text(axisHandle, focusBand(1) * 1.01, focusLabelY, ...
            sprintf('%.0f MHz', focusBand(1) / 1e6), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
            'Color', 'k', 'BackgroundColor', 'w', 'Margin', 1, ...
            'FontSize', 10, 'Interpreter', 'none');
        text(axisHandle, focusBand(2) / 1.01, focusLabelY, ...
            sprintf('%.0f MHz', focusBand(2) / 1e6), ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
            'Color', 'k', 'BackgroundColor', 'w', 'Margin', 1, ...
            'FontSize', 10, 'Interpreter', 'none');
    else
        patch(axisHandle, [focusBand(1) focusBand(2) focusBand(2) focusBand(1)], ...
            [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], [1.0 0.90 0.55], ...
            'FaceAlpha', 0.16, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(axisHandle, [focusBand(1) focusBand(1)], yLimits, ':k', ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
        plot(axisHandle, [focusBand(2) focusBand(2)], yLimits, ':k', ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
    end
end

lineLabel = localField(config, 'lineLabel', 'ASD');
plot(axisHandle, frequencyHz, values, 'Color', [0.12 0.47 0.71], ...
    'LineWidth', localField(config, 'lineWidth', 1.0), 'DisplayName', lineLabel);

if isfinite(limitValue) && limitValue > yLimits(1) && limitValue < yLimits(2)
    limitX = localField(config, 'limitX', xLimits);
    if isempty(limitX)
        limitX = xLimits;
    end
    limitLabel = localField(config, 'limitLabel', '指标限值');
    showLimitLabel = localField(config, 'showLimitLabel', true);
    if isDa9726Style
        plot(axisHandle, limitX, [limitValue limitValue], 'r--', ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
        if showLimitLabel && ~isempty(limitLabel)
            text(axisHandle, limitX(2) / 1.02, limitValue * 1.05, limitLabel, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
                'Color', 'r', 'FontSize', 10, 'Interpreter', 'none');
        end
    else
        plot(axisHandle, limitX, [limitValue limitValue], 'r--', ...
            'LineWidth', 1.2, 'DisplayName', limitLabel);
    end
end

checkFrequencyHz = localField(config, 'checkFrequencyHz', NaN);
checkValue = localField(config, 'checkValue', NaN);
if isfinite(checkFrequencyHz) && isfinite(checkValue) && ...
        checkFrequencyHz > 0 && checkValue > 0
    if isDa9726Style
        plot(axisHandle, checkFrequencyHz, checkValue, 'ko', ...
            'MarkerFaceColor', 'k', 'MarkerSize', 5, 'HandleVisibility', 'off');
    else
        plot(axisHandle, checkFrequencyHz, checkValue, 'ko', ...
            'MarkerFaceColor', 'k', 'MarkerSize', 5, 'DisplayName', ...
            localField(config, 'checkLabel', '实测指标点'));
    end
    checkValueLabel = localField(config, 'checkValueLabel', '');
    if ~isempty(checkValueLabel)
        text(axisHandle, checkFrequencyHz * 1.18, checkValue * 1.08, ...
            checkValueLabel, 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', 'Color', 'k', 'FontSize', 10, ...
            'BackgroundColor', 'w', 'Margin', 1, 'Interpreter', 'none');
    end
end

annotationText = localField(config, 'annotationText', '');
if ~isempty(annotationText)
    annotationPosition = localField(config, 'annotationPosition', [0.02 0.05]);
    text(axisHandle, annotationPosition(1), annotationPosition(2), ...
        annotationText, 'Units', 'normalized', 'Color', 'k', ...
        'BackgroundColor', 'w', 'EdgeColor', [0.5 0.5 0.5], ...
        'Margin', 3, 'FontSize', 10, 'VerticalAlignment', 'bottom');
end

focusText = localField(config, 'focusText', '');
if ~isDa9726Style && ~isempty(focusText) && numel(focusBand) == 2
    text(axisHandle, sqrt(focusBand(1) * focusBand(2)), yLimits(2) / 1.25, ...
        focusText, 'HorizontalAlignment', 'center', 'Color', [0.25 0.17 0.00], ...
        'BackgroundColor', [1.0 0.97 0.86], 'Margin', 3, 'FontSize', 9);
end

grid(axisHandle, 'on');
set(axisHandle, 'XMinorGrid', 'on', 'YMinorGrid', 'on');
if isDa9726Style
    set(axisHandle, 'FontSize', 11);
    xlabel(axisHandle, localField(config, 'xLabel', 'Frequency (Hz)'), ...
        'FontSize', 13);
    ylabel(axisHandle, localField(config, 'yLabel', 'ASD (uV/sqrtHz)'), ...
        'FontSize', 13);
    titleHandle = title(axisHandle, localField(config, 'titleText', 'ASD'), ...
        'Interpreter', 'none', 'FontSize', 14);
    set(titleHandle, 'Color', [0 0 0]);
else
    xlabel(axisHandle, localField(config, 'xLabel', 'Frequency (Hz)'));
    ylabel(axisHandle, localField(config, 'yLabel', 'ASD (uV/sqrtHz)'));
    title(axisHandle, localField(config, 'titleText', 'ASD'), ...
        'Interpreter', 'none');
end
showLegend = localField(config, 'showLegend', ~isDa9726Style);
if showLegend
    legend(axisHandle, 'Location', localField(config, 'legendLocation', 'southwest'), ...
        'Color', 'w', 'TextColor', 'k', 'EdgeColor', [0.25 0.25 0.25], ...
        'Interpreter', 'none');
end
hold(axisHandle, 'off');

converter.report.saveFigure(figureHandle, outputStem, ...
    localField(config, 'resolutionDpi', 180));
plotFile = [outputStem '.png'];
close(figureHandle);
end

function value = localField(config, name, defaultValue)
if isfield(config, name) && ~isempty(config.(name))
    value = config.(name);
else
    value = defaultValue;
end
end

function limits = localLogLimits(values)
limits = [10 ^ floor(log10(min(values))), 10 ^ ceil(log10(max(values)))];
if limits(1) == limits(2)
    limits(2) = limits(1) * 10;
end
end

function limits = localIncludeLimit(limits, limitValue)
if limitValue >= limits(2)
    limits(2) = 10 ^ ceil(log10(limitValue * 2));
end
if limitValue <= limits(1)
    limits(1) = 10 ^ floor(log10(limitValue / 2));
end
if limits(1) >= limits(2)
    limits(2) = limits(1) * 10;
end
end

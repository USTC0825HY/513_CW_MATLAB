function saveFigure(figureHandle, outputStem, resolutionDpi)
%SAVEFIGURE Save PNG and editable FIG with MATLAB R2018 APIs.

if nargin < 3
    resolutionDpi = 180;
end
% MATLAB can inherit the desktop dark theme through the root graphics
% defaults.  Explicitly normalize the saved figure to a report-friendly
% light theme; setting the figure Color alone does not change axes Color.
normalizeLightTheme(figureHandle);
pngPath = [outputStem '.png'];
try
    print(figureHandle, pngPath, '-dpng', sprintf('-r%d', resolutionDpi));
catch
    originalVisibility = get(figureHandle, 'Visible');
    originalUnits = get(figureHandle, 'Units');
    originalPosition = get(figureHandle, 'Position');
    set(figureHandle, 'Units', 'pixels', 'Position', [80 80 1400 800], ...
        'Visible', 'on');
    drawnow;
    capturedFrame = getframe(figureHandle);
    imwrite(capturedFrame.cdata, pngPath);
    set(figureHandle, 'Units', originalUnits, ...
        'Position', originalPosition, 'Visible', originalVisibility);
end
savefig(figureHandle, [outputStem '.fig']);
end

function normalizeLightTheme(figureHandle)
%NORMALIZELIGHTTHEME Make PNG and FIG exports independent of desktop theme.

set(figureHandle, 'Color', 'w');
if isprop(figureHandle, 'InvertHardcopy')
    set(figureHandle, 'InvertHardcopy', 'off');
end

axesHandles = findall(figureHandle, 'Type', 'axes');
for k = 1:numel(axesHandles)
    axisHandle = axesHandles(k);
    if isprop(axisHandle, 'Color')
        set(axisHandle, 'Color', 'w');
    end
    if isprop(axisHandle, 'XColor')
        set(axisHandle, 'XColor', 'k', 'YColor', 'k', 'ZColor', 'k');
    end
    if isprop(axisHandle, 'GridColor')
        set(axisHandle, 'GridColor', [0.70 0.70 0.70]);
    end
    if isprop(axisHandle, 'MinorGridColor')
        set(axisHandle, 'MinorGridColor', [0.82 0.82 0.82]);
    end
    if isprop(axisHandle, 'XLabel')
        set(axisHandle.XLabel, 'Color', 'k');
        set(axisHandle.YLabel, 'Color', 'k');
        set(axisHandle.ZLabel, 'Color', 'k');
        set(axisHandle.Title, 'Color', 'k');
    end
end

legendHandles = findall(figureHandle, 'Type', 'legend');
for k = 1:numel(legendHandles)
    legendHandle = legendHandles(k);
    if isprop(legendHandle, 'Color')
        set(legendHandle, 'Color', 'w');
    end
    if isprop(legendHandle, 'TextColor')
        set(legendHandle, 'TextColor', 'k');
    end
    if isprop(legendHandle, 'EdgeColor')
        set(legendHandle, 'EdgeColor', [0.25 0.25 0.25]);
    end
end
end


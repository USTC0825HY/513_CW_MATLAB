function saveFigure(figureHandle, outputStem, resolutionDpi)
%SAVEFIGURE Save PNG and editable FIG with MATLAB R2018 APIs.

if nargin < 3
    resolutionDpi = 180;
end
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


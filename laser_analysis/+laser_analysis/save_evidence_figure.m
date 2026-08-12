function filePath = save_evidence_figure(figureHandle, output, name, cfg)
%SAVE_EVIDENCE_FIGURE Export one evidence figure into the run directory.

arguments
    figureHandle (1, 1) matlab.ui.Figure
    output (1, 1) struct
    name (1, 1) string
    cfg (1, 1) struct
end

filePath = fullfile(output.runDir, char(name + ".png"));
dpi = 180;
if isfield(cfg, 'plotDpi') && isfinite(cfg.plotDpi)
    dpi = cfg.plotDpi;
end
exportgraphics(figureHandle, filePath, 'Resolution', dpi);
if ~isfield(cfg, 'showFigures') || ~cfg.showFigures
    close(figureHandle);
end
filePath = string(filePath);
end

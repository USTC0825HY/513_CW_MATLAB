function [config, cancelled] = prepareDacInputs(config, dataFolder, files, outputFolder, overrides, defaultFolder)
%PREPAREDACINPUTS Resolve file selection before invoking DAC calculation.
config = converter.runtime.mergeConfig(config, overrides);
% Explicit positional inputs take priority; configuration inputs remain usable.
if isempty(dataFolder), dataFolder = config.dataFolder; end
if isempty(dataFolder), dataFolder = defaultFolder; end
if isempty(files), files = config.inputFiles; end
if isempty(outputFolder), outputFolder = config.outputFolder; end
[files, dataFolder] = converter.io.selectMatFiles(dataFolder, files, ...
    ['选择本次 ' config.deviceId ' ' config.analysisId ' MAT（可多选）']);
cancelled = isempty(files);
if cancelled, return; end
config.dataFolder = char(dataFolder);
config.inputFiles = files;
config.outputFolder = converter.io.resolveOutputBase(dataFolder, outputFolder);
% A declared MAT channel applies once to all captures, or once per capture.
if ~isempty(config.dataVariables) && ...
        ~ismember(numel(string(config.dataVariables)), [1 numel(files)])
    error('converter:io:ChannelCountMismatch', 'dataVariables 须为一项或与文件逐一对应。');
end
end

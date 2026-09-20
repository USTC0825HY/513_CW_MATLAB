function [config,files,dataFolder,cancelled] = prepareAdcRadix(config,dataFolder,files)
%PREPAREADCRADIX Confirm ambiguous interactive inputs before creating outputs.
% Explicit file runs never prompt. The per-file map belongs to this run,
% not to a persistent preference, and prevents a second radix dialog.
cancelled = false;
if ~isfield(config,'allowRadixPrompt') || ~config.allowRadixPrompt, return; end
if isempty(files)
    [files,dataFolder] = converter.io.selectCsvFiles(dataFolder,files);
    if isempty(files), cancelled = true; return; end
end
if isfield(config,'inputRadix') && ~isempty(config.inputRadix) && ...
        ~strcmpi(config.inputRadix,'auto'), return; end
files = cellstr(string(files));
mapping = struct('filePath',{},'inputRadix',{},'inputRadixSource',{});
for k = 1:numel(files)
    path = converter.io.resolveInputPath(dataFolder,files{k});
    try
        [~,metadata] = converter.io.readAdcCsv(path,config);
    catch exception
        if strcmp(exception.identifier,'converter:io:InputRadixCancelled')
            cancelled = true; files = {}; return;
        end
        rethrow(exception);
    end
    mapping(end+1) = struct('filePath',metadata.filePath, ...
        'inputRadix',metadata.inputRadix, ...
        'inputRadixSource',metadata.inputRadixSource); %#ok<AGROW>
end
config.inputRadixByFile = mapping;
config.allowRadixPrompt = false;
end

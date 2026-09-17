function folder = resolveDa9726DataFolder(analysisId)
%RESOLVEDA9726DATAFOLDER Find a useful DA9726 data folder for the chooser.
%   Explicit dataFolder/inputFiles supplied to an entry point always take
%   precedence.  This helper only supplies the initial folder for a
%   zero-argument run.  It does not recurse through the data tree.

analysisId = lower(char(analysisId));
switch analysisId
    case 'noise'
        relativeFolders = { ...
            fullfile('DA9726', '03_Noise', 'nosie_20260901'), ...
            fullfile('DA9726', '03_Noise')};
    case 'scale'
        relativeFolders = { ...
            fullfile('DA9726', 'sin_scale', 'DAC1_JG18'), ...
            fullfile('DA9726', 'sin_scale')};
    otherwise
        error('cw513:UnknownDa9726Folder', ...
            '不支持的DA9726数据类型：%s', analysisId);
end

% A data-root environment variable makes the entry portable to another PC.
% The value is the directory that contains DA9726, not the DA9726 directory.
roots = {getenv('CW513_DATA_ROOT'), getenv('LASER_TEST_513_DATA_ROOT'), ...
    getenv('LASER_TEST_DATA_ROOT')};
roots = roots(~cellfun('isempty', roots));
roots = [roots, { ...
    fullfile('G:', filesep, '513_CW_test', 'CW_Data', '513_CW_DATA'), ...
    fullfile('F:', filesep, '01_Laser', '0_20260727_513test', ...
        'CW_Data', '513_CW_DATA')}];

% Prefer a candidate that actually contains MAT captures.  If a known
% parent exists but is currently empty, return it as the chooser start path.
existingFolder = '';
for rootIndex = 1:numel(roots)
    root = char(roots{rootIndex});
    if isempty(root), continue; end
    for folderIndex = 1:numel(relativeFolders)
        candidate = fullfile(root, relativeFolders{folderIndex});
        if ~isfolder(candidate), continue; end
        if isempty(existingFolder), existingFolder = candidate; end
        if ~isempty(dir(fullfile(candidate, '*.mat')))
            folder = candidate;
            return;
        end
    end
end

if isempty(existingFolder)
    folder = '';
else
    folder = existingFolder;
end
end

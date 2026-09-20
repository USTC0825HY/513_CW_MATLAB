function revision = getGitRevision(startFolder)
%GETGITREVISION Return the current Git commit without failing a run.

revision = 'unknown';
currentFolder = char(startFolder);
while ~isempty(currentFolder)
    if isfolder(fullfile(currentFolder, '.git')) || isfile(fullfile(currentFolder, '.git'))
        oldFolder = pwd;
        cleanupObject = onCleanup(@() cd(oldFolder));
        cd(currentFolder);
        safe = strrep(currentFolder, '\', '/');
        [status, output] = system(sprintf('git -c safe.directory="%s" rev-parse --short HEAD', safe));
        if status == 0
            revision = strtrim(output);
            [dirtyStatus, dirty] = system(sprintf('git -c safe.directory="%s" status --porcelain', safe));
            if dirtyStatus == 0 && ~isempty(strtrim(dirty)), revision = sprintf('%s-dirty',revision); end
        end
        return;
    end
    parentFolder = fileparts(currentFolder);
    if strcmp(parentFolder, currentFolder)
        break;
    end
    currentFolder = parentFolder;
end
end

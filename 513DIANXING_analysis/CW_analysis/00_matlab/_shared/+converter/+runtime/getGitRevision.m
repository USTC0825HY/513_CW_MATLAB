function revision = getGitRevision(startFolder)
%GETGITREVISION Return the current Git commit without failing a run.

revision = 'unknown';
currentFolder = char(startFolder);
while ~isempty(currentFolder)
    if isfolder(fullfile(currentFolder, '.git'))
        oldFolder = pwd;
        cleanupObject = onCleanup(@() cd(oldFolder));
        cd(currentFolder);
        [status, output] = system('git rev-parse --short HEAD');
        if status == 0
            revision = strtrim(output);
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

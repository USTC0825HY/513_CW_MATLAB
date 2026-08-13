function finishRun(runContext, succeeded, message)
%FINISHRUN Mark a run directory as successful or failed.

diary('off');
if succeeded
    statusName = 'STATUS_SUCCESS.txt';
else
    statusName = 'STATUS_FAILED.txt';
end
fileId = fopen(fullfile(runContext.folder, statusName), 'w');
if fileId < 0
    warning('converter:runtime:CannotWriteStatus', ...
        '无法写入运行状态：%s', runContext.folder);
    return;
end
cleanupObject = onCleanup(@() fclose(fileId));
% Keep datestr/now because the delivered program must run on MATLAB R2018.
fprintf(fileId, 'FinishedAt: %s\n', ...
    datestr(now, 31)); %#ok<DATST,TNOW1>
fprintf(fileId, 'Succeeded: %d\n', logical(succeeded));
if nargin >= 3 && ~isempty(message)
    fprintf(fileId, 'Message: %s\n', message);
end
end

function runContext = createRun(config, dataFolder, fileNames, outputFolder)
%CREATERUN Create a traceable timestamped result directory.

requiredFields = {'deviceId', 'analysisId', 'version'};
converter.runtime.validateConfig(config, requiredFields);
outputBase = converter.io.resolveOutputBase(dataFolder, outputFolder);
if ~isfolder(outputBase)
    mkdir(outputBase);
end

% Keep datestr/now because the delivered program must run on MATLAB R2018.
timestamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<DATST,TNOW1>
folderStem = sprintf('run_%s_%s', timestamp, lower(config.analysisId));
runFolder = fullfile(outputBase, folderStem);
suffix = 1;
while isfolder(runFolder)
    runFolder = fullfile(outputBase, sprintf('%s_%02d', folderStem, suffix));
    suffix = suffix + 1;
end
mkdir(runFolder);

runContext = struct();
runContext.folder = runFolder;
runContext.logPath = fullfile(runFolder, 'run_log.txt');
runContext.startedAt = datestr(now, 31); %#ok<DATST,TNOW1>
runContext.gitRevision = converter.runtime.getGitRevision( ...
    fileparts(mfilename('fullpath')));

save(fullfile(runFolder, 'run_config.mat'), 'config');
writeRunInfo(runContext, config, dataFolder);
writeAnalysisParameters(runFolder, config);
converter.runtime.writeRunManifest(runFolder, dataFolder, fileNames);
diary(runContext.logPath);
runContext.diaryCleanup = onCleanup(@() diary('off'));

fprintf('器件：%s；分析：%s；采样率：%.9g Hz；ADC：%d bit %s\n', ...
    config.deviceId, config.analysisId, config.sampleRate, ...
    config.adcBits, config.adcCodeFormat);
fprintf('本次结果目录：%s\n', runFolder);
end

function writeRunInfo(runContext, config, dataFolder)
fileId = fopen(fullfile(runContext.folder, 'run_info.txt'), 'w');
if fileId < 0
    error('converter:runtime:CannotWriteRunInfo', '无法写入运行信息。');
end
cleanupObject = onCleanup(@() fclose(fileId));
fprintf(fileId, 'Device: %s\n', config.deviceId);
fprintf(fileId, 'Analysis: %s\n', config.analysisId);
fprintf(fileId, 'Version: %s\n', config.version);
fprintf(fileId, 'StartedAt: %s\n', runContext.startedAt);
fprintf(fileId, 'MATLAB: %s\n', version);
fprintf(fileId, 'GitRevision: %s\n', runContext.gitRevision);
fprintf(fileId, 'DataFolder: %s\n', dataFolder);
stack = dbstack('-completenames');
entryIndex = find(~contains({stack.file}, [filesep '+runtime' filesep]), 1);
if ~isempty(entryIndex)
    fprintf(fileId, 'EntryPoint: %s\n', stack(entryIndex).file);
end
end

function writeAnalysisParameters(runFolder, config)
fieldNames = fieldnames(config);
parameterNames = cell(0, 1);
parameterValues = cell(0, 1);
for fieldIndex = 1:numel(fieldNames)
    fieldName = fieldNames{fieldIndex};
    value = config.(fieldName);
    if ischar(value)
        textValue = value;
    elseif isstring(value) && isscalar(value)
        textValue = char(value);
    elseif isnumeric(value) || islogical(value)
        textValue = mat2str(value, 15);
    else
        continue;
    end
    parameterNames{end + 1, 1} = fieldName; %#ok<AGROW>
    parameterValues{end + 1, 1} = textValue; %#ok<AGROW>
end
parameterTable = table(parameterNames, parameterValues, ...
    'VariableNames', {'Parameter', 'Value'});
converter.report.writeTable(parameterTable, ...
    fullfile(runFolder, 'analysis_parameters.csv'));
end

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
converter.runtime.writeRunManifest(runFolder, dataFolder, fileNames);
diary(runContext.logPath);
runContext.diaryCleanup = onCleanup(@() diary('off'));

if strncmpi(config.deviceId, 'DA', 2)
    % DA analyses consume voltage waveforms captured by PicoScope.  Report
    % the DAC code width and the captured quantity separately.
    fprintf(['器件：%s；分析：%s；采样率：%.9g Hz；DAC码宽：%d bit；' ...
        '采集波形：电压（PicoScope MAT）\n'], ...
        config.deviceId, config.analysisId, config.sampleRate, ...
        localDacCodeBits(config));
else
    fprintf('器件：%s；分析：%s；采样率：%.9g Hz；ADC：%d bit %s\n', ...
        config.deviceId, config.analysisId, config.sampleRate, ...
        config.adcBits, config.adcCodeFormat);
end
fprintf('本次结果目录：%s\n', runFolder);
end

function bits = localDacCodeBits(config)
% Accept older caller-owned configurations while preferring DAC fields.
if isfield(config, 'dacCodeBits')
    bits = config.dacCodeBits;
elseif isfield(config, 'dacBits')
    bits = config.dacBits;
elseif isfield(config, 'adcBits')
    bits = config.adcBits;
else
    error('converter:runtime:DacCodeBitsMissing', ...
        'DA分析配置缺少dacCodeBits或dacBits。');
end
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
end

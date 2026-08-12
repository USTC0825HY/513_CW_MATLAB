function run_ad9245_full_analysis
%RUN_AD9245_FULL_ANALYSIS Recalculate all staged AD9245 data.

bundleFolder = fileparts(mfilename('fullpath'));
codeFolder = 'C:\Users\86183\Desktop\00_matlab\9245_hy';
inputRoot = fullfile(bundleFolder, 'inputs_9245');

addpath(codeFolder);
addpath(fullfile(codeFolder, 'sfdr'));
set(groot, 'defaultFigureVisible', 'off');

diary(fullfile(bundleFolder, 'Logs', 'AD9245_matlab_run.log'));
cleanupObject = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('MATLAB version: %s\n', version);
fprintf('Analysis started: %s\n', datestr(now, 31));

entryFiles = {
    'adc_sfdr_analysis.m'
    'adc_bandwidth_analysis.m'
    'adc_isolation_analysis.m'
    'adc_power_scale_analysis.m'
    };
for fileIndex = 1:numel(entryFiles)
    filePath = fullfile(codeFolder, entryFiles{fileIndex});
    messages = checkcode(filePath, '-id');
    fprintf('\nCHECKCODE %s: %d message(s)\n', ...
        entryFiles{fileIndex}, numel(messages));
end

channelNames = {'X1G', 'X2G', 'X3G', 'X4G'};
for channelIndex = 1:numel(channelNames)
    channelName = channelNames{channelIndex};
    dataFolder = fullfile(inputRoot, 'SFDR_25MHz_6dBm', channelName);
    fileNames = listCsvNames(dataFolder);
    fprintf('\nRunning SFDR: %s, %d file(s)\n', ...
        channelName, numel(fileNames));
    adc_sfdr_analysis(dataFolder, fileNames);
end

dataFolder = fullfile(inputRoot, 'freq_scale', 'X3G');
fileNames = listCsvNames(dataFolder);
fprintf('\nRunning bandwidth: %d file(s)\n', numel(fileNames));
adc_bandwidth_analysis(dataFolder, fileNames);

dataFolder = fullfile(inputRoot, 'GeLiDu', 'X3G_1MHz_7dBm');
fileNames = listCsvNames(dataFolder);
fprintf('\nRunning isolation: %d file(s)\n', numel(fileNames));
adc_isolation_analysis(dataFolder, fileNames);

dataFolder = fullfile(inputRoot, 'Power_Scale_1MHz');
fileNames = listCsvNames(dataFolder);
fprintf('\nRunning power scale: %d file(s)\n', numel(fileNames));
adc_power_scale_analysis(dataFolder, fileNames);

fprintf('\nAnalysis completed: %s\n', datestr(now, 31));
end

function fileNames = listCsvNames(dataFolder)
fileInfo = dir(fullfile(dataFolder, '*.csv'));
fileNames = {fileInfo.name};
fileNames = sort(fileNames);
end

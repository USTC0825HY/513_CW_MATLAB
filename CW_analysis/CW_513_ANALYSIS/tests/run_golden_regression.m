function report = run_golden_regression(dataRoot)
%RUN_GOLDEN_REGRESSION Compare real X3G workflows with tagged output.
%   REPORT = RUN_GOLDEN_REGRESSION(DATAROOT) requires the existing
%   513_GS_AD_DATA/AD9245 directory. Large raw files are never copied into
%   this repository. The historical power-scale golden is intentionally not
%   included: the formal calibration direction is now CodePp -> Vpp and is
%   covered by ad9245WorkflowTest instead.

if nargin < 1 || ~isfolder(dataRoot)
    error('converter:test:GoldenDataMissing', ...
        '请提供现有 513_GS_AD_DATA/AD9245 数据目录。');
end
testsFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(testsFolder);
addpath(fullfile(repositoryRoot, '9245_hy'));
goldenFolder = fullfile(testsFolder, 'golden', 'ad9245_x3g');
workFolder = [tempname '_ad9245_golden'];
mkdir(workFolder);
workCleanup = onCleanup(@() rmdir(workFolder, 's'));

specs = createSpecs(dataRoot);
analysis = cell(numel(specs), 1);
rowCount = zeros(numel(specs), 1);
exactMatch = false(numel(specs), 1);
for specIndex = 1:numel(specs)
    spec = specs(specIndex);
    outputFolder = fullfile(workFolder, spec.name);
    files = {dir(fullfile(spec.dataFolder, '*.csv')).name};
    spec.entry(spec.dataFolder, files, outputFolder);
    actualFile = newestSummary(outputFolder, spec.summaryFile);
    actual = readtable(actualFile);
    expected = readtable(fullfile(goldenFolder, spec.summaryFile));
    analysis{specIndex} = spec.name;
    rowCount(specIndex) = height(actual);
    exactMatch(specIndex) = isequaln(actual, expected);
end
report = table(analysis, rowCount, exactMatch, ...
    'VariableNames', {'Analysis', 'RowCount', 'ExactMatch'});
if ~all(exactMatch)
    error('converter:test:GoldenMismatch', ...
        'AD9245 X3G 真实数据结果与重构前标签不一致。');
end
disp(report);
clear workCleanup;
end

function specs = createSpecs(dataRoot)
specs(1) = createSpec('sfdr', fullfile(dataRoot, ...
    '01_SFDR', 'X3G', 'raw'), @adc_sfdr_analysis, 'ADC_SFDR_summary.csv');
specs(2) = createSpec('bandwidth', fullfile(dataRoot, ...
    '02_FrequencyResponse', 'X3G', 'raw'), @adc_bandwidth_analysis, ...
    'ADC_bandwidth_summary.csv');
specs(3) = createSpec('isolation', fullfile(dataRoot, ...
    '04_Isolation', 'X3G', 'raw'), @adc_isolation_analysis, ...
    'ADC_isolation_summary.csv');
specs(4) = createSpec('inl_dnl', fullfile(dataRoot, ...
    '05_INL_DNL', 'X3G', 'raw'), @adc_inl_dnl_analysis, ...
    'ADC_inl_dnl_summary.csv');
end

function spec = createSpec(name, dataFolder, entry, summaryFile)
if ~isfolder(dataFolder)
    error('converter:test:GoldenDataMissing', ...
        '缺少真实数据目录：%s', dataFolder);
end
spec = struct('name', name, 'dataFolder', dataFolder, ...
    'entry', entry, 'summaryFile', summaryFile);
end

function summaryPath = newestSummary(outputFolder, summaryFile)
runFolders = dir(fullfile(outputFolder, 'run_*'));
runFolders = runFolders([runFolders.isdir]);
if isempty(runFolders)
    error('converter:test:GoldenOutputMissing', '未生成运行目录。');
end
[~, newestIndex] = max([runFolders.datenum]);
summaryPath = fullfile(runFolders(newestIndex).folder, ...
    runFolders(newestIndex).name, summaryFile);
if ~isfile(summaryPath)
    error('converter:test:GoldenOutputMissing', ...
        '未生成黄金回归摘要：%s', summaryPath);
end
end

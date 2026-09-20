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
    % The tagged source data predates the current 20 MHz/5:1 SFDR default.
    % Reproduce its recorded 25 MHz full-rate conditions explicitly; never
    % reinterpret a historical capture with today's device defaults.
    spec.entry(spec.dataFolder, files, outputFolder, spec.runOptions);
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
historical = struct('inputRadix','decimal', 'sampleRate',25e6, ...
    'ilaCaptureSampleRateHz',25e6);
sfdr = historical;
sfdr.sfdrSampleStride = 1;
sfdr.sfdrAnalysisSampleRateHz = 25e6;
sfdr.sfdrSamplingMode = 'historical_25mhz_full_rate';
sfdr.sfdrResultUse = '历史黄金基线：25 MHz ILA全点分析';
specs(1) = createSpec('sfdr', fullfile(dataRoot, ...
    '01_SFDR', 'X3G', 'raw'), @adc_sfdr_analysis, ...
    'ADC_SFDR_summary.csv', sfdr);
specs(2) = createSpec('bandwidth', fullfile(dataRoot, ...
    '02_FrequencyResponse', 'X3G', 'raw'), @adc_bandwidth_analysis, ...
    'ADC_bandwidth_summary.csv', historical);
specs(3) = createSpec('isolation', fullfile(dataRoot, ...
    '04_Isolation', 'X3G', 'raw'), @adc_isolation_analysis, ...
    'ADC_isolation_summary.csv', historical);
specs(4) = createSpec('inl_dnl', fullfile(dataRoot, ...
    '05_INL_DNL', 'X3G', 'raw'), @adc_inl_dnl_analysis, ...
    'ADC_inl_dnl_summary.csv', historical);
end

function spec = createSpec(name, dataFolder, entry, summaryFile, runOptions)
if ~isfolder(dataFolder)
    error('converter:test:GoldenDataMissing', ...
        '缺少真实数据目录：%s', dataFolder);
end
spec = struct('name', name, 'dataFolder', dataFolder, ...
    'entry', entry, 'summaryFile', summaryFile, 'runOptions', runOptions);
end

function summaryPath = newestSummary(outputFolder, summaryFile)
runFolders = dir(fullfile(outputFolder, 'run_*'));
runFolders = runFolders([runFolders.isdir]);
if isempty(runFolders)
    error('converter:test:GoldenOutputMissing', '未生成运行目录。');
end
[~, newestIndex] = max([runFolders.datenum]);
runFolder = fullfile(runFolders(newestIndex).folder, runFolders(newestIndex).name);
summaryPath = converter.runtime.evidencePath(runFolder, summaryFile);
if ~isfile(summaryPath)
    error('converter:test:GoldenOutputMissing', ...
        '未生成黄金回归摘要：%s', summaryPath);
end
end

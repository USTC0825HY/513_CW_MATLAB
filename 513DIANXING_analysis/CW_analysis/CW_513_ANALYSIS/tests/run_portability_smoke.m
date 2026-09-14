function report = run_portability_smoke()
%RUN_PORTABILITY_SMOKE Verify entrypoints after unrelated project paths vanish.
%   This test only uses temporary synthetic data and restores MATLAB's path
%   on exit.  It is intentionally callable without the laser_analysis tree.

testsFolder = fileparts(mfilename('fullpath'));
sourceRoot = fileparts(testsFolder);
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
clear functions;
smokeFolder = [tempname '_cw513_portability'];
mkdir(smokeFolder);
cleanup = onCleanup(@() rmdir(smokeFolder, 's')); %#ok<NASGU>
repositoryRoot = fullfile(smokeFolder, 'CW_513_ANALYSIS');
copyfile(sourceRoot, repositoryRoot);
if ~isfolder(repositoryRoot)
    error('cw513:PortabilityCopyFailed', '无法复制迁移测试库。');
end
removeUnrelatedPaths(repositoryRoot);
addpath(fullfile(repositoryRoot, '_shared'));

dataFolder = fullfile(smokeFolder, 'raw'); mkdir(dataFolder);
sampleRate = 250e3; time = (0:4095)' / sampleRate;
A = 0.5 * sin(2*pi*1e3*time); Tinterval = 1 / sampleRate;
save(fullfile(dataFolder, 'scale_code_10000.mat'), 'A', 'Tinterval');
A = 1.0 * sin(2*pi*1e3*time);
save(fullfile(dataFolder, 'scale_code_20000.mat'), 'A', 'Tinterval');

adcData = fullfile(smokeFolder, 'adc_raw'); mkdir(adcData);
writeAdcSmokeCsv(fullfile(adcData, 'X3G_1MHz.csv'), false);
writeAdcSmokeCsv(fullfile(adcData, 'YB_1MHz.csv'), true);
addpath(fullfile(repositoryRoot, '9245_hy'));
adc9245 = adc_sfdr_analysis(adcData, {'X3G_1MHz.csv'}, ...
    fullfile(smokeFolder, 'ad9245_results'));
rmpath(fullfile(repositoryRoot, '9245_hy'));
clear adc_sfdr_analysis;
addpath(fullfile(repositoryRoot, '2208_hy'));
adc2208 = adc_sfdr_analysis(adcData, {'YB_1MHz.csv'}, ...
    fullfile(smokeFolder, 'ad2208_results'));
rmpath(fullfile(repositoryRoot, '2208_hy'));
addpath(fullfile(repositoryRoot, '766_hy'));
files = {'scale_code_10000.mat','scale_code_20000.mat'};
scale = dac_scale_analysis(dataFolder, files, fullfile(smokeFolder, 'scale_results'));
noise = dac_noise_analysis(dataFolder, files, fullfile(smokeFolder, 'noise_results'));
pair = struct('driven_file', fullfile(dataFolder, 'scale_code_10000.mat'), ...
    'victim_file', fullfile(dataFolder, 'scale_code_20000.mat'), ...
    'driven_variable', 'A', 'victim_variable', 'A', ...
    'frequency_hz', 1e3, 'driven_label', 'drive', 'victim_label', 'victim', ...
    'reference_plane', 'synthetic voltage at common reference plane');
isolation = dac_isolation_analysis(dataFolder, pair, ...
    fullfile(smokeFolder, 'isolation_results'));

assert(isfile(fullfile(scale.outputFolder, 'STATUS_SUCCESS.txt')));
assert(isfile(fullfile(noise.outputFolder, 'STATUS_SUCCESS.txt')));
assert(isfile(fullfile(isolation.outputFolder, 'STATUS_SUCCESS.txt')));
assert(~isempty(adc9245)); assert(~isempty(adc2208));
assertContained(requiredFiles('9245_hy/adc_sfdr_analysis.m', repositoryRoot), repositoryRoot);
assertContained(requiredFiles('2208_hy/adc_sfdr_analysis.m', repositoryRoot), repositoryRoot);
assertContained(requiredFiles('9726_hy/dac_noise_analysis.m', repositoryRoot), repositoryRoot);
assertContained(requiredFiles('766_hy/dac_noise_analysis.m', repositoryRoot), repositoryRoot);

report = struct('passed', true, 'scaleFolder', scale.outputFolder, ...
    'noiseFolder', noise.outputFolder, 'isolationFolder', isolation.outputFolder);
end

function writeAdcSmokeCsv(filePath, is2208)
sampleRate = 25e6; time = (0:4095)' / sampleRate;
code = round(3500*sin(2*pi*1e6*time));
fileId = fopen(filePath, 'w');
cleanup = onCleanup(@() fclose(fileId)); %#ok<NASGU>
if is2208
    fprintf(fileId, 'sample,c1,c2,yb2208_test_module[2]\n');
    fprintf(fileId, '%d,0,0,%d\n', [(0:numel(code)-1); code(:).']);
else
    fprintf(fileId, 'sample,ad9245_test_module[2]\n');
    fprintf(fileId, '%d,%d\n', [(0:numel(code)-1); code(:).']);
end
end

function removeUnrelatedPaths(repositoryRoot)
allPaths = strsplit(path, pathsep);
for k = 1:numel(allPaths)
    current = allPaths{k};
    if isempty(current), continue; end
    lowerCurrent = lower(current);
    if (contains(lowerCurrent, [filesep 'laser_analysis' filesep]) || ...
            contains(lowerCurrent, [filesep 'cw_513_analysis' filesep])) && ...
            ~contains(lowerCurrent, lower(repositoryRoot))
        rmpath(current);
    end
end
end

function files = requiredFiles(entry, repositoryRoot)
entryPath = fullfile(repositoryRoot, entry);
[files, ~] = matlab.codetools.requiredFilesAndProducts(entryPath);
end

function assertContained(files, repositoryRoot)
for k = 1:numel(files)
    assert(startsWithIgnoreCase(files{k}, repositoryRoot), ...
        '发现迁移目录外的代码依赖：%s', files{k});
end
end

function result = startsWithIgnoreCase(value, prefix)
value = char(value); prefix = char(prefix);
result = numel(value) >= numel(prefix) && ...
    strcmpi(value(1:numel(prefix)), prefix);
end

function report = run_ad9245_refactor_validation()
%RUN_AD9245_REFACTOR_VALIDATION Read-only compatibility validation.
%   Runs checkcode, executes both shared cores only in a temporary output
%   tree, and compares available reviewed summaries with tolerance
%   max(1e-15, 1e-10*abs(reference)).  Existing result directories are read
%   but never written.  The caller must start MATLAB with a valid license.

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(repoRoot);
setup_laser_analysis();
tempRoot = tempname;
mkdir(tempRoot);
cleanup = onCleanup(@() removeTempTree(tempRoot)); %#ok<NASGU>

stage = strings(0, 1);
caseName = strings(0, 1);
status = strings(0, 1);
detail = strings(0, 1);

files = [dir(fullfile(repoRoot, '01_workflows', '**', 's*.m')); ...
    dir(fullfile(repoRoot, '+laser_analysis', '*.m'))];
issueCount = 0;
for k = 1:numel(files)
    issues = checkcode(fullfile(files(k).folder, files(k).name), '-id');
    issueCount = issueCount + numel(issues);
end
[stage, caseName, status, detail] = appendRow(stage, caseName, status, detail, ...
    "static", "all MATLAB files", ternary(issueCount == 0, "pass", "fail"), ...
    sprintf('%d checkcode issue(s)', issueCount));

channels = ["X1G", "X2G", "X3G", "X4G"];
for k = 1:numel(channels)
    channel = channels(k);
    cfg = laser_analysis.ad9245_calibration_config(channel);
    referencePath = fullfile(cfg.outputDir, ...
        sprintf('AD9245_%s_scale_fit_summary.csv', channel));
    cfg.outputDir = fullfile(tempRoot, "scale_" + channel);
    try
        result = laser_analysis.run_ad9245_scale_calibration(cfg);
        assert(startsWith(result.outputFiles.fitSummary, tempRoot), ...
            'Output escaped temporary root.');
        if exist(referencePath, 'file')
            reference = readtable(referencePath);
            compareCalibration(reference, result.summaryTable);
            message = "temporary run matches reviewed summary";
        else
            message = "temporary run passed; reviewed summary absent";
        end
        resultStatus = "pass";
    catch exception
        resultStatus = "fail";
        message = string(exception.identifier) + ": " + string(exception.message);
    end
    [stage, caseName, status, detail] = appendRow(stage, caseName, status, detail, ...
        "calibration", channel, resultStatus, message);
end

noiseCases = [ ...
    struct('channel', "X1G", 'variant', "current"); ...
    struct('channel', "X2G", 'variant', "current"); ...
    struct('channel', "X3G", 'variant', "current"); ...
    struct('channel', "X4G", 'variant', "legacy"); ...
    struct('channel', "X4G", 'variant', "current")];
for k = 1:numel(noiseCases)
    item = noiseCases(k);
    cfg = laser_analysis.ad9245_noise_config(item.channel, item.variant);
    referencePath = fullfile(cfg.outputDir, [char(cfg.caseName) '_one_hz_summary.csv']);
    cfg.outputDir = fullfile(tempRoot, ...
        "noise_" + item.channel + "_" + item.variant);
    label = item.channel + "/" + item.variant;
    try
        result = laser_analysis.run_ad9245_g100_psd_asd(cfg);
        assert(startsWith(result.outputFiles.oneHzSummary, tempRoot), ...
            'Output escaped temporary root.');
        if exist(referencePath, 'file')
            reference = readtable(referencePath);
            compareCommonNumericColumns(reference, result.summaryTable);
            message = "temporary run matches common numeric summary fields";
        else
            message = "temporary run passed; reviewed summary absent";
        end
        resultStatus = "pass";
    catch exception
        resultStatus = "fail";
        message = string(exception.identifier) + ": " + string(exception.message);
    end
    [stage, caseName, status, detail] = appendRow(stage, caseName, status, detail, ...
        "noise", label, resultStatus, message);
end

report = table(stage, caseName, status, detail);
disp(report);
if any(status == "fail")
    error('laser_analysis:ValidationFailed', ...
        'One or more AD9245 refactor validation cases failed.');
end
end

function compareCalibration(reference, actual)
names = {'slopeVPerCode', 'interceptV', 'rSquared', ...
    'residualRmsMv', 'maxAbsResidualMv', 'pointCount'};
compareNamedColumns(reference, actual, names);
stringNames = {'fitName', 'usedFiles', 'excludedFiles', 'inputSha256Manifest'};
compareNamedStrings(reference, actual, stringNames);
end

function compareCommonNumericColumns(reference, actual)
common = intersect(reference.Properties.VariableNames, ...
    actual.Properties.VariableNames, 'stable');
numericNames = strings(0, 1);
for k = 1:numel(common)
    name = common{k};
    if isnumeric(reference.(name)) && isnumeric(actual.(name))
        numericNames(end + 1, 1) = string(name); %#ok<AGROW>
    end
end
compareNamedColumns(reference, actual, cellstr(numericNames));
end

function compareNamedColumns(reference, actual, names)
for k = 1:numel(names)
    name = names{k};
    assert(ismember(name, reference.Properties.VariableNames), ...
        'Reference lacks %s.', name);
    assert(ismember(name, actual.Properties.VariableNames), ...
        'Actual result lacks %s.', name);
    expected = double(reference.(name));
    observed = double(actual.(name));
    assert(isequal(size(expected), size(observed)), ...
        '%s size mismatch.', name);
    tolerance = max(1e-15, 1e-10 .* abs(expected));
    assert(all(abs(observed - expected) <= tolerance | ...
        (isnan(observed) & isnan(expected)), 'all'), ...
        '%s exceeds numerical tolerance.', name);
end
end

function compareNamedStrings(reference, actual, names)
for k = 1:numel(names)
    name = names{k};
    assert(isequal(string(reference.(name)), string(actual.(name))), ...
        '%s string mismatch.', name);
end
end

function [stage, caseName, status, detail] = appendRow( ...
    stage, caseName, status, detail, stageValue, caseValue, statusValue, detailValue)
stage(end + 1, 1) = string(stageValue);
caseName(end + 1, 1) = string(caseValue);
status(end + 1, 1) = string(statusValue);
detail(end + 1, 1) = string(detailValue);
end

function value = ternary(condition, trueValue, falseValue)
if condition, value = trueValue; else, value = falseValue; end
end

function removeTempTree(path)
if exist(path, 'dir') && startsWith(path, tempdir)
    rmdir(path, 's');
end
end

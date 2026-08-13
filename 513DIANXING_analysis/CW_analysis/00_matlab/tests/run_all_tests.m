function results = run_all_tests()
%RUN_ALL_TESTS Run all unit and integration tests for this repository.

testsFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(testsFolder);
addpath(fullfile(repositoryRoot, '_shared'));
addpath(fullfile(repositoryRoot, '9245_hy'));
suite = matlab.unittest.TestSuite.fromFolder( ...
    testsFolder, 'IncludingSubfolders', true);
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);
assertSuccess(results);
end

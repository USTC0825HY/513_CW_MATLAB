function results = run_all_tests()
%RUN_ALL_TESTS Run all unit and integration tests for this repository.

testsFolder = fileparts(mfilename('fullpath'));
repositoryRoot = fileparts(testsFolder);
addpath(fullfile(repositoryRoot, '_shared'));
addpath(fullfile(repositoryRoot, '9245_hy'));
addpath(fullfile(repositoryRoot, '2208_hy'));
addpath(fullfile(repositoryRoot, '677_hy'));
addpath(fullfile(repositoryRoot, '9726_hy'));
addpath(fullfile(repositoryRoot, '766_hy'));
% Keep the AD9245 entry first for its existing integration tests; the
% portability smoke explicitly switches precedence when testing AD2208.
addpath(fullfile(repositoryRoot, '9245_hy'));
addpath(testsFolder);
suite = matlab.unittest.TestSuite.fromFolder( ...
    testsFolder, 'IncludingSubfolders', true);
runner = matlab.unittest.TestRunner.withTextOutput;
results = runner.run(suite);
assertSuccess(results);
end

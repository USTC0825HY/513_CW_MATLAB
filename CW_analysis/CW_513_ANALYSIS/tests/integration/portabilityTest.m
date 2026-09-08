classdef portabilityTest < matlab.unittest.TestCase
    %PORTABILITYTEST Verify that the four device entry families are local.
    methods (Test)
        function migratedTreeRunsWithoutWorkflow(testCase)
            report = run_portability_smoke();
            testCase.verifyTrue(report.passed);
        end
    end
end

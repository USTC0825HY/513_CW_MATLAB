classdef criticalInputEstimateTest < matlab.unittest.TestCase
    %CRITICALINPUTESTIMATETEST Public contracts for 99% rail estimation.

    methods (TestClassSetup)
        function addRuntime(testCase)
            repositoryRoot = fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repositoryRoot, '_shared')));
        end
    end

    methods (Test)
        function selectsPositiveRailInsideClippingBracket(testCase)
            results = criticalInputEstimateTest.measurements( ...
                [1; 2; 3], [100; 200; 900], [-80; -160; -900], ...
                [true; true; false], [false; false; true]);
            estimate = converter.adc.estimateCriticalInput(results, ...
                [0.01 0], criticalInputEstimateTest.config(), 50);

            testCase.verifyTrue(estimate.available);
            testCase.verifyEqual(estimate.status, "bracketed_estimate");
            testCase.verifyEqual(estimate.limitingRail, "positive");
            testCase.verifyEqual(estimate.criticalInputVpp, 2.5344, ...
                AbsTol=1e-12);
            testCase.verifyEqual(estimate.firstClippedInputVpp, 3, ...
                AbsTol=1e-12);
        end

        function selectsNegativeRailWithDcAsymmetry(testCase)
            results = criticalInputEstimateTest.measurements( ...
                [1; 2; 3], [90; 180; 900], [-110; -220; -900], ...
                [true; true; false], [false; false; true]);
            estimate = converter.adc.estimateCriticalInput(results, ...
                [0.01 0], criticalInputEstimateTest.config(), 50);

            testCase.verifyEqual(estimate.limitingRail, "negative");
            testCase.verifyEqual(estimate.criticalInputVpp, ...
                253.44 / 110, AbsTol=1e-12);
            testCase.verifyTrue(estimate.bracketed);
        end

        function reportsUnbracketedExtrapolation(testCase)
            results = criticalInputEstimateTest.measurements( ...
                [1; 2; 3], [50; 100; 150], [-40; -80; -120], ...
                [true; true; true], [false; false; false]);
            estimate = converter.adc.estimateCriticalInput(results, ...
                [0.02 0], criticalInputEstimateTest.config(), NaN);

            testCase.verifyEqual(estimate.status, ...
                "unbracketed_extrapolation");
            testCase.verifyFalse(estimate.bracketed);
            testCase.verifyEqual(estimate.extrapolationRatio, ...
                (253.44 / 50) / 3, AbsTol=1e-12);
            testCase.verifyTrue(isnan(estimate.criticalInputDbm));
        end

        function ignoresExcludedPointsInRailFits(testCase)
            results = criticalInputEstimateTest.measurements( ...
                [1; 2; 3], [100; 200; 5000], [-80; -160; -5000], ...
                [true; true; false], [false; false; true]);
            estimate = converter.adc.estimateCriticalInput(results, ...
                [0.01 0], criticalInputEstimateTest.config(), 50);

            testCase.verifyEqual(estimate.criticalInputVpp, 2.5344, ...
                AbsTol=1e-12);
            testCase.verifyEqual(estimate.positiveRailFitR2, 1, ...
                AbsTol=1e-12);
        end

        function rejectsNonIncreasingRailModels(testCase)
            results = criticalInputEstimateTest.measurements( ...
                [1; 2; 3], [200; 100; 50], [-200; -100; -50], ...
                [true; true; true], [false; false; false]);
            estimate = converter.adc.estimateCriticalInput(results, ...
                [0.01 0], criticalInputEstimateTest.config(), 50);

            testCase.verifyFalse(estimate.available);
            testCase.verifyEqual(estimate.status, "unavailable");
        end

        function rejectsInvalidThreshold(testCase)
            config = criticalInputEstimateTest.config();
            config.criticalInputThresholdFraction = 1;
            results = criticalInputEstimateTest.measurements( ...
                [1; 2], [100; 200], [-100; -200], ...
                [true; true], [false; false]);

            testCase.verifyError(@() converter.adc.estimateCriticalInput( ...
                results, [0.01 0], config, 50), ...
                'converter:adc:InvalidCriticalInputThreshold');
        end
    end

    methods (Static, Access=private)
        function config = config()
            config = struct('adcBits', 9, ...
                'criticalInputThresholdFraction', 0.99);
        end

        function results = measurements(inputVpp, peakCode, valleyCode, ...
                included, clipped)
            results = table(inputVpp, peakCode, valleyCode, included, clipped, ...
                'VariableNames', {'InputVoltageVpp', 'PeakCode', ...
                'ValleyCode', 'CalibrationIncluded', 'ClippingFlag'});
        end
    end
end

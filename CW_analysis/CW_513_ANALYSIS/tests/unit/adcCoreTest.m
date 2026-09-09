classdef adcCoreTest < matlab.unittest.TestCase
    methods (Test)
        function fitsSyntheticSine(testCase)
            sampleRate = 25e6;
            frequencyHz = sampleRate * 160 / 4096;
            time = (0:4095)' / sampleRate;
            code = 1234 * sin(2*pi*frequencyHz*time + 0.37) - 45;
            fit = converter.adc.fitSine(code, frequencyHz, sampleRate);
            testCase.verifyEqual(fit.amplitudeCode, 1234, 'AbsTol', 1e-9);
            testCase.verifyEqual(fit.offsetCode, -45, 'AbsTol', 1e-9);
            testCase.verifyGreaterThan(fit.r2, 1 - 1e-12);
        end

        function estimatesCoherentFrequency(testCase)
            sampleRate = 25e6;
            frequencyHz = sampleRate * 160 / 4096;
            time = (0:4095)' / sampleRate;
            code = 3000 * sin(2*pi*frequencyHz*time);
            actual = converter.adc.estimateFrequency(code, sampleRate);
            testCase.verifyEqual(actual, frequencyHz, ...
                'AbsTol', sampleRate / numel(code));
        end

        function reportsDynamicSpur(testCase)
            config = adcCoreTest.dynamicConfig();
            time = (0:8191)' / config.sampleRate;
            code = 3000*sin(2*pi*1e6*time) + 30*sin(2*pi*2.3e6*time);
            config.fitMode = 'auto';
            metrics = converter.adc.analyzeDynamicMetrics(code, config);
            testCase.verifyGreaterThan(metrics.dynamic.SFDR, 35);
            testCase.verifyLessThan(metrics.dynamic.SFDR, 45);
        end

        function interpolatesThreeDbCrossing(testCase)
            frequency = [1e6; 2e6; 4e6];
            relativeDb = [0; -1; -5];
            expected = 10^(log10(2e6) + 0.5*(log10(4e6)-log10(2e6)));
            actual = converter.adc.findThreeDbCrossing(frequency, relativeDb);
            testCase.verifyEqual(actual, expected, 'RelTol', 1e-12);
        end

        function warnsWhenBandwidthDoesNotCross(testCase)
            testCase.verifyWarning(@() converter.adc.findThreeDbCrossing( ...
                [1e6; 2e6; 4e6], [0; -1; -2]), ...
                'converter:adc:NoThreeDbCrossing');
        end

        function fitsLowFrequencySweepAtKnownSetpoints(testCase)
            config = adcCoreTest.bandwidthConfig();
            fileFrequencyHz = [400; 600; 800; 10e3; 20e3];
            amplitudeCode = [1000; 1000; 1000; 900; 600];
            sampleCount = 8192;
            adcCodeList = cell(numel(fileFrequencyHz), 1);
            fileNames = cell(numel(fileFrequencyHz), 1);
            for pointIndex = 1:numel(fileFrequencyHz)
                adcCodeList{pointIndex} = adcCoreTest.sineCode( ...
                    amplitudeCode(pointIndex), fileFrequencyHz(pointIndex), ...
                    config.sampleRate, sampleCount);
                fileNames{pointIndex} = sprintf('%gHz.csv', ...
                    fileFrequencyHz(pointIndex));
            end

            [results, details] = converter.adc.calculateBandwidth( ...
                adcCodeList, fileNames, fileFrequencyHz, config);

            testCase.verifyTrue(all(results.ValidForBandwidth));
            testCase.verifyEqual(details.referenceCodePp, 2000, ...
                'AbsTol', 1e-3);
            testCase.verifyGreaterThan(details.bandwidth3dBHz, 10e3);
            testCase.verifyLessThan(details.bandwidth3dBHz, 20e3);
        end

        function excludesFrequencyMismatchFromBandwidth(testCase)
            config = adcCoreTest.bandwidthConfig();
            config.referencePointCount = 2;
            config.rejectFrequencyMismatch = true;
            fileFrequencyHz = [1e6; 2e6; 5e6];
            actualFrequencyHz = [1e6; 2e6; 4e6];
            adcCodeList = cell(3, 1);
            for pointIndex = 1:3
                adcCodeList{pointIndex} = adcCoreTest.sineCode( ...
                    1000 - 100 * pointIndex, actualFrequencyHz(pointIndex), ...
                    config.sampleRate, 8192);
            end

            results = converter.adc.calculateBandwidth(adcCodeList, ...
                {'1MHz.csv'; '2MHz.csv'; '5MHz.csv'}, ...
                fileFrequencyHz, config);

            testCase.verifyTrue(results.FrequencyMismatchFlag(3));
            testCase.verifyFalse(results.ValidForBandwidth(3));
        end

        function rejectsDuplicateIsolationChannels(testCase)
            config = adcCoreTest.isolationConfig();
            code = adcCoreTest.sineCode(1000, 1e6, config.sampleRate, 4096);
            testCase.verifyError(@() converter.adc.calculateIsolation( ...
                {code; code}, {'X3G'; 'X3G'}, 'X3G', config), ...
                'converter:adc:DuplicateChannels');
        end

        function detectsInsufficientInlSamples(testCase)
            config = adcCoreTest.inlConfig();
            testCase.verifyError(@() converter.adc.calculateInlDnl( ...
                {zeros(15, 1)}, {'short.csv'}, 'X3G', config), ...
                'converter:adc:InsufficientSamples');
        end

        function reportsLowInlCoverage(testCase)
            config = adcCoreTest.inlConfig();
            code = round(adcCoreTest.sineCode(7000, ...
                config.sampleRate * 4 / 64, config.sampleRate, 64));
            [results, ~] = converter.adc.calculateInlDnl( ...
                {code}, {'sparse.csv'}, 'X3G', config);
            testCase.verifyLessThan(results.CoverageRatio, 0.01);
        end

        function combinesIndependentInlRecords(testCase)
            config = adcCoreTest.inlConfig();
            firstCode = adcCoreTest.sineCode(6000, 1e6, ...
                config.sampleRate, 8192);
            secondCode = adcCoreTest.sineCode(6500, 1.1e6, ...
                config.sampleRate, 8192) + 200;

            [results, details] = converter.adc.calculateInlDnl( ...
                {firstCode; secondCode}, {'first.csv'; 'second.csv'}, ...
                'X3G', config);

            testCase.verifyEqual(results.ValidCaptureCount, 2);
            testCase.verifyEqual(height(details.captureTable), 2);
            testCase.verifyNotEqual(details.captureTable.AmplitudeCode(1), ...
                details.captureTable.AmplitudeCode(2));
            testCase.verifyFalse(isempty(details.curveTable));
        end

        function excludesLowQualityInlRecord(testCase)
            config = adcCoreTest.inlConfig();
            config.minimumValidCaptureFraction = 0.5;
            goodCode = adcCoreTest.sineCode(6000, 1e6, ...
                config.sampleRate, 8192);
            time = (0:8191)' / config.sampleRate;
            poorCode = goodCode + 1500 * sign(sin(2*pi*2e6*time));

            [results, details] = converter.adc.calculateInlDnl( ...
                {goodCode; poorCode}, {'good.csv'; 'poor.csv'}, ...
                'X3G', config);

            testCase.verifyEqual(results.ValidCaptureCount, 1);
            testCase.verifyTrue(details.captureTable.UsedForInlDnl(1));
            testCase.verifyFalse(details.captureTable.UsedForInlDnl(2));
            testCase.verifyTrue(contains(details.captureTable.Status(2), ...
                "FitR2BelowMinimum"));
            testCase.verifyFalse(isempty(details.curveTable));
        end

        function withholdsCurveBelowCaptureFraction(testCase)
            config = adcCoreTest.inlConfig();
            goodCode = adcCoreTest.sineCode(6000, 1e6, ...
                config.sampleRate, 8192);
            time = (0:8191)' / config.sampleRate;
            poorCode = goodCode + 1500 * sign(sin(2*pi*2e6*time));

            [results, details] = converter.adc.calculateInlDnl( ...
                {goodCode; poorCode}, {'good.csv'; 'poor.csv'}, ...
                'X3G', config);

            testCase.verifyEqual(results.Status, ...
                "CaptureQualityBelowMinimum");
            testCase.verifyTrue(isempty(details.curveTable));
        end
    end

    methods (Static, Access = private)
        function config = dynamicConfig()
            config = struct('sampleRate', 25e6, 'nfft', 128*1024, ...
                'adcFullScalePeakCode', 8192, ...
                'dcSpan', 16, 'signalSpan', 16, 'harmonicSpan', 8, ...
                'maxHarmonicOrder', 8, 'fitCycles', 20, ...
                'minimumFitSamples', 1024);
        end

        function config = isolationConfig()
            config = struct('sampleRate', 25e6, 'adcBits', 14, ...
                'isolationFrequencyHz', 1e6, ...
                'frequencyMismatchTolerance', 0.02, ...
                'minimumIsolationDb', 40, 'fitCycles', 20, ...
                'minimumFitSamples', 1024, 'nfft', 128*1024, ...
                'dcSpan', 16, 'signalSpan', 16, 'harmonicSpan', 8, ...
                'maxHarmonicOrder', 8);
        end

        function config = bandwidthConfig()
            config = struct('sampleRate', 25e6, 'adcBits', 14, ...
                'minimumFitR2', 0.99, 'referencePointCount', 3, ...
                'frequencyMismatchTolerance', 0.02, 'fitCycles', 20, ...
                'minimumFitSamples', 1024, 'clippingMarginCode', 1, ...
                'rejectFrequencyMismatch', false, ...
                'bandwidthFrequencySource', 'measured');
        end

        function config = inlConfig()
            config = struct('sampleRate', 25e6, 'adcBits', 14, ...
                'marginCode', 0, 'minimumFitR2', 0.99, ...
                'frequencyRefinementCycles', 20, ...
                'frequencyRefinementMinimumSamples', 1024, ...
                'minimumValidCaptureFraction', 1.0, ...
                'glitchSigmaMultiplier', 10, ...
                'glitchMinimumThresholdCode', 128, ...
                'maximumGlitchFraction', 1.0, ...
                'clippingMarginCode', 1, ...
                'recordsAreSampleContiguous', false);
        end

        function code = sineCode(amplitude, frequencyHz, sampleRate, count)
            time = (0:count-1)' / sampleRate;
            code = amplitude * sin(2*pi*frequencyHz*time + 0.21);
        end
    end
end

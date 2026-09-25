classdef adcMethodGuardsTest < matlab.unittest.TestCase
    %ADCMETHODGUARDSTEST Independent synthetic checks for method safeguards.
    methods (Test)
        function thdUsesHarmonicToFundamentalPower(testCase)
            c = adcMethodGuardsTest.config();
            n = (0:c.nfft-1)';
            x = 1000*sin(2*pi*300*n/c.nfft) + 10*sin(2*pi*600*n/c.nfft);
            m = converter.adc.analyzeDynamicMetrics(x, c);
            testCase.verifyEqual(m.dynamic.THD, -40, 'AbsTol', 1e-6);
        end

        function dcExcludedBeforeFundamentalSearch(testCase)
            c = adcMethodGuardsTest.config();
            n = (0:c.nfft-1)';
            x = 10000*sin(2*pi*5*n/c.nfft) + 1000*sin(2*pi*300*n/c.nfft);
            m = converter.adc.analyzeDynamicMetrics(x, c);
            testCase.verifyEqual(m.spectrum.fundamentalIndex, 301);
        end

        function nyquistSpurRemainsSearchable(testCase)
            c = adcMethodGuardsTest.config();
            n = (0:c.nfft-1)';
            x = 1000*sin(2*pi*300*n/c.nfft) + 10*cos(pi*n);
            m = converter.adc.analyzeDynamicMetrics(x, c);
            testCase.verifyEqual(m.dynamic.SFDR, 40, 'AbsTol', 1e-6);
            testCase.verifyGreaterThan(m.spectrum.largestSpurFrequencyHz, .49*c.sampleRate);
        end

        function overlappingDcAndSignalMasksRejected(testCase)
            c = adcMethodGuardsTest.config();
            n = (0:c.nfft-1)';
            x = 1000*sin(2*pi*20*n/c.nfft);
            testCase.verifyError(@() converter.adc.analyzeDynamicMetrics(x,c), ...
                'converter:adc:OverlappingSpectrumMasks');
        end

        function isolationMismatchCannotPass(testCase)
            c = adcMethodGuardsTest.config();
            c.adcBits = 16;
            c.isolationFrequencyHz = 1000;
            c.frequencyMismatchTolerance = .02;
            c.minimumIsolationDb = 40;
            n = (0:c.nfft-1)';
            x = 1000*sin(2*pi*300*n/c.nfft);
            r = converter.adc.calculateIsolation({x; x/1000}, {'a';'b'}, 'a', c);
            testCase.verifyTrue(r.ThresholdMet);
            testCase.verifyFalse(r.Pass);
            testCase.verifyFalse(r.MeasurementValid);
            testCase.verifyEqual(r.FormalConclusion, "暂不能判定");
        end

        function sparsePhaseCoverageNotOk(testCase)
            c = adcMethodGuardsTest.config();
            c.adcBits = 14; c.marginCode = 0; c.minimumFitR2 = .99;
            c.frequencyRefinementCycles = 20;
            c.frequencyRefinementMinimumSamples = 1024;
            c.minimumValidCaptureFraction = 1;
            c.glitchSigmaMultiplier = 10; c.glitchMinimumThresholdCode = 128;
            c.maximumGlitchFraction = 1; c.clippingMarginCode = 1;
            c.recordsAreSampleContiguous = false;
            n = (0:8191)';
            x = round(7000*sin(2*pi*n/16+.21));
            r = converter.adc.calculateInlDnl({x}, {'sparse.csv'}, 'a', c);
            testCase.verifyLessThan(r.CoverageRatio, .01);
            testCase.verifyEqual(r.Status, "IncompleteCodeCoverage");
        end

        function nyquistBandwidthPointRetainedByDefault(testCase)
            c = adcMethodGuardsTest.config();
            c.adcBits = 16; c.minimumFitR2 = .9;
            c.referencePointCount = 3; c.frequencyMismatchTolerance = .02;
            c.clippingMarginCode = 1; c.rejectFrequencyMismatch = false;
            n = (0:1023)';
            x = 1000*sin(2*pi*41*n/1024);  % ~3994 Hz alias of a 60 kHz input
            r = converter.adc.calculateBandwidth({x}, {'60kHz.csv'}, 60000, c);
            testCase.verifyEqual(height(r), 1);
            testCase.verifyTrue(r.NyquistOrAboveFlag);
            testCase.verifyTrue(r.ValidForBandwidth);
            testCase.verifyEqual(r.RelativeDb, 0, 'AbsTol', 1e-9);
            testCase.verifyTrue(isnan(r.Bandwidth3dBHz));
        end

        function nyquistBandwidthPointExcludedOnlyWhenConfigured(testCase)
            c = adcMethodGuardsTest.config();
            c.adcBits = 16; c.minimumFitR2 = .9;
            c.referencePointCount = 3; c.frequencyMismatchTolerance = .02;
            c.clippingMarginCode = 1; c.rejectFrequencyMismatch = false;
            c.rejectNyquistOrAbove = true;
            n = (0:1023)';
            x = 1000*sin(2*pi*41*n/1024);  % ~3994 Hz alias of a 60 kHz input
            r = converter.adc.calculateBandwidth({x}, {'60kHz.csv'}, 60000, c);
            testCase.verifyTrue(r.NyquistOrAboveFlag);
            testCase.verifyFalse(r.ValidForBandwidth);
            testCase.verifyTrue(isnan(r.RelativeDb));
            testCase.verifyTrue(isnan(r.Bandwidth3dBHz));
        end
    end
    methods (Static, Access = private)
        function c = config()
            c = struct('sampleRate',100000,'nfft',8192, ...
                'fitMode','auto','adcFullScalePeakCode',32768, ...
                'dcSpan',16,'signalSpan',16,'harmonicSpan',8, ...
                'maxHarmonicOrder',8,'fitCycles',20,'minimumFitSamples',1024);
        end
    end
end

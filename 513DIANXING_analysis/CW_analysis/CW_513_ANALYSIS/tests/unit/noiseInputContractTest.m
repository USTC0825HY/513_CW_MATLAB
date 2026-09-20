classdef noiseInputContractTest < matlab.unittest.TestCase
    % Regress channel selection, compressed MAT input and noise coverage.
    properties
        Folder
    end
    methods (TestMethodSetup)
        function prepare(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, '_shared')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'noise_chain_hy')));
            testCase.Folder = tempname;
            mkdir(testCase.Folder);
            testCase.addTeardown(@() rmdir(testCase.Folder, 's'));
        end
    end
    methods (Test)
        function repeatedCodeLevelsDoNotEstablishScale(testCase)
            Tinterval = 0.001; A = sin(2*pi*10*(0:999)'*Tinterval);
            first = fullfile(testCase.Folder, 'code_1000_a.mat'); save(first,'A','Tinterval');
            A = 2*A;
            second = fullfile(testCase.Folder, 'code_1000_b.mat'); save(second,'A','Tinterval');
            cfg = struct('deviceId','DA_TEST','analysisId','scale','version','test', ...
                'sampleRate',1000,'dacCodeBits',16,'dataFolder',testCase.Folder, ...
                'outputFolder',fullfile(testCase.Folder,'results'), ...
                'inputFiles',{{first,second}},'hardwareGain',1,'toneFrequencyHz',10, ...
                'minimumFitR2',0.98,'minimumCodeVpp',1,'maximumCodeVpp',65536);
            result = converter.dac.runScale(cfg);
            testCase.verifyTrue(isnan(result.summary.slope_v_per_code_vpp));
            testCase.verifyEqual(result.summary.formal_conclusion,"未测试");
        end
        function toneOutsideNyquistIsRejected(testCase)
            y = sin((0:99)');
            testCase.verifyError(@() converter.dac.fitTone(y, 1000, 500), ...
                'converter:dac:ToneOutsideNyquist');
            testCase.verifyError(@() converter.dac.fitTone(y, 1000, 1001), ...
                'converter:dac:ToneOutsideNyquist');
        end
        function rejectsNonfiniteSamples(testCase)
            A = [1; NaN; 3]; Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'invalid.mat'); save(file, 'A', 'Tinterval');
            testCase.verifyError(@() converter.io.loadPicoMat(file), 'converter:io:NonfiniteWaveform');
        end
        function explicitMissingChannelDoesNotFallback(testCase)
            B = (1:20)'; Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'onlyB.mat'); save(file, 'B', 'Tinterval');
            testCase.verifyError(@() converter.io.loadPicoMat(file, 'A'), 'converter:io:VariableMissing');
            capture = converter.io.loadPicoMat(file);
            testCase.verifyEqual(capture.variableName, 'B');
        end
        function ambiguousChannelsRequireSelection(testCase)
            A = (1:20)'; B = 2*A; Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'two.mat'); save(file, 'A', 'B', 'Tinterval');
            testCase.verifyError(@() converter.io.loadPicoMat(file), 'converter:io:VariableAmbiguous');
            capture = converter.io.loadPicoMat(file, 'B', 1, false);
            testCase.verifyEqual(capture.voltage, B, 'AbsTol', eps);
        end
        function gainIsAppliedExactlyOnce(testCase)
            A = sin((0:999)'*0.01); Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'gain.mat'); save(file, 'A', 'Tinterval');
            unscaled = converter.io.loadPicoMat(file, 'A', 1, true);
            corrected = converter.io.loadPicoMat(file, 'A', 100, true);
            testCase.verifyEqual(corrected.voltage, unscaled.voltage/100, 'AbsTol', 1e-15);
            testCase.verifyEqual(sum(corrected.voltage.^2), sum(unscaled.voltage.^2)/10000, 'AbsTol', 1e-14);
        end
        function acceptsCompressedMatInChain(testCase)
            A = zeros(20000, 1); Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'compressed.mat'); save(file, 'A', 'Tinterval', '-v7');
            info = dir(file);
            testCase.verifyLessThan(info.bytes, 8*numel(A));
            result = adc_input_equiv_noise_analysis(chainConfig(testCase.Folder, file));
            testCase.verifyEqual(result.summary.sample_count, numel(A));
            testCase.verifyTrue(result.summary.asd_coverage_adequate);
            testCase.verifyTrue(isfile(result.summary.spectrum_file));
        end
        function shortChainRecordIsNotOneHzEvidence(testCase)
            A = sin((0:99)'*0.3); Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'short.mat'); save(file, 'A', 'Tinterval', '-v7');
            result = adc_input_equiv_noise_analysis(chainConfig(testCase.Folder, file));
            testCase.verifyFalse(result.summary.asd_coverage_adequate);
            testCase.verifyEqual(result.summary.formal_state, "暂不能判定");
            testCase.verifyEqual(result.summary.asd_check_actual_hz, 0, 'AbsTol', eps);
        end
        function ambiguousChainFailsWithoutSuccessMarker(testCase)
            A = zeros(20000,1); B = A; Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'two.mat'); save(file, 'A', 'B', 'Tinterval');
            result = adc_input_equiv_noise_analysis(chainConfig(testCase.Folder, file));
            testCase.verifyEqual(result.summary.formal_state, "暂不能判定");
            testCase.verifyEmpty(char(result.summary.spectrum_file));
            testCase.verifyFalse(isfile(fullfile(result.runFolder, 'STATUS_SUCCESS.txt')));
            testCase.verifyNotEmpty(dir(fullfile(result.runFolder, '**', 'STATUS_FAILED.txt')));
        end
        function uncoveredDacBandCannotReportPass(testCase)
            A = sin(2*pi*10*(0:19999)'/1000); Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'dac.mat'); save(file, 'A', 'Tinterval');
            config = dacConfig(testCase.Folder, file);
            config.integratedBandHz = [100, 1000];
            result = converter.dac.runNoise(config);
            testCase.verifyFalse(result.summary.requested_band_fully_covered);
            testCase.verifyEqual(result.summary.integrated_judgment, "暂不能判定");
            testCase.verifyEqual(result.summary.formal_conclusion, "暂不能判定");
        end
        function narrowDacBandDoesNotBecomeZeroRms(testCase)
            A = sin(2*pi*10*(0:19999)'/1000); Tinterval = 0.001;
            file = fullfile(testCase.Folder, 'dac.mat'); save(file, 'A', 'Tinterval');
            config = dacConfig(testCase.Folder, file);
            config.integratedBandHz = [100, 100.1];
            result = converter.dac.runNoise(config);
            testCase.verifyTrue(isnan(result.summary.integrated_noise_uVrms));
            testCase.verifyEqual(result.summary.integrated_judgment, "暂不能判定");
        end
    end
end

function config = chainConfig(folder, file)
row = struct('device','TEST','interface','CH1','slope',1e-4, ...
    'intercept',0,'r2',1,'dataGroup','synthetic');
config = struct('analysisId','noise_contract','version','test', ...
    'outputRoot',fullfile(folder,'results'), 'adcCalibrationRows',row, ...
    'adcCalibrationSource','synthetic','kDacVPerCodePp',1e-4, ...
    'formalEnabled',false,'entries', ...
    struct('device','TEST','interface','CH1','matFile',file));
end

function config = dacConfig(folder, file)
config = struct('deviceId','DA_TEST','analysisId','noise','version','test', ...
    'sampleRate',1000,'dacCodeBits',16, ...
    'dataFolder',folder,'outputFolder',fullfile(folder,'results'), ...
    'inputFiles',{{file}},'hardwareGain',100,'removeMean',true, ...
    'targetResolutionHz',0.2,'overlapRatio',0.5,'windowType','hann', ...
    'asdCheckHz',1,'minimumAsdSegmentCount',4,'maximumAsdBinRelativeError',0.25, ...
    'asdLimit_uVPerSqrtHz',1e9,'formalEnabled',true,'asdOnly',false, ...
    'integratedLimit_uVrms',1e9,'integratedBandHz',[1 100]);
end

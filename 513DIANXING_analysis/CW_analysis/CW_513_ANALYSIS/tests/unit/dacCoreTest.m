classdef dacCoreTest < matlab.unittest.TestCase
    %DACCORETEST Regression tests for the portable DA core.
    methods (Test)
        function fixedToneFitIsRecovered(testCase)
            sampleRate = 250e3;
            time = (0:4095)' / sampleRate;
            expectedVpp = 1.2;
            voltage = 0.5 * expectedVpp * sin(2*pi*1e3*time + 0.37);
            fit = converter.dac.fitTone(voltage, sampleRate, 1e3);
            testCase.verifyEqual(fit.vppV, expectedVpp, 'AbsTol', 1e-10);
            testCase.verifyGreaterThan(fit.rSquared, 1 - 1e-12);
        end

        function picoMatLoaderUsesTinterval(testCase)
            folder = [tempname '_cw513_dac_loader']; mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
            A = [1; 2; NaN; 4]; Tinterval = 1 / 1000;
            filePath = fullfile(folder, 'capture.mat');
            save(filePath, 'A', 'Tinterval');
            capture = converter.dac.loadPicoMat(filePath, 'A', 2, true);
            testCase.verifyEqual(capture.sampleRateHz, 1000, 'AbsTol', eps);
            testCase.verifyEqual(capture.droppedNonfinite, 1);
            testCase.verifyEqual(mean(capture.voltage), 0, 'AbsTol', eps);
        end

        function scaleEntryWritesTraceableResult(testCase)
            [folder, files] = makeToneFiles(testCase, 250e3, [10000, 20000]);
            outputFolder = fullfile(folder, 'results');
            config = struct('deviceId', 'DA9726', 'analysisId', 'scale', ...
                'version', 'test', 'dataFolder', folder, ...
                'outputFolder', outputFolder, 'filePattern', '*.mat', ...
                'inputFiles', {files}, 'dataVariables', {{}}, ...
                'hardwareGain', 1, 'removeMean', true, 'sampleRate', 250e3, ...
                'adcBits', 16, 'adcCodeFormat', 'voltage', 'dacCodeBits', 16, ...
                'toneFrequencyHz', 1e3, 'minimumFitR2', 0.9, ...
                'minimumCodeVpp', 1, 'maximumCodeVpp', 2^17);
            result = converter.dac.runScale(config);
            testCase.verifyEqual(result.summary.fit_point_count, 2);
            testCase.verifyTrue(isfile(fullfile(result.outputFolder, ...
                'STATUS_SUCCESS.txt')));
        end

        function hexUnsignedCodeNamesAreSignExtended(testCase)
            [folder, files] = makeHexToneFiles(testCase, 250e3);
            config = struct('deviceId', 'DA766', 'analysisId', 'scale', ...
                'version', 'test', 'dataFolder', folder, ...
                'outputFolder', fullfile(folder, 'results'), 'filePattern', '*.mat', ...
                'inputFiles', {files}, 'dataVariables', {{}}, ...
                'hardwareGain', 1, 'removeMean', true, 'sampleRate', 250e3, ...
                'adcBits', 16, 'adcCodeFormat', 'voltage', 'dacCodeBits', 16, ...
                'codeNameFormat', 'hex_unsigned', ...
                'codeVppDefinition', 'twice_abs_signed_code', ...
                'toneFrequencyHz', 1e3, 'minimumFitR2', 0.9, ...
                'minimumCodeVpp', 1, 'maximumCodeVpp', 2^17);
            result = converter.dac.runScale(config);
            [~, order] = sort(result.measurements.raw_code);
            testCase.verifyEqual(result.measurements.raw_code(order)', [4096, 32768]);
            testCase.verifyEqual(result.measurements.signed_code(order)', ...
                [4096, -32768]);
            testCase.verifyEqual(result.measurements.code_vpp(order)', ...
                [8192, 65536]);
        end

        function isolationWithoutManifestIsUncertain(testCase)
            folder = [tempname '_cw513_dac_isolation']; mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
            config = struct('deviceId', 'DA9726', 'analysisId', 'isolation', ...
                'version', 'test', 'dataFolder', folder, ...
                'outputFolder', fullfile(folder, 'results'), 'pairManifest', [], ...
                'sampleRate', 250e3, 'adcBits', 16, 'adcCodeFormat', 'voltage', ...
                'hardwareGain', 1, 'minimumIsolationDb', 40, ...
                'formalEnabled', false);
            result = converter.dac.runIsolation(config);
            testCase.verifyEqual(result.summary.status, "未测试");
            testCase.verifyTrue(isfile(fullfile(result.outputFolder, ...
                'STATUS_SUCCESS.txt')));
        end

        function asdOnlySpectrumHasNoPsdColumn(testCase)
            folder = [tempname '_cw513_dac_noise']; mkdir(folder);
            cleanup = onCleanup(@() rmdir(folder, 's')); %#ok<NASGU>
            sampleRate = 1000; time = (0:4095)' / sampleRate;
            A = 1e-6 * randn(size(time)); Tinterval = 1 / sampleRate;
            save(fullfile(folder, 'noise.mat'), 'A', 'Tinterval');
            config = struct('deviceId', 'DA9726', 'analysisId', 'noise', ...
                'version', 'test', 'dataFolder', folder, ...
                'outputFolder', fullfile(folder, 'results'), 'filePattern', '*.mat', ...
                'inputFiles', {{}}, 'dataVariables', {{}}, 'hardwareGain', 1, ...
                'removeMean', true, 'sampleRate', sampleRate, 'adcBits', 16, ...
                'adcCodeFormat', 'voltage', 'targetResolutionHz', 1, ...
                'overlapRatio', 0.5, 'windowType', 'hann', ...
                'minimumAsdSegmentCount', 4, 'maximumAsdBinRelativeError', 0.25, ...
                'asdCheckHz', 1, 'asdLimit_uVPerSqrtHz', 75, ...
                'integratedBandHz', [10, 100], 'integratedLimit_uVrms', 120, ...
                'asdOnly', true, 'formalEnabled', false);
            result = converter.dac.runNoise(config);
            spectrum = dir(fullfile(result.outputFolder, '*ASD_spectrum.csv'));
            header = fileread(fullfile(spectrum.folder, spectrum.name));
            testCase.verifyFalse(~isempty(strfind(lower(header), 'psd'))); %#ok<STREMP>
        end
    end
end

function [folder, files] = makeHexToneFiles(testCase, sampleRate)
folder = [tempname '_cw513_dac_hex_scale']; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
time = (0:4095)' / sampleRate;
rawCodes = [hex2dec('1000'), hex2dec('8000')];
signedCodes = [4096, -32768];
files = cell(numel(rawCodes), 1);
for k = 1:numel(rawCodes)
    A = (signedCodes(k) / 32768) * sin(2*pi*1e3*time);
    Tinterval = 1 / sampleRate;
    files{k} = sprintf('capture_CODE%04X.mat', rawCodes(k));
    save(fullfile(folder, files{k}), 'A', 'Tinterval');
end
end

function [folder, files] = makeToneFiles(testCase, sampleRate, codes)
folder = [tempname '_cw513_dac_scale']; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
time = (0:4095)' / sampleRate;
files = cell(numel(codes), 1);
for k = 1:numel(codes)
    A = (codes(k) / 20000) * sin(2*pi*1e3*time);
    Tinterval = 1 / sampleRate;
    files{k} = sprintf('capture_code_%d.mat', codes(k));
    save(fullfile(folder, files{k}), 'A', 'Tinterval');
end
end

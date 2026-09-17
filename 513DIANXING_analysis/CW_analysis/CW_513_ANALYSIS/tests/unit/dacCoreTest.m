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

        function hexCodeNamesAllowAcquisitionMetadata(testCase)
            [folder, files] = makeHexMetadataToneFiles(testCase, 250e3);
            config = struct('deviceId', 'DA9726', 'analysisId', 'scale', ...
                'version', 'test', 'dataFolder', folder, ...
                'outputFolder', fullfile(folder, 'results'), 'filePattern', '*.mat', ...
                'inputFiles', {files}, 'dataVariables', {{}}, ...
                'hardwareGain', 1, 'removeMean', true, 'sampleRate', 250e3, ...
                'adcBits', 16, 'adcCodeFormat', 'voltage', 'dacCodeBits', 16, ...
                'codeNameFormat', 'hex_unsigned', ...
                'codeVppDefinition', 'raw_unsigned_code', ...
                'toneFrequencyHz', 1e3, 'minimumFitR2', 0.9, ...
                'minimumCodeVpp', 1, 'maximumCodeVpp', 2^16);
            result = converter.dac.runScale(config);
            [~, order] = sort(result.measurements.raw_code);
            testCase.verifyEqual(result.measurements.raw_code(order)', [4096, 57344]);
            testCase.verifyEqual(result.measurements.signed_code(order)', [4096, -8192]);
            testCase.verifyEqual(result.measurements.code_vpp(order)', [4096, 57344]);
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

        function multichannelIsolationSplitIsTraceable(testCase)
            rootFolder = [tempname '_cw513_dac_split']; mkdir(rootFolder);
            testCase.addTeardown(@() rmdir(rootFolder, 's'));
            dataFolder = fullfile(rootFolder, 'JG18-1K'); mkdir(dataFolder);
            sampleRate = 20e3; sampleCount = 4096;
            time = (0:sampleCount - 1)' / sampleRate;
            actualFrequency = 1001.25;
            A = single(1.2 * sin(2*pi*actualFrequency*time));
            B = single(1e-2 * sin(2*pi*actualFrequency*time + 0.1));
            C = single(5e-3 * sin(2*pi*actualFrequency*time + 0.2));
            D = single(2e-3 * sin(2*pi*actualFrequency*time + 0.3));
            Tinterval = 1 / sampleRate; Tstart = -0.01;
            longName = 'JG18-JG20-JG21-JG23-capture.mat';
            save(fullfile(dataFolder, longName), ...
                'A', 'B', 'C', 'D', 'Tinterval', 'Tstart');
            D = single(1e-3 * sin(2*pi*actualFrequency*time + 0.4));
            shortName = 'JG25-capture.mat';
            save(fullfile(dataFolder, shortName), 'D', 'Tinterval', 'Tstart');

            options = struct('referencePlane', 'synthetic common 50 ohm plane');
            splitResult = split_dac_isolation_channels(dataFolder, ...
                {longName, shortName}, fullfile(rootFolder, 'split'), options);

            testCase.verifyFalse(isfield(splitResult, 'analysisReady'));
            testCase.verifyEqual(height(splitResult.channelRows), 5);
            testCase.verifyEqual(string(splitResult.channelRows.channel_label)', ...
                ["JG18", "JG20", "JG21", "JG23", "JG25"]);
            jg20Row = splitResult.channelRows( ...
                strcmpi(string(splitResult.channelRows.channel_label), 'JG20'), :);
            splitData = load(fullfile(splitResult.outputFolder, jg20Row.output_file));
            sourceData = load(fullfile(dataFolder, longName), 'B', 'Tinterval');
            testCase.verifyEqual(splitData.A, sourceData.B);
            testCase.verifyEqual(splitData.Tinterval, sourceData.Tinterval);
            testCase.verifyEqual(splitData.SourceVariable, 'B');

            rows = splitResult.channelRows;
            pairs = table(repmat(rows.output_file(1),4,1),rows.output_file(2:end), ...
                repmat("A",4,1),repmat("A",4,1),repmat(actualFrequency,4,1), ...
                repmat("JG18",4,1),rows.channel_label(2:end), ...
                repmat("synthetic common 50 ohm plane",4,1), ...
                'VariableNames',{'driven_file','victim_file','driven_variable', ...
                'victim_variable','frequency_hz','driven_label','victim_label','reference_plane'});
            isolation = dac_isolation_analysis(splitResult.outputFolder, ...
                pairs, fullfile(rootFolder, 'results'), struct('hardwareGain', 1));
            testCase.verifyEqual(height(isolation.summary), 4);
            testCase.verifyEqual(isolation.summary.frequency_hz, ...
                repmat(actualFrequency, 4, 1), 'AbsTol', 1e-9);
            testCase.verifyGreaterThan(isolation.summary.driven_fit_r2, 0.999);
            testCase.verifyTrue(isfile(fullfile(isolation.outputFolder, ...
                'dac_isolation_matrix_db.csv')));
            testCase.verifyEqual(size(isolation.isolationMatrix.valuesDb), [1, 4]);
            testCase.verifyEqual(isolation.isolationMatrix.valuesDb, ...
                isolation.summary.isolation_db', 'AbsTol', 1e-12);
        end

        function splitWithoutDriveOrFolderConvention(testCase)
            rootFolder = [tempname '_cw513_dac_split_template']; mkdir(rootFolder);
            testCase.addTeardown(@() rmdir(rootFolder, 's'));
            dataFolder = fullfile(rootFolder, 'arbitrary_folder'); mkdir(dataFolder);
            sampleRate = 20e3; time = (0:2047)' / sampleRate;
            A = sin(2*pi*1e3*time); B = 1e-3 * A; Tinterval = 1 / sampleRate;
            fileName = 'JG18-JG20-capture.mat';
            save(fullfile(dataFolder, fileName), 'A', 'B', 'Tinterval');

            splitResult = split_dac_isolation_channels(dataFolder, {fileName}, ...
                fullfile(rootFolder, 'split'), struct());
            testCase.verifyEqual(height(splitResult.channelRows), 2);
            testCase.verifyFalse(isfield(splitResult,'pairManifestPath'));
            testCase.verifyFalse(isfile(fullfile(splitResult.outputFolder, ...
                'pair_manifest_template.csv')));
        end

        function ambiguousIsolationFilenameIsRejected(testCase)
            rootFolder = [tempname '_cw513_dac_split_bad']; mkdir(rootFolder);
            testCase.addTeardown(@() rmdir(rootFolder, 's'));
            dataFolder = fullfile(rootFolder, 'JG18-1K'); mkdir(dataFolder);
            A = (1:32)'; B = A; Tinterval = 1e-4;
            fileName = 'JG18-capture.mat';
            save(fullfile(dataFolder, fileName), 'A', 'B', 'Tinterval');
            testCase.verifyError(@() split_dac_isolation_channels( ...
                dataFolder, {fileName}, fullfile(rootFolder, 'split'), struct()), ...
                'converter:dac:IsolationChannelMapAmbiguous');
        end

        function automaticIsolationSelectionFindsDrivenFile(testCase)
            [dataFolder, files, actualFrequency] = ...
                makeIsolationSingleChannelFiles(testCase, [1.2, 0.01, 0.004]);
            config = makeSimpleIsolationConfig(dataFolder, files);
            [prepared, cancelled] = converter.io.prepareDacIsolation( ...
                config, dataFolder, [], fullfile(dataFolder, 'results'), ...
                struct('autoDetectDrive', true), dataFolder);

            testCase.verifyFalse(cancelled);
            testCase.verifyEqual(numel(prepared.pairManifest), 2);
            testCase.verifyEqual(string({prepared.pairManifest.driven_label}), ...
                ["JG18", "JG18"]);
            testCase.verifyEqual(string({prepared.pairManifest.victim_label}), ...
                ["JG20", "JG21"]);
            testCase.verifyEqual([prepared.pairManifest.frequency_hz], ...
                repmat(actualFrequency, 1, 2), 'AbsTol', 0.05);
            testCase.verifyGreaterThan( ...
                prepared.isolationSelection.driveSeparationDb, 10);
            testCase.verifyEqual(prepared.hardwareGain, 1);
        end

        function automaticIsolationSelectionRejectsLowConfidence(testCase)
            [dataFolder, files] = makeIsolationSingleChannelFiles( ...
                testCase, [1.0, 0.8]);
            config = makeSimpleIsolationConfig(dataFolder, files);
            testCase.verifyError(@() converter.io.prepareDacIsolation( ...
                config, dataFolder, [], fullfile(dataFolder, 'results'), ...
                struct('autoDetectDrive', true), dataFolder), ...
                'converter:dac:IsolationDriveConfidence');
        end

        function sharedToneEstimatorRecoversActualFrequency(testCase)
            sampleRate = 20e3; actualFrequency = 1001.25;
            time = (0:4095)' / sampleRate;
            voltage = 0.8 * sin(2*pi*actualFrequency*time + 0.2);
            estimate = converter.dac.estimateToneFrequency(voltage, sampleRate);
            testCase.verifyEqual(estimate.frequencyHz, actualFrequency, ...
                'AbsTol', 0.05);
            testCase.verifyGreaterThan(estimate.fit.rSquared, 0.999);
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

function config = makeSimpleIsolationConfig(dataFolder, files)
config = struct('dataFolder', dataFolder, 'outputFolder', '', ...
    'inputFiles', {files}, 'hardwareGain', 1, 'minimumFitR2', 0.98, ...
    'measurementCondition', ...
    'PicoScope输入端直接测量；无外部放大；输入阻抗和探头倍率未记录', ...
    'simpleIsolationSelection', true, 'autoDetectDrive', false, ...
    'autoDriveMinimumSeparationDb', 10);
end

function [dataFolder, files, actualFrequency] = ...
        makeIsolationSingleChannelFiles(testCase, amplitudes)
rootFolder = [tempname '_cw513_dac_auto_isolation']; mkdir(rootFolder);
testCase.addTeardown(@() rmdir(rootFolder, 's'));
dataFolder = fullfile(rootFolder, 'JG18-1K'); mkdir(dataFolder);
sampleRate = 20e3; actualFrequency = 1001.25;
time = (0:4095)' / sampleRate;
labels = {'JG18', 'JG20', 'JG21'};
files = cell(1, numel(amplitudes));
for k = 1:numel(amplitudes)
    A = amplitudes(k) * sin(2*pi*actualFrequency*time + 0.1*k); %#ok<NASGU>
    Tinterval = 1 / sampleRate; %#ok<NASGU>
    ChannelLabel = labels{k}; %#ok<NASGU>
    files{k} = [labels{k} '.mat'];
    save(fullfile(dataFolder, files{k}), 'A', 'Tinterval', 'ChannelLabel');
end
end

function [folder, files] = makeHexMetadataToneFiles(testCase, sampleRate)
folder = [tempname '_cw513_dac_hex_metadata']; mkdir(folder);
testCase.addTeardown(@() rmdir(folder, 's'));
time = (0:4095)' / sampleRate;
A = 0.25 * sin(2*pi*1e3*time);
Tinterval = 1 / sampleRate;
files = {'capture_CODE_1000_JG18_CH1.mat'; ...
    'capture_COADE_E000_JG18_CH1.mat'};
save(fullfile(folder, files{1}), 'A', 'Tinterval');
A = 0.75 * sin(2*pi*1e3*time);
save(fullfile(folder, files{2}), 'A', 'Tinterval');
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

classdef dacSplitCodeTokenTest < matlab.unittest.TestCase
    %DACSPLITCODETOKENTEST Percent-to-code naming for the DAC channel split tool.
    methods (TestClassSetup)
        function addRuntime(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, '9726_hy')));
        end
    end
    methods (Test)
        function percentBecomesCodeTokenOnAllChannels(testCase)
            [folder, files] = testCase.makeSourceMat('10%');
            out = testCase.split(folder, files, struct( ...
                'codeFromPercent', struct('fullScaleCode', 65535)));
            rows = testCase.manifest(out);
            testCase.verifyEqual(height(rows), 4);
            testCase.verifyEqual(unique(rows.code_percent), 10);
            testCase.verifyEqual(unique(rows.raw_code), 6554);
            testCase.verifyEqual(unique(rows.code_hex), "199A");
            testCase.verifySubstring(rows.code_rule(1), '65535');
            testCase.verifyEqual(numel(testCase.outputFiles(out)), 4);
        end

        function code99IsFd70(testCase)
            [folder, files] = testCase.makeSourceMat('99%');
            out = testCase.split(folder, files, struct( ...
                'codeFromPercent', struct('fullScaleCode', 65535)));
            rows = testCase.manifest(out);
            testCase.verifyEqual(unique(rows.raw_code), 64880);
            testCase.verifyEqual(unique(rows.code_hex), "FD70");
        end

        function outputNameParsesLikeRunScaleExpects(testCase)
            % Contract test mirroring runScale.localCodeFromName's hex_unsigned
            % pattern; the real scale entry is exercised by the live run.
            [folder, files] = testCase.makeSourceMat('10%');
            out = testCase.split(folder, files, struct( ...
                'codeFromPercent', struct('fullScaleCode', 65535)));
            listing = testCase.outputFiles(out);
            for k = 1:numel(listing)
                token = regexp(listing(k).name, ...
                    '(?i)(?:code|coade)[_-]?([0-9a-f]+)(?=[_-]|\.mat$)', ...
                    'tokens', 'once');
                testCase.verifyNotEmpty(token);
                testCase.verifyEqual(hex2dec(token{1}), 6554);
                testCase.verifyEqual(token{1}, '199A');
            end
        end

        function optionOffKeepsLegacyNames(testCase)
            [folder, files] = testCase.makeSourceMat('10%');
            out = testCase.split(folder, files, struct());
            rows = testCase.manifest(out);
            testCase.verifyEqual(height(rows), 4);
            testCase.verifyTrue(all(isnan(rows.code_percent)));
            hexValues = rows.code_hex;
            if isnumeric(hexValues)
                testCase.verifyTrue(all(isnan(hexValues)));
            else
                testCase.verifyTrue(all(ismissing(string(hexValues)) | ...
                    string(hexValues) == ""));
            end
            testCase.verifyTrue(all(isnan(rows.raw_code)));
            listing = testCase.outputFiles(out);
            names = {listing.name};
            testCase.verifyTrue(~any(contains(names, 'CODE_')));
            stem = strrep(char(files{1}(1:end-4)), '%', '_');
            testCase.verifyEqual(char(names{1}), ['JG20__' stem '__A.mat']);
        end

        function missingPercentFailsWhenOptionOn(testCase)
            folder = tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            S = testCase.waveformStruct();
            save(fullfile(folder, 'AD9726-no-percent.mat'), ...
                '-struct', 'S', '-v7');
            testCase.verifyError(@() testCase.split(folder, ...
                {'AD9726-no-percent.mat'}, struct( ...
                'codeFromPercent', struct('fullScaleCode', 65535))), ...
                'converter:dac:IsolationPercentMissing');
        end

        function multipleFilesWithSameLabelsSplit(testCase)
            folder = tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            S = testCase.waveformStruct();
            names = {['AD9726-scale-CH1_JG20-CH2_JG21-CH3_JG23-CH4_JG25-' ...
                '1MHz-10%.mat'], ['AD9726-scale-CH1_JG20-CH2_JG21-CH3_JG23-' ...
                'CH4_JG25-1MHz-20%.mat']};
            for k = 1:numel(names)
                save(fullfile(folder, names{k}), '-struct', 'S', '-v7');
            end
            out = testCase.split(folder, names, struct( ...
                'codeFromPercent', struct('fullScaleCode', 65535)));
            rows = testCase.manifest(out);
            testCase.verifyEqual(height(rows), 8);
            testCase.verifyEqual(numel(unique(rows.source_file)), 2);
            testCase.verifyEqual(unique(rows.code_percent), [10; 20]);
        end

        function emptyRuleStructFails(testCase)
            [folder, files] = testCase.makeSourceMat('10%');
            testCase.verifyError(@() testCase.split(folder, files, ...
                struct('codeFromPercent', struct())), ...
                'converter:dac:IsolationPercentRule');
        end
    end
    methods (Access = private)
        function [folder, files] = makeSourceMat(testCase, percentToken)
            folder = tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder, 's'));
            S = testCase.waveformStruct();
            name = ['AD9726-scale-CH1_JG20-CH2_JG21-CH3_JG23-CH4_JG25-' ...
                '1MHz-' percentToken '.mat'];
            save(fullfile(folder, name), '-struct', 'S', '-v7');
            files = {name};
        end

        function S = waveformStruct(~)
            n = 64;
            t = (0:n-1) * 5.12e-8;
            S = struct();
            S.Tinterval = 5.12e-8;
            S.Tstart = 0;
            S.Length = n;
            S.A = single(sin(2*pi*1e6*t).');
            S.B = single(2*sin(2*pi*1e6*t).');
            S.C = single(3*sin(2*pi*1e6*t).');
            S.D = single(4*sin(2*pi*1e6*t).');
        end

        function out = split(~, folder, files, options)
            out = split_dac_isolation_channels(folder, files, [], options);
        end

        function rows = manifest(~, out)
            rows = readtable(out.channelManifestPath, ...
                'Delimiter', ',', 'TextType', 'string');
        end

        function listing = outputFiles(~, out)
            listing = dir(fullfile(out.outputFolder, '*.mat'));
            listing = listing(~contains({listing.name}, 'channel_split_result'));
        end
    end
end

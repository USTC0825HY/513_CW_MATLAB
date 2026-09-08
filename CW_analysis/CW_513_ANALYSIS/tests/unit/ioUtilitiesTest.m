classdef ioUtilitiesTest < matlab.unittest.TestCase
    properties (TestParameter)
        frequencyText = {'2Hz', '3kHz', '4.5MHz', '1.25GHz'}
        frequencyExpected = {2, 3e3, 4.5e6, 1.25e9}
    end

    methods (Test, ParameterCombination = 'sequential')
        function parsesFrequencyUnits(testCase, frequencyText, frequencyExpected)
            actual = converter.io.parseFrequencyHz(frequencyText);
            testCase.verifyEqual(actual, frequencyExpected, 'RelTol', 1e-12);
        end
    end

    methods (Test)
        function parsesPowerAndChannels(testCase)
            testCase.verifyEqual(converter.io.parsePowerDbm('X3G_-7.5dBm.csv'), -7.5);
            testCase.verifyEqual(converter.io.extractChannel('capture_X4G.csv'), 'X4G');
            testCase.verifyEqual(converter.io.parseDrivenChannel('drive-X2G_test'), 'X2G');
        end

        function readsSignedCsvWithHeader(testCase)
            config = ioUtilitiesTest.adcConfig('signed', 0);
            actual = converter.io.readAdcCsv( ...
                ioUtilitiesTest.fixturePath('adc_signed_with_header.csv'), config);
            testCase.verifyEqual(actual, [-8192; -1024; 0; 1024; 8191]);
        end

        function convertsUnsignedCodes(testCase)
            config = ioUtilitiesTest.adcConfig('unsigned', 2);
            actual = converter.io.readAdcCsv( ...
                ioUtilitiesTest.fixturePath('adc_unsigned_no_header.csv'), config);
            testCase.verifyEqual(actual, [-8192; 0; 8191]);
        end

        function rejectsTextInNumericRegion(testCase)
            config = ioUtilitiesTest.adcConfig('signed', 2);
            testCase.verifyError(@() converter.io.readAdcCsv( ...
                ioUtilitiesTest.fixturePath('adc_text_in_numeric_region.csv'), config), ...
                'converter:io:NonNumericData');
        end

        function rejectsWrongColumn(testCase)
            config = ioUtilitiesTest.adcConfig('signed', 3);
            testCase.verifyError(@() converter.io.readAdcCsv( ...
                ioUtilitiesTest.fixturePath('adc_signed_with_header.csv'), config), ...
                'converter:io:ColumnOutOfRange');
        end

        function rejectsEmptyFile(testCase)
            emptyPath = [tempname '.csv'];
            fileId = fopen(emptyPath, 'w');
            fclose(fileId);
            cleanupObject = onCleanup(@() delete(emptyPath));
            config = ioUtilitiesTest.adcConfig('signed', 1);
            testCase.verifyError(@() converter.io.readAdcCsv(emptyPath, config), ...
                'converter:io:NoNumericData');
            testCase.verifyNotEmpty(cleanupObject);
        end
    end

    methods (Static, Access = private)
        function config = adcConfig(codeFormat, dataColumn)
            config = struct('adcBits', 14, 'adcCodeFormat', codeFormat, ...
                'adcDataColumn', dataColumn);
        end

        function path = fixturePath(fileName)
            testFolder = fileparts(fileparts(mfilename('fullpath')));
            path = fullfile(testFolder, 'fixtures', fileName);
        end
    end
end

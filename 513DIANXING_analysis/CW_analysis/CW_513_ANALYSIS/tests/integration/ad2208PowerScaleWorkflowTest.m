classdef ad2208PowerScaleWorkflowTest < matlab.unittest.TestCase
    %AD2208POWERSCALEWORKFLOWTEST Integration coverage for critical input.

    properties
        WorkFolder
        DataFolder
        OutputFolder
    end

    methods (TestMethodSetup)
        function createFixture(testCase)
            repositoryRoot = fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repositoryRoot, '_shared')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repositoryRoot, '2208_hy')));
            testCase.WorkFolder = string(tempname);
            testCase.DataFolder = fullfile(testCase.WorkFolder, 'raw');
            testCase.OutputFolder = fullfile(testCase.WorkFolder, 'result');
            mkdir(testCase.DataFolder);
            mkdir(testCase.OutputFolder);
            testCase.addTeardown(@() rmdir(testCase.WorkFolder, 's'));
            ad2208PowerScaleWorkflowTest.buildPowerData(testCase.DataFolder);
        end
    end

    methods (Test)
        function writesBracketedCriticalInputArtifact(testCase)
            files = ad2208PowerScaleWorkflowTest.fileNames();
            results = adc_power_scale_analysis(testCase.DataFolder, files, ...
                testCase.OutputFolder);
            criticalFiles = dir(fullfile(testCase.OutputFolder, 'run_*', ...
                'ADC_critical_input_estimate.csv'));
            critical = readtable(fullfile(criticalFiles(1).folder, ...
                criticalFiles(1).name), TextType='string');

            testCase.verifyEqual(height(results), 4);
            testCase.verifyTrue(results.ClippingFlag(end));
            testCase.verifyEqual(critical.Status, "bracketed_estimate");
            testCase.verifyEqual(critical.ThresholdFraction, 0.99, ...
                AbsTol=1e-12);
            testCase.verifyGreaterThan(critical.CriticalInputDbm, 7);
            testCase.verifyLessThan(critical.CriticalInputDbm, 8);
        end
    end

    methods (Static, Access=private)
        function buildPowerData(folder)
            powerDbm = [-10, 0, 7, 8];
            inputVpp = converter.adc.dbmToVpp(powerDbm, 50);
            amplitudeCode = 21000 * inputVpp;
            files = ad2208PowerScaleWorkflowTest.fileNames();
            for index = 1:numel(powerDbm)
                code = ad2208PowerScaleWorkflowTest.sineCode( ...
                    amplitudeCode(index), powerDbm(index) == 8);
                ad2208PowerScaleWorkflowTest.writeCsv( ...
                    folder, files{index}, code);
            end
        end

        function files = fileNames()
            files = {'JG15-1M-N10db.csv', 'JG15-1M-0db.csv', ...
                'JG15-1M-7db.csv', 'JG15-1M-8db.csv'};
        end

        function code = sineCode(amplitudeCode, applyClipping)
            sampleRate = 100e6;
            time = (0:8191)' / sampleRate;
            code = round(300 + amplitudeCode * sin(2*pi*1e6*time + 0.2));
            if applyClipping
                code = max(min(code, 32767), -32768);
            end
        end

        function writeCsv(folder, fileName, code)
            fileId = fopen(fullfile(folder, fileName), 'w');
            if fileId < 0
                error('test:CannotWriteFixture', ...
                    '无法写入 AD2208 测试 CSV：%s', fileName);
            end
            cleanupObject = onCleanup(@() fclose(fileId));
            fprintf(fileId, ['Sample in Buffer,Sample in Window,TRIGGER,' ...
                'module_yb2208_test_top_inst/yb2208_test_module[0].' ...
                'yb2208_test/yb2208_dout[15:0]\n']);
            sample = (0:numel(code)-1)';
            trigger = zeros(size(code));
            trigger(1) = 1;
            fprintf(fileId, '%d,%d,%d,%d\n', ...
                [sample, sample, trigger, code].');
            clear cleanupObject;
        end
    end
end

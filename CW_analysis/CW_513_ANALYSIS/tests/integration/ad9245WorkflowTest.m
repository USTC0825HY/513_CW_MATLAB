classdef ad9245WorkflowTest < matlab.unittest.TestCase
    properties
        WorkFolder
        DataFolders
        OutputFolders
    end

    methods (TestClassSetup)
        function createSyntheticInputs(testCase)
            testCase.WorkFolder = tempname;
            mkdir(testCase.WorkFolder);
            [testCase.DataFolders, testCase.OutputFolders] = ...
                ad9245WorkflowTest.buildAllDatasets(testCase.WorkFolder);
        end
    end

    methods (TestClassTeardown)
        function removeSyntheticInputs(testCase)
            if isfolder(testCase.WorkFolder)
                rmdir(testCase.WorkFolder, 's');
            end
        end
    end

    methods (Test)
        function runsSfdrEntry(testCase)
            files = {'X3G_1MHz.csv'};
            results = adc_sfdr_analysis(testCase.DataFolders.sfdr, files, ...
                testCase.OutputFolders.sfdr);
            testCase.verifyEqual(height(results), 1);
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.sfdr, 'ADC_SFDR_summary.csv'));
        end

        function runsBandwidthEntry(testCase)
            files = {'X3G_0.5MHz.csv', 'X3G_1MHz.csv', 'X3G_2MHz.csv', ...
                'X3G_4MHz.csv', 'X3G_6MHz.csv'};
            results = adc_bandwidth_analysis(testCase.DataFolders.bandwidth, ...
                files, testCase.OutputFolders.bandwidth);
            testCase.verifyEqual(height(results), 5);
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.bandwidth, 'ADC_bandwidth_summary.csv'));
        end

        function runsIsolationEntry(testCase)
            files = {'DRIVE_X3G_CAPTURE_X1G_1MHz.csv', ...
                'DRIVE_X3G_CAPTURE_X2G_1MHz.csv', ...
                'DRIVE_X3G_CAPTURE_X3G_1MHz.csv', ...
                'DRIVE_X3G_CAPTURE_X4G_1MHz.csv'};
            results = adc_isolation_analysis(testCase.DataFolders.isolation, ...
                files, testCase.OutputFolders.isolation);
            testCase.verifyEqual(height(results), 3);
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.isolation, 'ADC_isolation_summary.csv'));
        end

        function runsPowerScaleEntry(testCase)
            files = {'X3G_-10dBm_1MHz.csv', 'X3G_-5dBm_1MHz.csv', ...
                'X3G_0dBm_1MHz.csv', 'X3G_5dBm_1MHz.csv'};
            results = adc_power_scale_analysis(testCase.DataFolders.power, ...
                files, testCase.OutputFolders.power);
            testCase.verifyEqual(height(results), 4);
            testCase.verifyTrue(all(isfinite(results.InputVoltageVpp)));
            testCase.verifyTrue(all(isfinite(results.CalibrationSlopeVppPerCodePp)));
            testCase.verifyGreaterThan(results.CalibrationSlopeVppPerCodePp(1), 0);
            testCase.verifyTrue(all(contains(results.InputPowerDefinition, ...
                'Vpp')));
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.power, 'ADC_vpp_codepp_summary.csv'));
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.power, 'ADC_critical_input_estimate.csv'));
        end

        function runsInlDnlEntry(testCase)
            files = {'X3G_1MHz.csv'};
            results = adc_inl_dnl_analysis(testCase.DataFolders.inl, files, ...
                testCase.OutputFolders.inl);
            testCase.verifyEqual(height(results), 1);
            testCase.verifyTrue(ad9245WorkflowTest.hasSuccessRun( ...
                testCase.OutputFolders.inl, 'ADC_inl_dnl_summary.csv'));
        end
    end

    methods (Static, Access = private)
        function [dataFolders, outputFolders] = buildAllDatasets(workFolder)
            analysisNames = {'sfdr', 'bandwidth', 'isolation', 'power', 'inl'};
            for index = 1:numel(analysisNames)
                name = analysisNames{index};
                dataFolders.(name) = fullfile(workFolder, name, 'raw');
                outputFolders.(name) = fullfile(workFolder, name, 'results');
                mkdir(dataFolders.(name));
            end
            ad9245WorkflowTest.buildSfdr(dataFolders.sfdr);
            ad9245WorkflowTest.buildBandwidth(dataFolders.bandwidth);
            ad9245WorkflowTest.buildIsolation(dataFolders.isolation);
            ad9245WorkflowTest.buildPower(dataFolders.power);
            ad9245WorkflowTest.buildInl(dataFolders.inl);
        end

        function buildSfdr(folder)
            sampleRate = 25e6;
            time = (0:8191)' / sampleRate;
            code = round(4000*sin(2*pi*1e6*time) + ...
                40*sin(2*pi*2.3e6*time));
            ad9245WorkflowTest.writeCsv(folder, 'X3G_1MHz.csv', code, 2);
        end

        function buildBandwidth(folder)
            sampleRate = 20e6;
            frequencyMHz = [0.5, 1, 2, 4, 6];
            amplitude = [6000, 6000, 6000, 4000, 2000];
            for index = 1:numel(frequencyMHz)
                frequencyHz = frequencyMHz(index) * 1e6;
                code = round(ad9245WorkflowTest.sineCode( ...
                    amplitude(index), frequencyHz, sampleRate, 8192));
                fileName = sprintf('X3G_%gMHz.csv', frequencyMHz(index));
                ad9245WorkflowTest.writeCsv(folder, fileName, code, 2);
            end
        end

        function buildIsolation(folder)
            sampleRate = 25e6;
            amplitude = [5, 10, 1000, 20];
            for channel = 1:4
                code = round(ad9245WorkflowTest.sineCode( ...
                    amplitude(channel), 1e6, sampleRate, 8192));
                fileName = sprintf('DRIVE_X3G_CAPTURE_X%dG_1MHz.csv', channel);
                ad9245WorkflowTest.writeCsv(folder, fileName, code, channel - 1);
            end
        end

        function buildPower(folder)
            sampleRate = 25e6;
            powerDbm = [-10, -5, 0, 5];
            amplitude = 1000 * 10.^((powerDbm + 10) / 20);
            for index = 1:numel(powerDbm)
                code = round(ad9245WorkflowTest.sineCode( ...
                    amplitude(index), 1e6, sampleRate, 8192));
                fileName = sprintf('X3G_%gdBm_1MHz.csv', powerDbm(index));
                ad9245WorkflowTest.writeCsv(folder, fileName, code, 2);
            end
        end

        function buildInl(folder)
            sampleRate = 25e6;
            code = round(ad9245WorkflowTest.sineCode( ...
                7000, 1e6, sampleRate, 65536));
            ad9245WorkflowTest.writeCsv(folder, 'X3G_1MHz.csv', code, 2);
        end

        function code = sineCode(amplitude, frequencyHz, sampleRate, count)
            time = (0:count-1)' / sampleRate;
            code = amplitude * sin(2*pi*frequencyHz*time + 0.17);
        end

        function writeCsv(folder, fileName, code, moduleIndex)
            filePath = fullfile(folder, fileName);
            fileId = fopen(filePath, 'w');
            if fileId < 0
                error('test:CannotWriteFixture', '无法写入测试 CSV：%s', filePath);
            end
            cleanupObject = onCleanup(@() fclose(fileId));
            fprintf(fileId, 'sample,ad9245_test_module[%d]\n', moduleIndex);
            fprintf(fileId, '%d,%d\n', [(0:numel(code)-1); code(:).']);
            clear cleanupObject;
        end

        function success = hasSuccessRun(outputFolder, summaryFile)
            statusFiles = dir(fullfile(outputFolder, 'run_*', 'STATUS_SUCCESS.txt'));
            summaryFiles = dir(fullfile(outputFolder, 'run_*', summaryFile));
            manifests = dir(fullfile(outputFolder, 'run_*', 'run_manifest.csv'));
            success = ~isempty(statusFiles) && ~isempty(summaryFiles) && ...
                ~isempty(manifests);
        end
    end
end

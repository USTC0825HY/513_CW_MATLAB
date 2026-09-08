classdef ad677WorkflowTest < matlab.unittest.TestCase
    %AD677WORKFLOWTEST Public-entry integration and portability checks.

    properties
        WorkFolder
        BandwidthFolder
        PowerFolder
        RepositoryRoot
    end

    methods (TestMethodSetup)
        function buildFixture(testCase)
            testCase.RepositoryRoot = fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.RepositoryRoot, '_shared')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(testCase.RepositoryRoot, '677_hy')));
            testCase.WorkFolder = string(tempname);
            testCase.BandwidthFolder = fullfile(testCase.WorkFolder, 'bandwidth');
            testCase.PowerFolder = fullfile(testCase.WorkFolder, 'power');
            mkdir(testCase.BandwidthFolder);
            mkdir(testCase.PowerFolder);
            testCase.addTeardown(@() rmdir(testCase.WorkFolder, 's'));
            ad677WorkflowTest.buildBandwidthData(testCase.BandwidthFolder);
            ad677WorkflowTest.buildPowerData(testCase.PowerFolder);
        end
    end

    methods (Test)
        function testExplicitFilesDefaultOutputPowerCall(testCase)
            files = {'ad677_ch01_error_input_vpp_1kHz_0.25Vpp_sweep.csv', ...
                'ad677_ch01_error_input_vpp_1kHz_1.5Vpp_sweep.csv', ...
                'ad677_ch01_error_input_vpp_1kHz_2.25Vpp_sweep.csv', ...
                'ad677_ch01_error_input_vpp_1kHz_2.5Vpp_sweep.csv'};
            results = adc_power_scale_analysis(testCase.PowerFolder, files);
            testCase.verifyEqual(results.InputVoltageVpp, ...
                [0.25; 1.5; 2.25; 2.5], AbsTol=1e-12);
            testCase.verifyEqual(unique(results.Channel), "677_1");
            testCase.verifyGreaterThan(results.CalibrationR2(1), 0.999);
            testCase.verifyEqual(unique(results.Conclusion), "暂不能判定");
            testCase.verifyTrue(ad677WorkflowTest.hasSuccessfulRun( ...
                fullfile(testCase.PowerFolder, 'results')));
            criticalFiles = dir(fullfile(testCase.PowerFolder, 'results', ...
                'run_*', 'ADC_critical_input_estimate.csv'));
            testCase.verifyNotEmpty(criticalFiles);
        end

        function testExplicitBandwidthCall(testCase)
            files = {'ad677_ch01_input_frequency_1.5Vpp_100Hz_sweep.csv', ...
                'ad677_ch01_input_frequency_1.5Vpp_1kHz_sweep.csv', ...
                'ad677_ch01_input_frequency_1.5Vpp_30kHz_sweep.csv'};
            outputFolder = fullfile(testCase.WorkFolder, 'explicit_result');
            results = adc_bandwidth_analysis(testCase.BandwidthFolder, ...
                files, outputFolder);
            testCase.verifyEqual(results.FileFrequencyHz, [100; 1e3; 30e3]);
            testCase.verifyEqual(unique(results.CoverageStatus), "覆盖不足");
            testCase.verifyTrue(ad677WorkflowTest.hasSuccessfulRun(outputFolder));
        end

        function testRequiredFilesStayInsideLibrary(testCase)
            bandwidthEntry = fullfile(testCase.RepositoryRoot, '677_hy', ...
                'adc_bandwidth_analysis.m');
            powerEntry = fullfile(testCase.RepositoryRoot, '677_hy', ...
                'adc_power_scale_analysis.m');
            bandwidthFiles = matlab.codetools.requiredFilesAndProducts( ...
                bandwidthEntry);
            powerFiles = matlab.codetools.requiredFilesAndProducts(powerEntry);
            allFiles = string([bandwidthFiles(:); powerFiles(:)]);
            testCase.verifyTrue(all(startsWith(allFiles, ...
                string(testCase.RepositoryRoot), 'IgnoreCase', true)));
        end
    end

    methods (Static, Access=private)
        function buildBandwidthData(folder)
            frequencies = [100, 1e3, 30e3];
            for index = 1:numel(frequencies)
                name = sprintf(['ad677_ch01_input_frequency_1.5Vpp_' ...
                    '%s_sweep.csv'], ad677WorkflowTest.frequencyLabel( ...
                    frequencies(index)));
                code = ad677WorkflowTest.sineCode(4000, frequencies(index));
                ad677WorkflowTest.writeCsv(folder, name, code, 1);
            end
        end

        function buildPowerData(folder)
            vpp = [0.25, 1.5, 2.25, 2.5];
            for index = 1:numel(vpp)
                name = sprintf(['ad677_ch01_error_input_vpp_1kHz_' ...
                    '%gVpp_sweep.csv'], vpp(index));
                code = ad677WorkflowTest.sineCode(2500*vpp(index), 1e3);
                ad677WorkflowTest.writeCsv(folder, name, code, 1);
            end
        end

        function code = sineCode(amplitude, frequencyHz)
            sampleRate = 100e6;
            time = (0:131071)' / sampleRate;
            code = round(amplitude * sin(2*pi*frequencyHz*time + 0.4));
        end

        function writeCsv(folder, name, code, channel)
            fileId = fopen(fullfile(folder, name), 'w');
            cleanup = onCleanup(@() fclose(fileId));
            fprintf(fileId, ['Sample in Buffer,Sample in Window,TRIGGER,' ...
                'u_ad677_to_b9726/u_ad677_%d/adc_data[15:0],' ...
                'u_ad677_to_b9726/u_ad677_%d/adc_data_vld\n'], ...
                channel, channel);
            sample = (0:numel(code)-1)';
            trigger = zeros(size(code)); trigger(1) = 1;
            valid = ones(size(code));
            fprintf(fileId, '%d,%d,%d,%d,%d\n', ...
                [sample, sample, trigger, code, valid].');
            assert(~isempty(cleanup));
        end

        function label = frequencyLabel(frequencyHz)
            if frequencyHz >= 1e3
                label = sprintf('%gkHz', frequencyHz/1e3);
            else
                label = sprintf('%gHz', frequencyHz);
            end
        end

        function tf = hasSuccessfulRun(folder)
            tf = ~isempty(dir(fullfile(folder, 'run_*', ...
                'STATUS_SUCCESS.txt')));
        end
    end
end

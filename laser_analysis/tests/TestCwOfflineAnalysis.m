classdef TestCwOfflineAnalysis < matlab.unittest.TestCase
    %TESTCWOFFLINEANALYSIS Synthetic verification for s26-s35 core metrics.

    properties
        Root (1, 1) string
    end

    methods (TestClassSetup)
        function addCodeRoot(~)
            %ADDCODEROOT Keep package functions visible to the test runner.
            testFile = mfilename('fullpath');
            codeRoot = fileparts(fileparts(testFile));
            addpath(codeRoot);
            setup_laser_analysis();
        end
    end

    methods (TestMethodSetup)
        function createRoot(testCase)
            %CREATEROOT Create an isolated evidence directory.
            testCase.Root = string(tempname);
            mkdir(testCase.Root);
        end
    end

    methods (TestMethodTeardown)
        function removeRoot(testCase)
            %REMOVEROOT Delete only this test's temporary directory.
            if isfolder(testCase.Root)
                rmdir(testCase.Root, 's');
            end
            close all force;
        end
    end

    methods (Test)
        function requirementConflictsRemainUnresolved(testCase)
            %REQUIREMENTCONFLICTSREMAINUNRESOLVED Check source conflicts.
            requirements = laser_analysis.requirement_profile( ...
                "delay_driver", "CW");
            conflict = requirements(requirements.metric == "asd_1hz" & ...
                requirements.subsystem == "dac", :);
            testCase.verifyEqual(height(conflict), 2);
            testCase.verifyTrue(all(conflict.state == "conflict"));
            judgment = laser_analysis.evaluate_requirement( ...
                10, conflict, true);
            testCase.verifyEqual(judgment, "暂不能判定");
        end

        function knownSfdrIsRecovered(testCase)
            %KNOWNSFDRISRECOVERED Verify integrated-bin SFDR definition.
            fs = 100e3;
            time = (0:8191).' / fs;
            values = sin(2 * pi * 10e3 * time) + ...
                1e-3 * sin(2 * pi * 20e3 * time);
            metrics = laser_analysis.spectrum_metrics(values, ...
                fs, 10e3, 3);
            testCase.verifyGreaterThan(metrics.sfdr_db, 54);
            testCase.verifyLessThan(metrics.sfdr_db, 65);
        end

        function codeDensityProducesFiniteLinearity(testCase)
            %CODEDENSITYPRODUCESFINITELINEARITY Run an 8-bit sine histogram.
            phase = (0:199999).' / 997;
            code = round(127.5 + 126.5 * sin(2 * pi * phase));
            source = fullfile(testCase.Root, 'codes.csv');
            writematrix(code, source);
            manifest = table("D1", "ADC", string(source), "ila_csv", ...
                1, 8, "unipolar", "dec", ...
                'VariableNames', {'case_id', 'channel', 'source_file', ...
                'format', 'data_column', 'bits', 'coding', 'radix'});
            cfg = testCase.makeConfig("digital_lock", "code_density", ...
                manifest);
            result = s27_analyze_adc_code_density_linearity(cfg);
            testCase.verifyTrue( ...
                isfinite(result.summary.maximum_abs_dnl_lsb));
            testCase.verifyGreaterThan( ...
                result.summary.code_coverage_ratio, 0.9);
        end

        function knownIsolationIsRecovered(testCase)
            %KNOWNISOLATIONISRECOVERED Verify same-frequency tone fitting.
            fs = 100e3;
            time = (0:4095).' / fs;
            aggressorPath = fullfile(testCase.Root, 'aggressor.mat');
            victimPath = fullfile(testCase.Root, 'victim.mat');
            A = sin(2 * pi * 10e3 * time);
            Tinterval = 1 / fs;
            save(aggressorPath, 'A', 'Tinterval');
            A = 0.01 * sin(2 * pi * 10e3 * time);
            save(victimPath, 'A', 'Tinterval');
            manifest = table(["I1"; "I1"], ["A"; "B"], ...
                [string(aggressorPath); string(victimPath)], ...
                ["mat"; "mat"], 10e3 * ones(2, 1), ...
                ["A"; "A"], ["B"; "B"], ...
                repmat("ADC input", 2, 1), repmat("adc", 2, 1), ...
                'VariableNames', {'case_id', 'channel', 'source_file', ...
                'format', 'stimulus_frequency_hz', ...
                'aggressor_channel', 'victim_channel', ...
                'reference_plane', 'data_role'});
            cfg = testCase.makeConfig("digital_lock", "isolation", manifest);
            result = s28_analyze_channel_isolation(cfg);
            testCase.verifyEqual(result.details.isolation_db, 40, ...
                'AbsTol', 0.1);
        end

        function knownTemperatureSlopeIsRecovered(testCase)
            %KNOWNTEMPERATURESLOPEISRECOVERED Verify uV/degC regression.
            temperature = [-10; 0; 20; 45];
            files = strings(size(temperature));
            Tinterval = 1e-3;
            for k = 1:numel(temperature)
                A = repmat(20e-6 * temperature(k), 100, 1);
                files(k) = fullfile(testCase.Root, "temp" + k + ".mat");
                save(files(k), 'A', 'Tinterval');
            end
            manifest = table("T" + (1:4).', repmat("ADC", 4, 1), ...
                files, repmat("mat", 4, 1), temperature, ones(4, 1), ...
                repmat("ADC input", 4, 1), ...
                'VariableNames', {'case_id', 'channel', 'source_file', ...
                'format', 'temperature_c', 'cycle', 'reference_plane'});
            cfg = testCase.makeConfig("digital_lock", "temperature", manifest);
            result = s29_analyze_temperature_drift(cfg);
            testCase.verifyEqual( ...
                result.summary.worst_slope_uv_per_degc, 20, ...
                'AbsTol', 1e-9);
        end

        function dcTransferReportsKnownResidual(testCase)
            %DCTRANSFERREPORTSKNOWNRESIDUAL Verify static DC code fitting.
            code = (0:4).';
            voltage = 0.1 * code;
            voltage(3) = voltage(3) + 1e-3;
            manifest = table("V" + (1:5).', repmat("DAC", 5, 1), ...
                code, voltage, 50 * ones(5, 1), ...
                repmat("DAC connector", 5, 1), ...
                'VariableNames', {'case_id', 'channel', 'code_value', ...
                'measured_value', 'load_ohm', 'reference_plane'});
            cfg = testCase.makeConfig("digital_lock", "dac_dc", manifest);
            result = s30_analyze_dac_dc_transfer(cfg);
            testCase.verifyEqual( ...
                result.summary.maximum_abs_inl_endpoint_mv, 1, ...
                'AbsTol', 1e-9);
        end

        function phaseNoiseDirectCurvePasses(testCase)
            %PHASENOISEDIRECTCURVEPASSES Verify target-offset interpolation.
            source = fullfile(testCase.Root, 'phase_noise_curve.csv');
            writematrix([0.5, -45; 1, -60; 10, -90; ...
                1e5, -130; 2e5, -140], source);
            manifest = table("P1", "DAC", string(source), "csv", ...
                1, 2, 1e6, "DAC output", ...
                'VariableNames', {'case_id', 'channel', 'source_file', ...
                'format', 'frequency_column', 'phase_noise_column', ...
                'carrier_frequency_hz', 'reference_plane'});
            cfg = testCase.makeConfig("digital_lock", "phase_noise", manifest);
            result = s31_analyze_phase_noise_compliance(cfg);
            testCase.verifyEqual(result.summary.status, "满足");
        end

        function delayCrossingsRecoverKnownDelay(testCase)
            %DELAYCROSSINGSRECOVERKNOWNDELAY Verify edge interpolation.
            fs = 100e6;
            time = (0:4095).' / fs;
            C2_data = square(2 * pi * 1e6 * time);
            delaySamples = 10;
            A = [zeros(delaySamples, 1); C2_data(1:end - delaySamples)];
            Tinterval = 1 / fs;
            source = fullfile(testCase.Root, 'delay.mat');
            save(source, 'A', 'C2_data', 'Tinterval');
            manifest = table("L1", "FAST", string(source), "mat", ...
                "loop_fast", "ADC input to DAC output", ...
                "DL-CW-DELAY-FAST", 0, ...
                'VariableNames', {'case_id', 'channel', 'source_file', ...
                'format', 'data_role', 'reference_plane', ...
                'requirement_id', 'cable_skew_s'});
            cfg = testCase.makeConfig("digital_lock", "delay", manifest);
            result = s33_analyze_loop_delay(cfg);
            testCase.verifyEqual(result.summary.median_delay_s, 100e-9, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(result.summary.status, "满足");
        end

        function missingTauCannotPassRfStability(testCase)
            %MISSINGTAUCANNOTPASSRFSTABILITY Verify metadata guard.
            source = fullfile(testCase.Root, 'frequency.csv');
            writematrix(100e6 + randn(100, 1), source);
            manifest = table("R1", "RF1", "frequency_log", ...
                string(source), 1, 100e6, "RF output", ...
                "DL-CW-RF100-ADEV-1S", ...
                'VariableNames', {'case_id', 'channel', 'data_role', ...
                'source_file', 'data_column', 'center_frequency_hz', ...
                'reference_plane', 'requirement_id'});
            cfg = testCase.makeConfig("digital_lock", "rf", manifest);
            result = s32_analyze_rf_reference_compliance(cfg);
            testCase.verifyTrue(all(result.details.status == "暂不能判定"));
        end
    end

    methods (Access = private)
        function cfg = makeConfig(testCase, board, testId, manifest)
            %MAKECONFIG Write a manifest and return an isolated config.
            manifestPath = fullfile(testCase.Root, testId + ".csv");
            writetable(manifest, manifestPath);
            cfg = laser_analysis.make_test_config(board, "CW", testId);
            cfg.manifestFile = manifestPath;
            cfg.outputDir = fullfile(testCase.Root, "output_" + testId);
            cfg.timestampedOutput = false;
            cfg.showFigures = false;
        end
    end
end

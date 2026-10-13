classdef configProfilesWorkflowTest < matlab.unittest.TestCase
    properties
        WorkFolder
        Root
    end
    methods (TestMethodSetup)
        function prepare(testCase)
            testCase.Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.WorkFolder = fixture.Folder;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'_shared')));
        end
    end
    methods (Test)
        function commonIsolationGainPreservesRatio(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'9726_hy')));
            Tinterval = 1/20000;
            t = (0:4095)'*Tinterval;
            A = sin(2*pi*1000*t);
            save(fullfile(testCase.WorkFolder,'drive.mat'),'A','Tinterval');
            A = 0.01*sin(2*pi*1000*t+0.2);
            save(fullfile(testCase.WorkFolder,'victim.mat'),'A','Tinterval');
            pair = struct('driven_file','drive.mat','victim_file','victim.mat', ...
                'driven_variable','A','victim_variable','A','frequency_hz',1000, ...
                'driven_label','JG18','victim_label','JG20','reference_plane','synthetic common plane');
            direct = dac_isolation_analysis(testCase.WorkFolder,pair, ...
                fullfile(testCase.WorkFolder,'direct'),struct('hardwareGain',1));
            amplified = dac_isolation_analysis(testCase.WorkFolder,pair, ...
                fullfile(testCase.WorkFolder,'amplified'),struct('hardwareGain',100));
            testCase.verifyEqual(direct.summary.isolation_db,40,AbsTol=1e-9);
            testCase.verifyEqual(amplified.summary.isolation_db,direct.summary.isolation_db,AbsTol=1e-9);
            testCase.verifyEqual(amplified.summary.driven_vpp_v*100,direct.summary.driven_vpp_v,AbsTol=1e-10);
            testCase.verifyEqual(amplified.summary.victim_vpp_v*100,direct.summary.victim_vpp_v,AbsTol=1e-10);
        end
        function dcProfilePreservesDefaultsAndFit(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'9726_hy')));
            codes = [-32768 -24577 -16385 -8193 0 8191 16383 24575 32767];
            A = repelem(codes(:)*1e-4,1000);
            Tinterval = 1/2000;
            save(fullfile(testCase.WorkFolder,'JG18_DC.mat'),'A','Tinterval');
            result = dac_output_voltage_analysis(testCase.WorkFolder,{'JG18_DC.mat'}, ...
                fullfile(testCase.WorkFolder,'output'),struct('channelLabels',{{'JG18'}}));
            recorded = load(fullfile(result.outputFolder,'run_config.mat'));
            testCase.verifyEqual(recorded.options.edgeThreshold,0.25);
            testCase.verifyEqual(recorded.options.smoothingWindowSamples,201);
            testCase.verifyEqual(result.channelResults.slopeVPerCode,1e-4,AbsTol=1e-12);
            testCase.verifyEqual(result.channelResults.vppV,6.5535,AbsTol=1e-10);
        end
        function dcProfileRejectsUnknownOption(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'9726_hy')));
            testCase.verifyError(@()dac_output_voltage_analysis([],[],[], ...
                struct('edgeThresold',0.25)),'converter:runtime:UnknownConfigField');
        end
        function hexProfileKeepsDefaults(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'766_hy')));
            files = configProfilesWorkflowTest.makeHexInputs(testCase.WorkFolder,1525);
            result = dac_scale_hex_analysis(testCase.WorkFolder,files,fullfile(testCase.WorkFolder,'output'));
            testCase.verifyEqual(result.summary.slope_v_per_code_vpp,1e-4,AbsTol=1e-10);
            saved = load(fullfile(result.outputFolder,'evidence','run_config.mat'));
            testCase.verifyEqual(saved.config.toneFrequencyHz,1525);
            testCase.verifyEqual(saved.config.hardwareGain,1);
            testCase.verifyEqual(saved.config.maximumCodeVpp,65536);
            testCase.verifyEqual(saved.config.analysisId,'scale');
        end
        function hexProfileAcceptsNumericFourthArgument(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.Root,'766_hy')));
            files = configProfilesWorkflowTest.makeHexInputs(testCase.WorkFolder,1600);
            result = dac_scale_hex_analysis(testCase.WorkFolder,files,fullfile(testCase.WorkFolder,'output'),1600);
            testCase.verifyEqual(result.summary.slope_v_per_code_vpp,1e-4,AbsTol=1e-10);
            saved = load(fullfile(result.outputFolder,'evidence','run_config.mat'));
            testCase.verifyEqual(saved.config.toneFrequencyHz,1600);
        end
    end
    methods (Static, Access=private)
        function files = makeHexInputs(folder,frequency)
            tokens = {'1000','2000','4000'};
            files = cell(1,3);
            Tinterval = 1/250000;
            t = (0:4095)'*Tinterval;
            for k=1:3
                A = hex2dec(tokens{k})*1e-4*sin(2*pi*frequency*t+0.3);
                files{k} = ['X7_CODE' tokens{k} '.mat'];
                save(fullfile(folder,files{k}),'A','Tinterval');
            end
        end
    end
end

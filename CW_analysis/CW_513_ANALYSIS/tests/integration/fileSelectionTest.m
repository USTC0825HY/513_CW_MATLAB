classdef fileSelectionTest < matlab.unittest.TestCase
    %FILESELECTIONTEST Public entry selection, cancellation and output contracts.
    properties
        Root
        Work
        Raw
    end
    properties (TestParameter)
        entry = struct( ...
            'device_2208_hy_adc_sfdr_analysis', struct('folder','2208_hy','name','adc_sfdr_analysis'), ...
            'device_2208_hy_adc_bandwidth_analysis', struct('folder','2208_hy','name','adc_bandwidth_analysis'), ...
            'device_2208_hy_adc_power_scale_analysis', struct('folder','2208_hy','name','adc_power_scale_analysis'), ...
            'device_2208_hy_adc_isolation_analysis', struct('folder','2208_hy','name','adc_isolation_analysis'), ...
            'device_2208_hy_adc_inl_dnl_analysis', struct('folder','2208_hy','name','adc_inl_dnl_analysis'), ...
            'device_2208_hy_adc_ila_noise_analysis', struct('folder','2208_hy','name','adc_ila_noise_analysis'), ...
            'device_2208_hy_adc_pico_noise_1hz_analysis', struct('folder','2208_hy','name','adc_pico_noise_1hz_analysis'), ...
            'device_9245_hy_adc_sfdr_analysis', struct('folder','9245_hy','name','adc_sfdr_analysis'), ...
            'device_9245_hy_adc_bandwidth_analysis', struct('folder','9245_hy','name','adc_bandwidth_analysis'), ...
            'device_9245_hy_adc_power_scale_analysis', struct('folder','9245_hy','name','adc_power_scale_analysis'), ...
            'device_9245_hy_adc_isolation_analysis', struct('folder','9245_hy','name','adc_isolation_analysis'), ...
            'device_9245_hy_adc_inl_dnl_analysis', struct('folder','9245_hy','name','adc_inl_dnl_analysis'), ...
            'device_9245_hy_adc_input_noise_analysis', struct('folder','9245_hy','name','adc_input_noise_analysis'), ...
            'device_9726_hy_dac_scale_analysis', struct('folder','9726_hy','name','dac_scale_analysis'), ...
            'device_9726_hy_dac_noise_analysis', struct('folder','9726_hy','name','dac_noise_analysis'), ...
            'device_9726_hy_dac_isolation_analysis', struct('folder','9726_hy','name','dac_isolation_analysis'), ...
            'device_766_hy_dac_scale_analysis', struct('folder','766_hy','name','dac_scale_analysis'), ...
            'device_766_hy_dac_scale_hex_analysis', struct('folder','766_hy','name','dac_scale_hex_analysis'), ...
            'device_766_hy_dac_noise_analysis', struct('folder','766_hy','name','dac_noise_analysis'), ...
            'device_766_hy_dac_isolation_analysis', struct('folder','766_hy','name','dac_isolation_analysis'), ...
            'device_677_hy_adc_bandwidth_analysis', struct('folder','677_hy','name','adc_bandwidth_analysis'), ...
            'device_677_hy_adc_power_scale_analysis', struct('folder','677_hy','name','adc_power_scale_analysis'))
        dacFolder = {'9726_hy','766_hy'}
    end
    methods (TestMethodSetup)
        function prepare(t)
            t.Root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            base = getenv('CW513_SELECTION_WORK');
            if isempty(base), base = tempdir; end
            t.Work = tempname(base);
            t.Raw = fullfile(t.Work, 'raw');
            mkdir(t.Raw);
            previousPath = path; previousFolder = pwd;
            t.addTeardown(@() path(previousPath));
            t.addTeardown(@() cd(previousFolder));
            t.addTeardown(@() setappdata(0,'cw513TestDialogs',struct('queue',{{}},'calls',0)));
            existing = strsplit(path,pathsep);
            isDevice = ~cellfun('isempty',regexp(existing, ...
                '[/\\](2208_hy|9245_hy|677_hy|9726_hy|766_hy)$','once'));
            path(strjoin(existing(~isDevice),pathsep));
            addpath(fullfile(t.Root,'tests','integration'));
            cd(t.Work);
            addpath(fullfile(t.Root,'_shared'));
            addpath(fullfile(t.Root,'tests','fixtures','file_selection_ui'));
            t.dialogs({});
            fileSelectionTest.createData(t.Raw);
        end
    end
    methods (Test)
        function zeroArgumentsCancelWithoutOutputs(t, entry)
            t.target(entry.folder, entry.name);
            t.dialogs({{0,t.Raw}});
            result = feval(entry.name);
            t.verifyTrue(isempty(result) || (isstruct(result) && isempty(fieldnames(result))));
            t.verifyEmpty(dir(fullfile(t.Work,'**','run_*')));
            t.verifyEqual(t.calls(),1);
        end
        function explicitMissingInputNeverOpensDialog(t, entry)
            t.target(entry.folder, entry.name);
            [call, id] = t.missingCall(entry);
            t.verifyError(call,id);
            t.verifyEqual(t.calls(),0);
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function csvInteractiveSubsetEqualsExplicit(t)
            t.target('9245_hy','adc_sfdr_analysis');
            t.dialogs({{'X3G_1MHz.csv',t.Raw}});
            interactive = adc_sfdr_analysis(t.Raw,[],fullfile(t.Work,'chosen'));
            t.dialogs({});
            explicit = adc_sfdr_analysis(t.Raw,{'X3G_1MHz.csv'},fullfile(t.Work,'explicit'));
            t.verifyEqual(height(interactive),1);
            t.verifyEqual(interactive{:,2:end},explicit{:,2:end},'AbsTol',1e-10);
            t.verifyEqual(t.calls(),0);
            t.verifyEqual(string(interactive.FileName),"X3G_1MHz.csv");
        end
        function matSubsetDefaultOutputAndUniqueRuns(t,dacFolder)
            t.target(dacFolder,'dac_scale_analysis');
            t.dialogs({{{'code_1000.mat','code_2000.mat'},t.Raw}});
            selected = dac_scale_analysis(t.Raw);
            t.dialogs({});
            explicit = dac_scale_analysis(t.Raw,{'code_1000.mat','code_2000.mat'});
            t.verifyEqual(height(selected.measurements),2);
            t.verifyEqual(selected.measurements.output_vpp_v,explicit.measurements.output_vpp_v,'AbsTol',1e-12);
            t.verifyNotEqual(selected.outputFolder,explicit.outputFolder);
            t.verifyEqual(fileparts(selected.outputFolder),fullfile(t.Work,'results'));
            t.verifyEqual(t.calls(),0);
            manifest = readtable(fullfile(explicit.outputFolder,'run_manifest.csv'));
            t.verifyEqual(height(manifest),2);
            t.verifyTrue(all(isfile(string(manifest.FileName))));
        end
        function configFileListDoesNotOpenDialog(t,dacFolder)
            t.target(dacFolder,'dac_noise_analysis');
            cfg = struct('dataFolder',t.Raw,'inputFiles',{{'noise.mat'}}, ...
                'outputFolder',fullfile(t.Work,'configured'),'dataVariables',{{'A'}});
            result = dac_noise_analysis([],[],[],cfg);
            t.verifyEqual(height(result.summary),1);
            t.verifyEqual(t.calls(),0);
        end
        function noiseMissingVariableFails(t,dacFolder)
            t.target(dacFolder,'dac_noise_analysis');
            t.verifyError(@() dac_noise_analysis(t.Raw,{'noise.mat'}, ...
                fullfile(t.Work,'out'),struct('dataVariables',{{'Z'}})), ...
                'converter:io:VariableMissing');
            t.verifyEqual(t.calls(),0);
        end
        function isolationNeedsReferenceCondition(t,dacFolder)
            t.target(dacFolder,'dac_isolation_analysis');
            pair = fileSelectionTest.pair(t.Raw);
            pair = rmfield(pair,'reference_plane');
            t.verifyError(@() dac_isolation_analysis(t.Raw,pair,fullfile(t.Work,'out')), ...
                'converter:dac:ReferenceRequired');
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
            t.verifyEqual(t.calls(),0);
        end
        function isolationSecondFileCancelHasNoOutput(t,dacFolder)
            t.target(dacFolder,'dac_isolation_analysis');
            t.dialogs({{'code_1000.mat',t.Raw},{0,t.Raw}});
            result = dac_isolation_analysis(t.Raw,[],fullfile(t.Work,'out'));
            t.verifyEmpty(result);
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function isolationConditionsCancelHasNoOutput(t,dacFolder)
            t.target(dacFolder,'dac_isolation_analysis');
            t.dialogs({{'code_1000.mat',t.Raw},{'code_2000.mat',t.Raw},{{}}});
            result = dac_isolation_analysis(t.Raw,[],fullfile(t.Work,'out'));
            t.verifyEmpty(result);
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function isolationSelectedPairEqualsExplicit(t,dacFolder)
            t.target(dacFolder,'dac_isolation_analysis');
            t.dialogs({{'code_1000.mat',t.Raw},{'code_2000.mat',t.Raw}, ...
                {{'drive','victim','A','A','1000','synthetic common voltage reference','1'}}});
            selected = dac_isolation_analysis(t.Raw,[],fullfile(t.Work,'chosen'));
            t.dialogs({});
            explicit = dac_isolation_analysis(t.Raw,fileSelectionTest.pair(t.Raw),fullfile(t.Work,'explicit'));
            t.verifyEqual(height(selected.summary),1);
            t.verifyEqual(selected.summary.isolation_db,explicit.summary.isolation_db,'AbsTol',1e-12);
            t.verifyEqual(t.calls(),0);
        end
        function pico9245InterfaceCancelHasNoOutput(t)
            t.target('9245_hy','adc_input_noise_analysis');
            t.dialogs({{'noise.mat',t.Raw},{[],0}});
            result = adc_input_noise_analysis(t.Raw,fullfile(t.Work,'out'));
            t.verifyEmpty(result);
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function pico9245RequiresExplicitInterface(t)
            t.target('9245_hy','adc_input_noise_analysis');
            t.verifyError(@() adc_input_noise_analysis(t.Raw,fullfile(t.Work,'out'), ...
                struct('selectedFiles',{{'noise.mat'}})), 'ad9245:NoiseInterfaceRequired');
            t.verifyEqual(t.calls(),0);
        end
        function pico2208InterfaceCancelHasNoOutput(t)
            t.target('2208_hy','adc_pico_noise_1hz_analysis');
            t.dialogs({{'noise.mat',t.Raw},{[],0}});
            result = adc_pico_noise_1hz_analysis(t.Raw,[],fullfile(t.Work,'out'));
            t.verifyTrue(isempty(fieldnames(result)));
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function pico2208RequiresExplicitInterface(t)
            t.target('2208_hy','adc_pico_noise_1hz_analysis');
            t.verifyError(@() adc_pico_noise_1hz_analysis(t.Raw,'noise.mat',fullfile(t.Work,'out')), ...
                'ad2208:PicoInterfaceRequired');
            t.verifyEqual(t.calls(),0);
        end
        function isolation2208MissingDrivenFileFailsBeforeOutput(t)
            t.target('2208_hy','adc_isolation_analysis');
            t.verifyError(@() adc_isolation_analysis(t.Raw,{'JG15.csv'},fullfile(t.Work,'out'), ...
                struct('drivenChannel','ADC2_JG17')), 'converter:adc:DrivenChannelMissing');
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
            t.verifyEqual(t.calls(),0);
        end
        function ilaRejectsUncalibratedHeaderWithoutGuessingName(t)
            t.target('2208_hy','adc_ila_noise_analysis');
            t.verifyError(@() adc_ila_noise_analysis(t.Raw,{'misleading_JG15.csv'}, ...
                fullfile(t.Work,'out')), 'converter:adc:MissingCalibration');
            t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
        function ilaFixedRecordLengthRejectsShortCapture(t)
            t.target('2208_hy','adc_ila_noise_analysis');
            t.verifyError(@() adc_ila_noise_analysis(t.Raw,{'JG15.csv'}, ...
                fullfile(t.Work,'out')), 'converter:adc:FixedNoiseRecordLength');
            t.verifyEqual(t.calls(),0);
        end
        function duplicateAndMissingCsvRejectedBeforeOutput(t)
            t.verifyError(@() converter.io.selectCsvFiles(t.Raw, ...
                {'JG15.csv','JG15.csv'}), 'converter:io:DuplicateInput');
            t.verifyError(@() converter.io.selectCsvFiles(t.Raw, ...
                {'absent.csv'}), 'converter:io:InputFileNotFound');
            t.verifyEqual(t.calls(),0);
        end
        function absoluteCsvResolvesOutsideCurrentFolder(t)
            [files, folder] = converter.io.selectCsvFiles(t.Raw,{fullfile(t.Raw,'JG15.csv')});
            t.verifyEqual(converter.io.resolveInputPath(folder,files{1}), ...
                char(java.io.File(fullfile(t.Raw,'JG15.csv')).getCanonicalPath()));
            t.verifyEqual(t.calls(),0);
        end
    end
    methods
        function target(t,folder,name)
            addpath(fullfile(t.Root,folder),'-begin');
            actual = which(name);
            t.assertEqual(strrep(actual,'\','/'),strrep(fullfile(t.Root,folder,[name '.m']),'\','/'));
        end
        function dialogs(~,queue)
            setappdata(0,'cw513TestDialogs',struct('queue',{queue},'calls',0));
        end
        function count = calls(~)
            state = getappdata(0,'cw513TestDialogs'); count = state.calls;
        end
        function [call,id] = missingCall(t,entry)
            out = fullfile(t.Work,'out');
            id = 'converter:io:InputFileNotFound';
            switch entry.name
                case 'adc_input_noise_analysis'
                    call = @() adc_input_noise_analysis(t.Raw,out, ...
                        struct('selectedFiles',{{'absent.mat'}},'interfaces',{{'X1G'}}));
                case 'adc_pico_noise_1hz_analysis'
                    call = @() adc_pico_noise_1hz_analysis(t.Raw,'absent.mat',out,struct('interface','ADC6_JG24'));
                    id = 'ad2208:PicoCaptureMissing';
                case 'dac_isolation_analysis'
                    pair = fileSelectionTest.pair(t.Raw); pair.driven_file = 'absent.mat';
                    call = @() dac_isolation_analysis(t.Raw,pair,out);
                case 'dac_scale_hex_analysis'
                    call = @() dac_scale_hex_analysis(t.Raw,{'absent.mat'},out);
                    id = 'cw513:ScaleFileMissing';
                otherwise
                    ext = '.csv'; if startsWith(entry.name,'dac'), ext = '.mat'; end
                    call = @() feval(entry.name,t.Raw,{['absent' ext]},out);
            end
        end
    end
    methods (Static)
        function createData(folder)
            Tinterval = 1e-4;
            time = (0:4095)'*Tinterval;
            A = 0.1*sin(2*pi*1000*time);
            save(fullfile(folder,'code_1000.mat'),'A','Tinterval');
            A = 0.2*sin(2*pi*1000*time);
            save(fullfile(folder,'code_2000.mat'),'A','Tinterval');
            Tinterval = 0.001; time = (0:29999)'*Tinterval;
            A = 1e-5*sin(2*pi*time)+1e-6*cos(2*pi*41*time);
            save(fullfile(folder,'noise.mat'),'A','Tinterval');
            time = (0:8191)'/25e6; code = round(3500*sin(2*pi*1e6*time));
            fileSelectionTest.csv(fullfile(folder,'X3G_1MHz.csv'),'sample,ad9245_test_module[2]',[(0:8191)' code]);
            time = (0:8191)'/100e6; code = round(2000*sin(2*pi*1e6*time));
            fileSelectionTest.csv(fullfile(folder,'JG15.csv'),'s,w,t,yb2208_test_module[0]',[(0:8191)' zeros(8192,2) code]);
            fileSelectionTest.csv(fullfile(folder,'misleading_JG15.csv'),'s,w,t,yb2208_test_module[3]',[(0:8191)' zeros(8192,2) code]);
        end
        function csv(file,header,data)
            f = fopen(file,'w'); cleanup = onCleanup(@() fclose(f));
            fprintf(f,'%s\n',header);
            format = [repmat('%d,',1,size(data,2)-1) '%d\n'];
            fprintf(f,format,data.');
        end
        function pair = pair(folder)
            pair = struct('driven_file',fullfile(folder,'code_1000.mat'), ...
                'victim_file',fullfile(folder,'code_2000.mat'), ...
                'driven_label','drive','victim_label','victim', ...
                'driven_variable','A','victim_variable','A','frequency_hz',1000, ...
                'reference_plane','synthetic common voltage reference');
        end
    end
end

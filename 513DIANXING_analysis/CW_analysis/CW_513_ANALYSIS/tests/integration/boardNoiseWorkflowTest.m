classdef boardNoiseWorkflowTest < matlab.unittest.TestCase
    % Synthetic file-to-bundle tests of calibration selection and scaling.
    properties
        Root
        Work
    end
    methods(TestMethodSetup)
        function prepare(t)
            t.Root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            base=getenv('CW513_SELECTION_WORK');if isempty(base),base=tempdir;end
            t.Work=tempname(base);mkdir(t.Work);
            oldPath=path;oldFolder=pwd;
            t.addTeardown(@()path(oldPath));t.addTeardown(@()cd(oldFolder));
            restoredefaultpath;addpath(fullfile(t.Root,'_shared'));
            addpath(fullfile(t.Root,'tests','integration'));cd(t.Work);
            time=(0:1999)'/100; A=0.002*sin(2*pi*time)+0.0002*cos(2*pi*3*time);Tinterval=0.01;
            save(fullfile(t.Work,'capture.mat'),'A','Tinterval');
        end
    end
    methods(Test)
        function pico2208BothBoardsAndHistorical(t)
            addpath(fullfile(t.Root,'2208_hy'));
            jd=adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,'jd'),struct('interface','ADC6_JG24','boardType','jianding'));
            jq=adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,'jq'),struct('interface','ADC6_JG24','boardType','jiaqiang'));
            before=adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,'before'), ...
                struct('interface','ADC6_JG24','boardType','jiaqiang','calibrationState','before'));
            t.verifyPicoRatio(jd,jq,(3.802132e-5/1.022947e-4)/(3.788345e-5/1.014514e-4));
            t.verifyPicoRatio(jq,before,1.932029e-5/3.802132e-5);
            t.verifyEqual(jd.summary.fpga_gain,128);
        end
        function pico9245AllInterfaces(t)
            addpath(fullfile(t.Root,'9245_hy'));
            files=cell(1,4);
            for k=1:4
                files{k}=sprintf('capture%d.mat',k);copyfile(fullfile(t.Work,'capture.mat'),fullfile(t.Work,files{k}));
            end
            opts=struct('selectedFiles',{files},'interfaces',{{'X1G','X2G','X3G','X4G'}},'boardType','jianding');
            jd=adc_input_noise_analysis(t.Work,fullfile(t.Work,'jd'),opts);
            opts.boardType='jiaqiang';jq=adc_input_noise_analysis(t.Work,fullfile(t.Work,'jq'),opts);
            ratio=([1.335434;1.343550;1.342798;1.341605]/1.022947)./([1.341131;1.328759;1.343665;1.339039]/1.014514);
            t.verifyPicoRatio(jd,jq,ratio);
        end
        function pico677BothChannels(t)
            addpath(fullfile(t.Root,'677_hy'));
            for k=1:2
                opts=struct('interface',sprintf('677_%d',k),'boardType','jianding');
                jd=adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,['jd' num2str(k)]),opts);
                opts.boardType='jiaqiang';jq=adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,['jq' num2str(k)]),opts);
                kJD=[1.536050e-4 1.695154e-4];kJQ=[0.000153251 0.000170337];
                t.verifyPicoRatio(jd,jq,(kJQ(k)/1.022947e-4)/(kJD(k)/1.014514e-4));
            end
        end
        function ila2208And677PsdAsdRmsScaling(t)
            n=131072;sample=(0:n-1)';code=mod(sample*37,41)-20;
            for d={'2208','677'}
                device=d{1};addpath(fullfile(t.Root,[device '_hy']));clear adc_ila_noise_analysis;
                if strcmp(device,'2208'),channel='ADC1_JG15';module='yb2208_test_module[0]/adc_data';ks=[2.347136e-5 2.368166e-5];
                else,channel='677_1';module='u_ad677_1/adc_data';ks=[1.536050e-4 .000153251];end
                file=fullfile(t.Work,[device '.csv']);fid=fopen(file,'w');
                fprintf(fid,'Sample,Window,Trigger,%s[15:0],valid\n',module);
                fprintf(fid,'%d,%d,%d,%d,%d\n',[sample sample zeros(n,1) code ones(n,1)]');fclose(fid);
                opts=struct('boardType','jianding','inputRadix','decimal','inputChannels',{{channel}});
                jd=adc_ila_noise_analysis(t.Work,{file},fullfile(t.Work,[device 'jd']),opts);
                opts.boardType='jiaqiang';jq=adc_ila_noise_analysis(t.Work,{file},fullfile(t.Work,[device 'jq']),opts);
                a=load(fullfile(jd.runFolder,'evidence',['AD' device '_input_noise_result.mat']));
                b=load(fullfile(jq.runFolder,'evidence',['AD' device '_input_noise_result.mat']));
                sa=a.channelResults{1}.spectrum;sb=b.channelResults{1}.spectrum;ratio=ks(2)/ks(1);
                % Bound FFT roundoff relative to the spectrum peak; near-zero
                % cancellation bins do not have a meaningful relative error.
                t.verifyLessThan(max(abs(sb.PsdV2PerHz-sa.PsdV2PerHz*ratio^2)),max(sb.PsdV2PerHz)*1e-12);
                t.verifyLessThan(max(abs(sb.AsdNvPerSqrtHz-sa.AsdNvPerSqrtHz*ratio)),max(sb.AsdNvPerSqrtHz)*1e-12);
                t.verifyEqual(sqrt(trapz(sb.FrequencyHz,sb.PsdV2PerHz))/sqrt(trapz(sa.FrequencyHz,sa.PsdV2PerHz)),ratio,'RelTol',1e-12);
                t.verifyEqual(a.config.calibrationSelection.adc.slopeVPerCode,ks(1));
                rmpath(fullfile(t.Root,[device '_hy']));
            end
        end
        function boardCancelAndMissingBoardDoNotCreateOutput(t)
            addpath(fullfile(t.Root,'2208_hy'));
            t.verifyError(@()adc_pico_noise_1hz_analysis(t.Work,'capture.mat',fullfile(t.Work,'out'), ...
                struct('interface','ADC6_JG24')),'converter:calibration:BoardRequired');
            addpath(fullfile(t.Root,'tests/fixtures/file_selection_ui'));
            t.addTeardown(@()rmappdata(0,'cw513TestDialogs'));
            setappdata(0,'cw513TestDialogs',struct('queue',{{{'capture.mat',t.Work},{[],0}}},'calls',0));
            r=adc_pico_noise_1hz_analysis(t.Work,[],fullfile(t.Work,'out'),struct('interface','ADC6_JG24'));
            t.verifyEmpty(fieldnames(r));t.verifyFalse(isfolder(fullfile(t.Work,'out')));
        end
    end
    methods(Access=private)
        function verifyPicoRatio(t,a,b,ratio)
            t.verifyTrue(all(isfinite(a.summary.input_asd_at_check_n_v_per_sqrt_hz)));
            t.verifyEqual(b.summary.input_asd_at_check_n_v_per_sqrt_hz./a.summary.input_asd_at_check_n_v_per_sqrt_hz,ratio,'RelTol',1e-12);
            t.verifyTrue(isfile(fullfile(b.runFolder,'结果汇总.xlsx')));
            t.verifyTrue(isfile(fullfile(b.runFolder,'evidence','selected_adc_calibration.csv')));
            saved=load(fullfile(b.runFolder,'evidence','result.mat'));
            t.verifyEqual(saved.result.config.calibrationSelection,b.config.calibrationSelection);
            sheets=sheetnames(fullfile(b.runFolder,'结果汇总.xlsx'));
            cells=readcell(fullfile(b.runFolder,'结果汇总.xlsx'),'Sheet',sheets(1));
            t.verifyTrue(contains(string(cells{2,1}),string(b.config.boardType)));
        end
    end
end

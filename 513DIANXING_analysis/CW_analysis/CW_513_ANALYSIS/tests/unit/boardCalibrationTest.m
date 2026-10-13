classdef boardCalibrationTest < matlab.unittest.TestCase
    % Report transcription and source-selection contract, not hardware validation.
    properties
        Root
    end
    methods(TestMethodSetup)
        function setup(t)
            t.Root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(t.Root,'_shared')));
        end
    end
    methods(Test)
        function catalogHasAllRecordsAndTraceableSources(t)
            c=converter.calibration.calibrationCatalog();
            t.verifyEqual(numel(c),55);
            keys=strcat(string({c.boardType}),"/",string({c.device}),"/",string({c.channel}),"/",string({c.calibrationState}));
            t.verifyEqual(numel(unique(keys)),55);
            t.verifyTrue(all([c.slopeVPerCode]>0));
            t.verifyTrue(all(isnan([c.fitR2])));
            t.verifyTrue(all(strlength(string({c.sourceDocumentSha256}))==64));
            t.verifyTrue(all(strcmp({c.unit},'V/code')));
            t.verifyEqual(sum(strcmp({c.boardType},'jianding')),27);
            t.verifyEqual(sum(strcmp({c.boardType},'jiaqiang')),28);
        end
        function jg24AndDacAfterBefore(t)
            a=converter.calibration.reportCalibration('AD2208','jiaqiang','current',{'ADC6_JG24'});
            b=converter.calibration.reportCalibration('AD2208','jiaqiang','before',{'ADC6_JG24'});
            j=converter.calibration.reportCalibration('AD2208','jianding','current',{'ADC6_JG24'});
            t.verifyEqual([a.slopeVPerCode b.slopeVPerCode j.slopeVPerCode], ...
                [3.802132e-5 1.932029e-5 3.788345e-5]);
            t.verifyEqual(a.calibrationState,'after');
            t.verifyEqual(j.calibrationState,'unspecified');
            for board={'jianding','jiaqiang'}
                after=converter.calibration.reportCalibration('DA766',board{1},'current',{'X11-5','X11-6','X11-7'});
                before=converter.calibration.reportCalibration('DA766',board{1},'before',{'X11-5','X11-6','X11-7'});
                t.verifyTrue(all(strcmp({after.calibrationState},'after')));
                t.verifyTrue(all([before.slopeVPerCode]>[after.slopeVPerCode]));
            end
        end
        function uniqueKeepsStateAndExactRequestFails(t)
            c=converter.calibration.reportCalibration('AD2208','jiaqiang','current',{'ADC1_JG15'});
            t.verifyEqual(c.calibrationState,'before');
            t.verifyError(@() converter.calibration.reportCalibration('AD2208','jiaqiang','after',{'ADC1_JG15'}), ...
                'converter:calibration:StateUnavailable');
        end
        function missingBoardAndConflictingSources(t)
            t.verifyError(@() converter.calibration.resolveNoiseCalibration(struct(),'AD2208',{'ADC1_JG15'},false,false), ...
                'converter:calibration:BoardRequired');
            cfg=struct('adcCalibrationRows',struct('slope',1),'calibrationWorkbook','any.xlsx');
            t.verifyError(@() converter.calibration.resolveNoiseCalibration(cfg,'AD2208',{'ADC1_JG15'},false,true), ...
                'converter:calibration:ConflictingSources');
            cfg=struct('boardType','jianding','kDacVPerCodePp',1e-4);
            t.verifyError(@() converter.calibration.resolveNoiseCalibration(cfg,'AD2208',{'ADC1_JG15'},false,true), ...
                'converter:calibration:ConflictingSources');
        end
        function cancellationAndIndependentChoice(t)
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(t.Root,'tests','fixtures','file_selection_ui')));
            t.addTeardown(@() rmappdata(0,'cw513TestDialogs'));
            setappdata(0,'cw513TestDialogs',struct('queue',{{{[],0},{1,1},{2,1}}},'calls',0));
            [~,r,cancel]=converter.calibration.resolveNoiseCalibration(struct(),'AD677',{'677_1'},true,false);
            t.verifyTrue(cancel);t.verifyEmpty(r);
            [a,~]=converter.calibration.resolveNoiseCalibration(struct(),'AD677',{'677_1'},true,false);
            [b,~]=converter.calibration.resolveNoiseCalibration(struct(),'AD677',{'677_1'},true,false);
            t.verifyEqual(a.boardType,'jianding');t.verifyEqual(b.boardType,'jiaqiang');
            state=getappdata(0,'cw513TestDialogs');t.verifyEqual(state.calls,3);
        end
        function sameBoardDacForEveryAdc(t)
            for board={'jianding','jiaqiang'}
                dac=converter.calibration.reportCalibration('DA9726',board{1},'current',{'DAC1_JG18'});
                for pair={{'AD2208',{'ADC6_JG24'}},{'AD9245',{'X1G','X2G','X3G','X4G'}},{'AD677',{'677_1','677_2'}}}
                    p=pair{1};[cfg,r]=converter.calibration.resolveNoiseCalibration(struct('boardType',board{1}),p{1},p{2},false,true);
                    t.verifyEqual(cfg.kDacVPerCodePp,dac.slopeVPerCode);
                    t.verifyEqual([cfg.adcCalibrationRows.slope],[r.slopeVPerCode]);
                    t.verifyEqual(cfg.calibrationSelection.dac.boardType,board{1});
                end
            end
        end
        function customAndReplay(t)
            row=struct('device','AD677','interface','677_1','slope',1.53251359250316e-4, ...
                'intercept',0,'r2',NaN,'dataGroup','historical 20260928');
            cfg=struct('adcCalibrationRows',row,'kDacVPerCodePp',1.01451391294771e-4);
            [cfg,r]=converter.calibration.resolveNoiseCalibration(cfg,'AD677',{'677_1'},false,true);
            t.verifyEqual(r.slopeVPerCode,row.slope);
            t.verifyEqual(cfg.calibrationSelection.sourceType,'user_calibration');
            t.verifyEmpty(r.sourceDocumentSha256);
            replay=converter.calibration.resolveNoiseCalibration(cfg,'AD677',{'677_1'},false,true);
            t.verifyEqual(replay,cfg);
            cfg.kDacVPerCodePp=2e-4;
            t.verifyError(@() converter.calibration.resolveNoiseCalibration(cfg,'AD677',{'677_1'},false,true), ...
                'converter:calibration:ReplayMismatch');
        end
        function explicitWorkbookAndDacCsv(t)
            fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            workbook=fullfile(fixture.Folder,'custom.xlsx');
            writecell({'title','','','','','';'device','interface','group','k','b','r2'; ...
                'AD2208','ADC6_JG24','user batch',2e-5,0.001,0.99},workbook,'Sheet','刻度参数');
            csv=fullfile(fixture.Folder,'dac.csv');
            writetable(table(1e-4,0.002,0.98,'VariableNames', ...
                {'slope_v_per_code_vpp','intercept_v','fit_r_squared'}),csv);
            [cfg,r]=converter.calibration.resolveNoiseCalibration( ...
                struct('calibrationWorkbook',workbook,'dacSummaryPath',csv), ...
                'AD2208',{'ADC6_JG24'},false,true);
            t.verifyEqual(r.slopeVPerCode,2e-5);t.verifyEqual(cfg.kDacVPerCodePp,1e-4);
            t.verifyEqual(cfg.calibrationSelection.dac.sourceSha256,converter.runtime.sha256File(csv));
            t.verifyEqual(r.sourceDocumentSha256,converter.runtime.sha256File(workbook));
            t.verifyEqual(cfg.calibrationSelection.sourceType,'user_calibration');
        end
        function calibrationCsvPreservesMultilineNotes(t)
            fixture=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            rows=converter.calibration.calibrationCatalog();
            for count=[1 numel(rows)]
                file=fullfile(fixture.Folder,sprintf('rows%d.csv',count));
                converter.report.writeTable(struct2table(rows(1:count),'AsArray',true),file);
                reloaded=readtable(file,'TextType','string','Encoding','UTF-8');
                t.verifyEqual(height(reloaded),count);
                t.verifyEqual(reloaded.sourceMethod(1),string(rows(1).sourceMethod));
                t.verifyEqual(reloaded.slopeVPerCode,[rows(1:count).slopeVPerCode]');
            end
        end
    end
end

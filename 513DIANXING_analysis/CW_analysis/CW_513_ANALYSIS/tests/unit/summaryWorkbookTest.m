classdef summaryWorkbookTest < matlab.unittest.TestCase
    %SUMMARYWORKBOOKTEST Numeric workbook contract and evidence organization.
    methods (Test)
        function numericAndMissingCellsAreNotText(testCase)
            folder=tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder,'s'));
            sheet=struct('name','刻度','title','刻度','note','Vpp=k×CodePp+b', ...
                'headers',{{'接口','斜率','R²','缺测'}}, ...
                'data',{{'JG18',1.01451391294771e-4,0.99998702,NaN}});
            converter.report.writeSummaryXlsx(fullfile(folder,'结果汇总.xlsx'),sheet);
            unpack=fullfile(folder,'unpacked'); unzip(fullfile(folder,'结果汇总.xlsx'),unpack);
            xml=fileread(fullfile(unpack,'xl','worksheets','sheet1.xml'));
            testCase.verifyTrue(contains(xml,'r="B5" s="3"><v>'));
            testCase.verifyFalse(contains(xml,'r="D5"'));
            testCase.verifyTrue(contains(xml,'JG18'));
            stored=regexp(xml,'r="C5"[^>]*><v>([^<]+)</v>','tokens','once');
            testCase.verifyEqual(str2double(stored{1}),0.99998702,'AbsTol',1e-15);
        end
        function powerSummaryHasTwoConciseSheets(testCase)
            folder=tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder,'s'));
            t=table("JG15",1e6,2e-5,0.001,0.9999,"暂不能判定",1, ...
                'VariableNames',{'Channel','ExpectedFrequencyHz','SlopeVppPerCodePp', ...
                'InterceptVpp','CalibrationR2','Conclusion','InputVoltageVpp'});
            converter.report.writeTable(t,fullfile(folder,'ADC_vpp_codepp_summary.csv'));
            c=table("JG15",1,NaN,1.3,NaN,"unbracketed_extrapolation", ...
                'VariableNames',{'Channel','LastUnclippedInputVpp','FirstClippedInputVpp', ...
                'CriticalInputVpp','CriticalInputDbm','Status'});
            converter.report.writeTable(c,fullfile(folder,'ADC_critical_input_estimate.csv'));
            sheets=converter.report.buildSummarySheets(folder,struct('deviceId','AD2208'));
            testCase.verifyEqual({sheets.name},{'刻度','动态范围'});
            testCase.verifyEqual(sheets(1).data{1,3},2e-5,'AbsTol',1e-15);
            testCase.verifyTrue(contains(sheets(2).data{1,end},'外推'));
            converter.runtime.finalizeBundle(folder,struct('deviceId','AD2208'));
            testCase.verifyTrue(isfile(fullfile(folder,'结果汇总.xlsx')));
            testCase.verifyTrue(isfile(fullfile(folder,'evidence','ADC_vpp_codepp_summary.csv')));
            testCase.verifyFalse(isfile(fullfile(folder,'ADC_vpp_codepp_summary.csv')));
        end
        function staleReturnedPathCanBeRefreshed(testCase)
            folder=tempname; mkdir(folder); mkdir(fullfile(folder,'evidence'));
            testCase.addTeardown(@() rmdir(folder,'s'));
            file=fullfile(folder,'evidence','spectrum.csv');
            fid=fopen(file,'w'); fprintf(fid,'f,a\n1,2\n'); fclose(fid);
            original=struct('outputFolder',folder,'spectrum',string(fullfile(folder,'spectrum.csv')));
            updated=converter.runtime.refreshResultPaths(original,folder);
            testCase.verifyEqual(updated.outputFolder,folder);
            testCase.verifyEqual(updated.spectrum,string(file));
        end
    end
end

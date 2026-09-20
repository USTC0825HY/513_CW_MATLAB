classdef adcRadixTest < matlab.unittest.TestCase
    properties (TestParameter)
        badToken = {'NaN','Inf','1.5',''}
    end
    methods (TestClassSetup)
        function addCore(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'_shared')));
        end
    end
    methods (Test)
        function digitOnlyNeedsRadix(testCase)
            path = testCase.csv(sprintf('sample,code\n0,1000\n1,2000\n'));
            testCase.verifyError(@() converter.io.readAdcCsv(path,testCase.config('auto')), ...
                'converter:io:AmbiguousInputRadix');
        end
        function explicitHexParsesDigitOnly(testCase)
            path = testCase.csv(sprintf('sample,code\n0,1000\n1,FFFF\n2,8000\n'));
            [x,m] = converter.io.readAdcCsv(path,testCase.config('hex'));
            testCase.verifyEqual(x,[4096;-1;-32768]);
            testCase.verifyEqual(m.inputRadix,'hex');
            testCase.verifyNotEmpty(strfind(m.conversionRule,'raw - 2^bits'));
            testCase.verifyEqual(m.sourceSampleCount,3);
        end
        function explicitDecimalKeepsDecimal(testCase)
            path = testCase.csv(sprintf('sample,code\n0,1000\n1,03e3\n'));
            x = converter.io.readAdcCsv(path,testCase.config('decimal'));
            testCase.verifyEqual(x,[1000;3000]);
        end
        function exponentLikeHexNeedsRadix(testCase)
            path = testCase.csv(sprintf('sample,code\n0,03e8\n'));
            testCase.verifyError(@() converter.io.readAdcCsv(path,testCase.config('auto')), ...
                'converter:io:AmbiguousInputRadix');
        end
        function negativeDecimalIsExplicitEvidence(testCase)
            path = testCase.csv(sprintf('sample,code\n0,1000\n1,-1\n'));
            [x,m] = converter.io.readAdcCsv(path,testCase.config('auto'));
            testCase.verifyEqual(x,[1000;-1]);
            testCase.verifyEqual(m.inputRadixSource,'signed_decimal_tokens');
        end
        function radixRowIsEvidence(testCase)
            path = testCase.csv(sprintf('sample,code\nRadix,HEX\n0,1000\n1,FFFF\n'));
            [x,m] = converter.io.readAdcCsv(path,testCase.config('auto'));
            testCase.verifyEqual(x,[4096;-1]);
            testCase.verifyEqual(m.inputRadixSource,'csv_declaration');
        end
        function declarationBeforeColumnNamesIsEvidence(testCase)
            path = testCase.csv(sprintf('# inputRadix=hex\nsample,code\n0,1000\n1,FFFF\n'));
            testCase.verifyEqual(converter.io.readAdcCsv(path,testCase.config('auto')),[4096;-1]);
        end
        function prefixedHexIsEvidence(testCase)
            path = testCase.csv(sprintf('sample,code\n0,0x1000\n1,0xFFFF\n'));
            testCase.verifyEqual(converter.io.readAdcCsv(path,testCase.config('auto')),[4096;-1]);
        end
        function explicitChoiceOverridesHeader(testCase)
            path = testCase.csv(sprintf('sample,code\nRadix,HEX\n0,1000\n'));
            testCase.verifyEqual(converter.io.readAdcCsv(path,testCase.config('decimal')),1000);
        end
        function rejectsInvalidSamples(testCase,badToken)
            path = testCase.csv(sprintf('sample,code\n0,-1\n1,%s\n2,2\n',badToken));
            testCase.verifyError(@() converter.io.readAdcCsv(path,testCase.config('decimal')), ...
                'converter:io:NonNumericData');
        end
        function rejectsUnsignedHexOverflow(testCase)
            path = testCase.csv(sprintf('sample,code\n0,10000\n'));
            testCase.verifyError(@() converter.io.readAdcCsv(path,testCase.config('hex')), ...
                'converter:io:CodeOutOfRange');
        end
        function rejectsSignedDecimalOverflow(testCase)
            path = testCase.csv(sprintf('sample,code\n0,65535\n'));
            testCase.verifyError(@() converter.io.readAdcCsv(path,testCase.config('decimal')), ...
                'converter:io:CodeOutOfRange');
        end
        function unsignedIsCentered(testCase)
            path = testCase.csv(sprintf('sample,code\n0,0000\n1,0800\n2,0FFF\n'));
            cfg = testCase.config('hex'); cfg.adcBits = 12; cfg.adcCodeFormat = 'unsigned';
            testCase.verifyEqual(converter.io.readAdcCsv(path,cfg),[-2048;0;2047]);
        end
        function filtersOnlyDeclaredStrobes(testCase)
            path = testCase.csv(sprintf('sample,code,vld\n0,-1,0\n1,2,1\n2,3,1\n'));
            cfg = testCase.config('decimal'); cfg.filterValidStrobe = true; cfg.validDataColumn = 3;
            [x,m] = converter.io.readAdcCsv(path,cfg);
            testCase.verifyEqual(x,[2;3]);
            testCase.verifyEqual(m.sourceSampleCount,3);
            testCase.verifyEqual(m.retainedSampleCount,2);
        end
        function interactiveConfirmationIsReused(testCase)
            testCase.mockDialogs({{2,true}});
            path = testCase.csv(sprintf('sample,code\n0,1000\n1,2000\n'));
            cfg = testCase.config('auto'); cfg.allowRadixPrompt = true;
            [cfg,~,~,cancelled] = converter.io.prepareAdcRadix(cfg,fileparts(path),{path});
            [x,m] = converter.io.readAdcCsv(path,cfg);
            state = getappdata(0,'cw513TestDialogs');
            testCase.verifyFalse(cancelled);
            testCase.verifyEqual(x,[4096;8192]);
            testCase.verifyEqual(m.inputRadixSource,'user_selection');
            testCase.verifyEqual(state.calls,1);
        end
        function readsFullIlaDepthWithSelectiveColumns(testCase)
            body = repmat(sprintf('0,03e8,ffffffffffffffff,1\n'),131072,1);
            path = testCase.csv(sprintf('sample,code,other,vld\n%s',reshape(body.',1,[])));
            cfg = testCase.config('hex');
            [x,m] = converter.io.readAdcCsv(path,cfg);
            testCase.verifySize(x,[131072,1]);
            testCase.verifyEqual(unique(x),1000);
            testCase.verifyEqual(m.sourceSampleCount,131072);
        end
        function cancelledRadixReturnsBeforeAnalysis(testCase)
            testCase.mockDialogs({{[],false}});
            path = testCase.csv(sprintf('sample,code\n0,1000\n'));
            cfg = testCase.config('auto'); cfg.allowRadixPrompt = true;
            [~,files,~,cancelled] = converter.io.prepareAdcRadix(cfg,fileparts(path),{path});
            testCase.verifyTrue(cancelled);
            testCase.verifyEmpty(files);
        end
        function entryRadixCancelCreatesNoOutput(testCase)
            path = testCase.csv(sprintf('sample,code\n0,1000\n'));
            [folder,name,ext] = fileparts(path);
            testCase.mockDialogs({{[name ext],folder},{[],false}});
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'2208_hy')));
            output = fullfile(folder,[name '_cancelled_output']);
            result = adc_sfdr_analysis(folder,[],output,struct('adcDataColumn',2,'inputRadix','auto'));
            testCase.verifyEmpty(result);
            testCase.verifyFalse(isfolder(output));
        end
        function appendsDecodingForDifferentFiles(testCase)
            first = testCase.csv(sprintf('sample,code\n0,1000\n'));
            second = testCase.csv(sprintf('sample,code\n0,-2\n'));
            [~,a] = converter.io.readAdcCsv(first,testCase.config('hex'));
            [~,b] = converter.io.readAdcCsv(second,testCase.config('decimal'));
            folder = tempname; mkdir(folder);
            testCase.addTeardown(@() rmdir(folder,'s'));
            converter.runtime.recordInputDecoding(folder,a);
            converter.runtime.recordInputDecoding(folder,b);
            t = readtable(fullfile(folder,'input_decoding.csv'),'Delimiter',',','TextType','string');
            testCase.verifyEqual(height(t),2);
            testCase.verifyEqual(t.inputRadix,["hex";"decimal"]);
            testCase.verifyEqual(t.filePath,string({first;second}));
            testCase.verifyEqual(t.adcDataColumn,[2;2]);
        end
        function channelDetectionUsesSelectedHeaderColumn(testCase)
            path = testCase.csv(sprintf( ...
                'sample,adc1_data[15:0],adc2_data[15:0]\n0,1,2\n'));
            cfg = testCase.config('decimal');
            cfg.adcDataColumn = 3;
            cfg.headerModulePattern = ...
                '(?i)(?:u_ad677_|adc)(\d+)(?:/adc_data|_data)';
            cfg.moduleChannelMap = {'','677_1','677_2'};
            [folder,name,ext] = fileparts(path);
            channel = converter.io.detectChannel(path,[name ext],folder,cfg);
            testCase.verifyEqual(channel,'677_2');
        end
    end
    methods (Access = private)
        function mockDialogs(testCase,queue)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'tests','fixtures','file_selection_ui')));
            setappdata(0,'cw513TestDialogs',struct('queue',{queue},'calls',0));
            testCase.addTeardown(@() rmappdata(0,'cw513TestDialogs'));
        end
        function path = csv(testCase,content)
            path = [tempname '.csv'];
            fid = fopen(path,'w'); fprintf(fid,'%s',content); fclose(fid);
            testCase.addTeardown(@() delete(path));
        end
    end
    methods (Static,Access = private)
        function cfg = config(radix)
            cfg = struct('adcDataColumn',2,'adcBits',16,'adcCodeFormat','signed','inputRadix',radix);
        end
    end
end

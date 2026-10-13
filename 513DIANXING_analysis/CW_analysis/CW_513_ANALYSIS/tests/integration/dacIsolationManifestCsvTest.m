classdef dacIsolationManifestCsvTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function setupPaths(testCase)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'_shared')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'766_hy')));
        end
    end
    methods (Test)
        function acceptsReferenceTextWithSpacesAndSemicolons(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            folder=fixture.Folder;
            Tinterval=1/10000;
            A=cos(2*pi*1000*(0:1999)'*Tinterval);
            save(fullfile(folder,'drive.mat'),'A','Tinterval');
            A=A/1000;
            save(fullfile(folder,'victim.mat'),'A','Tinterval');
            pair=table({fullfile(folder,'drive.mat')},{fullfile(folder,'victim.mat')}, ...
                {'X7'},{'X9'},1000,{'A'},{'A'}, ...
                {'DA766 output; PicoScope channel A voltage; connector/load reference not confirmed'}, ...
                'VariableNames',{'driven_file','victim_file','driven_label','victim_label', ...
                'frequency_hz','driven_variable','victim_variable','reference_plane'});
            manifest=fullfile(folder,'pair.csv');
            fid=fopen(manifest,'w','n','UTF-8');
            cleanup=onCleanup(@() fclose(fid));
            fprintf(fid,'%s\n',strjoin(pair.Properties.VariableNames,','));
            rows=compose('%s,%s,X7,V%d,1000,A,A,%s\n',string(pair.driven_file{1}),string(pair.victim_file{1}),(1:7)',string(pair.reference_plane{1}));
            fprintf(fid,'%s',char(join(string(rows),'')));
            clear cleanup;
            result=dac_isolation_analysis(folder,manifest,fullfile(folder,'results'), ...
                struct('hardwareGain',1,'formalEnabled',false));
            testCase.verifyEqual(result.summary.isolation_db,60*ones(7,1),'AbsTol',1e-10);
            testCase.verifyEqual(result.config.pairManifest(1).reference_plane,pair.reference_plane{1});
            testCase.verifyEqual(height(result.summary),7);
        end
    end
end

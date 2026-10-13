classdef configurationOptionsTest < matlab.unittest.TestCase
    % Public configuration contracts; numerical algorithms remain unchanged.
    methods (TestClassSetup)
        function addRuntime(t)
            root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'_shared')));
        end
    end
    methods (Test)
        function derivesRateAfterSourceOverride(t)
            c=converter.runtime.finalizeConfig(sfdrDefaults(),struct('sampleRate',25e6));
            t.verifyEqual(c.sfdrAnalysisSampleRateHz,5e6,AbsTol=1e-9);
            t.verifyEqual(c.ilaCaptureSampleRateHz,25e6,AbsTol=1e-9);
        end
        function derivesRateAfterStrideOverride(t)
            c=converter.runtime.finalizeConfig(sfdrDefaults(),struct('sfdrSampleStride',1));
            t.verifyEqual(c.sfdrAnalysisSampleRateHz,20e6,AbsTol=1e-9);
        end
        function keepsDefaultRate(t)
            c=converter.runtime.finalizeConfig(sfdrDefaults(),struct());
            t.verifyEqual(c.sfdrAnalysisSampleRateHz,4e6,AbsTol=1e-9);
        end
        function rejectsExplicitRateConflict(t)
            t.verifyError(@()converter.runtime.finalizeConfig(sfdrDefaults(), ...
                struct('sampleRate',25e6,'sfdrAnalysisSampleRateHz',4e6)), ...
                'converter:adc:InconsistentSfdrSamplingRate');
        end
        function rejectsMisspelledGain(t)
            t.verifyError(@()converter.runtime.finalizeConfig(struct('hardwareGain',100), ...
                struct('hardwareGian',1)), 'converter:runtime:UnknownConfigField');
        end
        function rejectsZeroGain(t)
            t.verifyError(@()converter.runtime.finalizeConfig(struct('hardwareGain',100), ...
                struct('hardwareGain',0)), 'MATLAB:finalizeConfig:expectedPositive');
        end
        function rejectsMixedOverrideStyles(t)
            t.verifyError(@()converter.runtime.applyRunOptions(sfdrDefaults(), ...
                struct('configOverride',struct(),'sampleRate',25e6)), ...
                'converter:runtime:MixedOverrideStyles');
        end
        function rejectsInactiveDbmRange(t)
            c=struct('analysisId','power_scale','powerRangeVpp',[0.1 2.1],'powerRangeDbm',[-10 6]);
            t.verifyError(@()converter.runtime.finalizeConfig(c,struct('powerRangeDbm',[-20 0])), ...
                'converter:runtime:InactivePowerRange');
        end
        function acceptsExplicitDbmSwitch(t)
            c=struct('analysisId','power_scale','powerRangeVpp',[0.1 2.1],'powerRangeDbm',[-10 6]);
            out=converter.runtime.finalizeConfig(c,struct('powerRangeVpp',[],'powerRangeDbm',[-20 0]));
            t.verifyEmpty(out.powerRangeVpp);
            t.verifyEqual(out.powerRangeDbm,[-20 0]);
        end
        function acceptsCompleteOldSnapshot(t)
            c=struct('analysisId','power_scale','powerRangeVpp',[0.1 2.1],'powerRangeDbm',[-10 6]);
            out=converter.runtime.finalizeConfig(c,c);
            t.verifyEqual(out.powerRangeVpp,c.powerRangeVpp,AbsTol=1e-12);
        end
        function preservesAliasesAndMetadata(t)
            c=converter.runtime.finalizeConfig(struct('dataFolder',''), ...
                struct('dataDir','chosen','metadata',struct('operator','test')));
            t.verifyEqual(c.dataFolder,'chosen');
            t.verifyEqual(c.metadata.operator,'test');
        end
        function rejectsReversedBand(t)
            t.verifyError(@()converter.runtime.finalizeConfig(struct(), ...
                struct('noiseBandHz',[1000 1])), 'converter:runtime:InvalidBand');
        end
        function permitsAutomaticValidRateAndLastColumn(t)
            c=converter.runtime.finalizeConfig(struct('sampleRate',NaN, ...
                'filterValidStrobe',true,'adcDataColumn',0,'validDataColumn',4),struct());
            t.verifyTrue(isnan(c.sampleRate));
            t.verifyEqual(c.adcDataColumn,0);
        end
        function warnsForRetiredSwitch(t)
            t.verifyWarning(@()converter.runtime.finalizeConfig(struct(), ...
                struct('resolutionAuditRequired',true)), 'converter:runtime:InactiveConfigField');
        end
        function warnsForOtherMetricSetting(t)
            t.verifyWarning(@()converter.runtime.finalizeConfig( ...
                struct('deviceId','AD2208','analysisId','power_scale'), ...
                struct('nfft',131072)), 'converter:runtime:InactiveConfigField');
        end
        function recordsOverrideOrigin(t)
            c=converter.runtime.finalizeConfig(struct('hardwareGain',100),struct('hardwareGain',1));
            t.verifyEqual(c.hardwareGain,1);
            t.verifyEqual(c.parameterSources.hardwareGain,'explicit caller override');
        end
        function strictWelchRejectsTypo(t)
            t.verifyError(@()converter.runtime.finalizeConfig(struct(),struct('welch', ...
                struct('targetResolutonHz',0.2))), 'converter:runtime:UnknownConfigField');
        end
    end
end

function c=sfdrDefaults()
c=struct('deviceId','AD9245','analysisId','sfdr','sampleRate',20e6, ...
    'ilaCaptureSampleRateHz',20e6,'sfdrSampleStride',5,'sfdrAnalysisSampleRateHz',4e6);
end

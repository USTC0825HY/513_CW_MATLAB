function config = cw513_adc128_config(branch)
%CW513_ADC128_CONFIG Read device defaults for the optional analysis platform.
%   This adapter contains no parameter values or numerical formulas.
bootstrapRuntime();
if ~strcmp(branch, 'bandwidth')
    error('cw513:platform:UnknownBranch', 'ADC128 supports bandwidth only.');
end
config = adc128Config();
end

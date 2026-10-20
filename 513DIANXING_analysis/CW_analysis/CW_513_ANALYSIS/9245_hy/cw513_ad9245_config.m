function config = cw513_ad9245_config(branch)
%CW513_AD9245_CONFIG Read device defaults for the optional analysis platform.
%   This adapter contains no parameter values or numerical formulas.
bootstrapRuntime();
config = ad9245Config(branch);
end

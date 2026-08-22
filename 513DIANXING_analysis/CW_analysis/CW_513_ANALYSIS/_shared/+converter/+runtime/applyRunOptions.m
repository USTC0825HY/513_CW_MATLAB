function [config, options] = applyRunOptions(config, options)
%APPLYRUNOPTIONS Apply non-destructive per-run configuration overrides.
%   OPTIONS may contain CONFIGOVERRIDE for algorithm parameters and
%   POWERSETPOINTS for an explicit input-power manifest.  Existing calls
%   without OPTIONS keep the fixed device configuration unchanged.

if nargin < 2 || isempty(options)
    options = struct();
    return;
end
if ~isstruct(options) || ~isscalar(options)
    error('converter:runtime:InvalidRunOptions', ...
        '运行选项必须是标量结构体。');
end

if isfield(options, 'configOverride')
    override = options.configOverride;
else
    override = options;
    if isfield(override, 'powerSetpoints')
        override = rmfield(override, 'powerSetpoints');
    end
end
if ~isempty(override)
    config = converter.runtime.mergeConfig(config, override);
end
end

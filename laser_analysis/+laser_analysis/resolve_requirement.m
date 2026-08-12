function requirement = resolve_requirement( ...
    cfg, requirementId, metric, subsystem)
%RESOLVE_REQUIREMENT Select an explicit requirement id or a metric row.
%   Explicit ids are preferred. Metric fallback never resolves multiple
%   matching limits, so conflicting or channel-specific rows remain
%   formally indeterminate.

arguments
    cfg (1, 1) struct
    requirementId (1, 1) string = ""
    metric (1, 1) string = ""
    subsystem (1, 1) string = ""
end

if strlength(strtrim(requirementId)) > 0
    if ~isfield(cfg, 'requirements') || ~istable(cfg.requirements)
        requirement = table();
    else
        requirement = cfg.requirements( ...
            cfg.requirements.requirement_id == requirementId, :);
    end
else
    requirement = laser_analysis.find_requirement(cfg, metric, subsystem);
end
end

function requirement = find_requirement(cfg, metric, subsystem)
%FIND_REQUIREMENT Select one requirement without resolving source conflicts.
%   An empty table is returned when no row matches. Multiple matching rows
%   are returned together so evaluate_requirement yields 暂不能判定.

arguments
    cfg (1, 1) struct
    metric (1, 1) string
    subsystem (1, 1) string = ""
end

if ~isfield(cfg, 'requirements') || ~istable(cfg.requirements)
    requirement = table();
    return;
end
mask = cfg.requirements.metric == metric;
if strlength(subsystem) > 0
    mask = mask & cfg.requirements.subsystem == subsystem;
end
requirement = cfg.requirements(mask, :);
end

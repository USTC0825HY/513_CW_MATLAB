function judgment = evaluate_requirement(value, requirement, formalEnabled)
%EVALUATE_REQUIREMENT Apply one approved requirement to a numeric value.
%   Nonapproved, missing, or nonfinite inputs return 暂不能判定.

arguments
    value (1, 1) double
    requirement table
    formalEnabled (1, 1) logical = true
end
if ~formalEnabled || height(requirement) ~= 1 || ...
        requirement.state(1) ~= "approved" || ~isfinite(value)
    judgment = "暂不能判定";
    return;
end

operator = string(requirement.operator(1));
a = requirement.limit_a(1);
b = requirement.limit_b(1);
switch operator
    case "<"
        pass = value < a;
    case "<="
        pass = value <= a;
    case ">"
        pass = value > a;
    case ">="
        pass = value >= a;
    case "between"
        pass = value >= min(a, b) && value <= max(a, b);
    otherwise
        judgment = "暂不能判定";
        return;
end
if pass
    judgment = "满足";
else
    judgment = "不满足";
end
end

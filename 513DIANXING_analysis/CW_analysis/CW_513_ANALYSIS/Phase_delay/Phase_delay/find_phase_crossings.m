function frequencies=find_phase_crossings(f,phase,target)
%FIND_PHASE_CROSSINGS Downward crossings, linear phase vs log10(f) interpolation.
f=f(:);phase=phase(:);
assert(numel(f)==numel(phase)&&all(isfinite([f;phase]))&&all(f>0)&&all(diff(f)>0));
i=find(phase(1:end-1)>target & phase(2:end)<=target);
frequencies=10.^(log10(f(i))+(target-phase(i))./(phase(i+1)-phase(i)).*log10(f(i+1)./f(i)));
end

function [result,detail] = estimate_threshold_delay(t,x,y,opts)
%ESTIMATE_THRESHOLD_DELAY Compare selected edge thresholds (default 10/50%).
% Window must contain one transition and settled pre/post plateaus.
arguments
    t (:,1) double
    x (:,1) double
    y (:,1) double
    opts.TimeWindow (1,2) double = [-Inf Inf]
    opts.PlateauFraction (1,1) double = 0.15
    opts.SmoothSamples (1,1) double = 1
    opts.Thresholds (:,1) double = [10;50]
end
assert(numel(t)==numel(x)&&numel(t)==numel(y)&&all(isfinite([t;x;y]))&&all(diff(t)>0),'Invalid samples.');
assert(opts.TimeWindow(2)>opts.TimeWindow(1),'Invalid time window.');
assert(opts.PlateauFraction>0&&opts.PlateauFraction<0.4,'PlateauFraction must be between 0 and 0.4.');
assert(opts.SmoothSamples>=1&&mod(opts.SmoothSamples,2)==1,'SmoothSamples must be a positive odd integer.');
assert(~isempty(opts.Thresholds)&&all(isfinite(opts.Thresholds))&&all(opts.Thresholds>0)&&all(opts.Thresholds<=50)&&all(diff(opts.Thresholds)>0),'Thresholds must increase within (0,50].');
keep=t>=opts.TimeWindow(1)&t<=opts.TimeWindow(2);t=t(keep);x=x(keep);y=y(keep);
assert(numel(t)>=20,'Selected window is too short.');
[tx,nx,lx]=edge(t,x,opts); [ty,ny,ly]=edge(t,y,opts);
result=table(opts.Thresholds,tx,ty,ty-tx,(ty-tx)*1e9,'VariableNames', ...
    {'Threshold_percent','Input_crossing_s','Output_crossing_s','Delay_s','Delay_ns'});
detail=struct('t',t,'x',x,'y',y,'normalizedInput',nx,'normalizedOutput',ny, ...
    'inputLevels',lx,'outputLevels',ly,'sampleInterval_s',median(diff(t)));
end

function [times,z,levels]=edge(t,v,opts)
n=max(3,floor(numel(v)*opts.PlateauFraction));
v=movmedian(v,opts.SmoothSamples);
base=median(v(1:n));final=median(v(end-n+1:end));amp=final-base;
noise=max(std(v(1:n)),std(v(end-n+1:end)));
assert(abs(amp)>max(8*noise,eps(max(abs(v)))),'No clear settled step: select a window with flat pre/post plateaus.');
z=(v-base)/amp; levels=[base final];
i50=find(z(1:end-1)<0.5 & z(2:end)>=0.5);
assert(numel(i50)==1,'Multiple/no 50%% crossings: select one edge with TimeWindow or adjust SmoothSamples.');
q=opts.Thresholds/100;ix=zeros(size(q));
for k=1:numel(q)
    candidate=find(z(1:i50)<q(k) & z(2:i50+1)>=q(k),1,'last');
    assert(~isempty(candidate),'No requested threshold crossing before 50%% crossing.');
    ix(k)=candidate;
end
assert(min(ix)>=n&&i50<numel(t)-n,'Edge overlaps plateau region: widen/reposition TimeWindow.');
times=t(ix)+(q-z(ix))./(z(ix+1)-z(ix)).*(t(ix+1)-t(ix));
end

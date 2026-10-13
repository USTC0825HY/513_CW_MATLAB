function [t,x,y] = read_scope_waveform(file,inputChannel,outputChannel,timeUnit)
%READ_SCOPE_WAVEFORM Pico MAT or CSV with Time, Channel A, Channel B, ...
% CSV timeUnit may be auto/s/ms/us/ns/ps. MAT Tstart/Tinterval are seconds.
[~,~,ext]=fileparts(file);
if strcmpi(ext,'.psdata')
    error('phase:Psdata','Export .psdata to CSV or MAT in PicoScope first.');
elseif strcmpi(ext,'.mat')
    d=load(file); a=char(upper(inputChannel)); b=char(upper(outputChannel));
    assert(isfield(d,a)&&isfield(d,b),'Requested channels missing in MAT.');
    assert(isvector(d.(a))&&isvector(d.(b)),'Export one waveform per MAT file.');
    x=double(d.(a)(:)); y=double(d.(b)(:));
    assert(isfield(d,'Tinterval'),'MAT must contain Tinterval (seconds).');
    dt=double(d.Tinterval); assert(isscalar(dt)&&dt>0,'Invalid Tinterval.');
    t0=0; if isfield(d,'Tstart'),t0=double(d.Tstart);end
    assert(isscalar(t0),'Invalid Tstart.');
    t=t0+(0:numel(x)-1)'*dt;
else
    lines=readlines(file); k=find(contains(lower(lines),'time'),1);
    assert(~isempty(k),'CSV needs Time and Channel A/B/... header.');
    delimiter=','; if contains(lines(k),';'),delimiter=';';elseif contains(lines(k),sprintf('\t')),delimiter=sprintf('\t');end
    h=strtrim(erase(split(lines(k),delimiter),'"'));
    ci=find(strcmpi(h,"Channel "+upper(string(inputChannel))) | strcmpi(h,upper(string(inputChannel))),1);
    co=find(strcmpi(h,"Channel "+upper(string(outputChannel))) | strcmpi(h,upper(string(outputChannel))),1);
    assert(~isempty(ci)&&~isempty(co),'Requested channel headers missing.');
    unit=lower(string(timeUnit));
    if unit=="auto"
        unitText=char(join(lines(k:min(k+1,end)), ' '));
        token=regexp(unitText,'(?i)Time\s*[\(\[]\s*(ps|ns|us|µs|μs|ms|s)\s*[\)\]]','tokens','once');
        if isempty(token)
            first=split(lines(min(k+1,end)),delimiter);
            token=regexp(char(first(1)),'[\(\[]\s*(ps|ns|us|µs|μs|ms|s)\s*[\)\]]','tokens','once');
        end
        assert(~isempty(token),'Unknown CSV time unit: set TimeUnit explicitly.');
        unit=string(token{1});
    end
    units=["s","ms","us","µs","μs","ns","ps"]; scales=[1,1e-3,1e-6,1e-6,1e-6,1e-9,1e-12];
    u=find(units==unit,1); assert(~isempty(u),'Unsupported time unit.');
    m=readmatrix(file,'Delimiter',delimiter,'NumHeaderLines',k);
    m=m(~all(isnan(m),2),:);
    t=m(:,1)*scales(u);x=m(:,ci);y=m(:,co);
end
assert(numel(t)==numel(x)&&numel(x)==numel(y)&&numel(t)>=20,'Invalid waveform lengths.');
assert(all(isfinite([t;x;y]))&&all(diff(t)>0),'Nonfinite values or nonincreasing time.');
end

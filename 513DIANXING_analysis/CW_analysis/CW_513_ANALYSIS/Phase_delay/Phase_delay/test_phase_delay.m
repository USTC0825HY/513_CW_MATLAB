function test_phase_delay
% Known delay, gain/offset/polarity, filtering bias and full export regression.
root=fileparts(mfilename('fullpath'));out=fullfile(root,'test_results');
if ~isfolder(out),mkdir(out);end
t=(-100:0.1:400)'*1e-9;
step=@(t,t0,tr) min(max((t-t0)/tr,0),1);
x=2+3*step(t,0,20e-9);y=-1+8*step(t,37e-9,20e-9);
r=estimate_threshold_delay(t,x,y);assert(max(abs(r.Delay_ns-37))<1e-8);
r=estimate_threshold_delay(t,-x,-y);assert(max(abs(r.Delay_ns-37))<1e-8);
r=estimate_threshold_delay(t,x,-y);assert(max(abs(r.Delay_ns-37))<1e-8);
y=-1+8*step(t,37e-9,60e-9);
r=estimate_threshold_delay(t,x,y);assert(max(abs(r.Delay_ns-[41;57]))<1e-8);
bad=false;
try,estimate_threshold_delay(t,sin(t/1e-8),sin(t/1e-8));catch,bad=true;end
assert(bad,'Ambiguous oscillatory waveform must not yield an accepted delay.');
A=x;B=-1+8*step(t,37e-9,20e-9);Tstart=t(1);Tinterval=t(2)-t(1); %#ok<NASGU>
file=fullfile(out,'synthetic.mat');save(file,'A','B','Tstart','Tinterval','-v4');
[tt,xx,yy]=read_scope_waveform(file,'A','B','auto');assert(max(abs(tt-t))<1e-18&&isequal(xx,A)&&isequal(yy,B));
csv=fullfile(out,'synthetic.csv');fid=fopen(csv,'w');fprintf(fid,'Time,Channel A,Channel B\n(ns),(V),(V)\n');fprintf(fid,'%.12g,%.12g,%.12g\n',[t*1e9 A B]');fclose(fid);
[tt,xx,yy]=read_scope_waveform(csv,'A','B','auto');assert(max(abs(tt-t))<1e-18&&max(abs(xx-A))<1e-9&&max(abs(yy-B))<1e-9);
r=analyze_phase_delay(ScopeFile=string(file),OutputDir=string(out),Visible='off');
assert(height(r.bode)==201);assert(abs(r.bode.Phase_deg(end)+892.9969459822623)<1e-9);
assert(max(abs(r.delay.Delay_ns-37))<1e-8);
assert(max(abs(r.bode.Corrected_phase_10pct_deg-r.bode.Phase_deg-360*r.bode.Frequency_Hz*37e-9))<1e-8);
disp('PASS: synthetic thresholds, inversion, edge rejection, CSV/MAT units, Bode preservation and correction sign.');
end

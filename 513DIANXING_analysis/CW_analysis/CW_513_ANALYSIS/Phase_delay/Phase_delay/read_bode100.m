function data = read_bode100(file)
%READ_BODE100 Read semicolon-delimited Bode 100 Gain/Phase export.
lines = readlines(file);
k = find(startsWith(strtrim(lines), 'Frequency (Hz);'),1);
assert(~isempty(k),'Cannot find Bode 100 frequency header.');
headers = split(erase(lines(k),'"'),';');
gainCol = find(contains(headers,'Magnitude (dB)'),1);
phaseCol = find(contains(headers,'Phase ('),1);
assert(~isempty(gainCol) && ~isempty(phaseCol),'Gain/phase columns missing.');
m = readmatrix(file,'Delimiter',';','NumHeaderLines',k);
m = m(~all(isnan(m),2),:);
f=m(:,1); gain=m(:,gainCol); phase=m(:,phaseCol);
assert(all(isfinite([f;gain;phase])) && all(f>0) && all(diff(f)>0), ...
    'Frequency/gain/phase must be finite, with increasing positive frequency.');
% Preserve explicitly unwrapped exports; unwrap only a principal-angle trace.
if all(abs(phase)<=180+1e-8)
    phase=unwrap(phase*pi/180)*180/pi;
end
data=table(f,gain,m(:,phaseCol),phase,'VariableNames', ...
    {'Frequency_Hz','Magnitude_dB','Phase_export_deg','Phase_deg'});
end

function data=read_bode3(file)
%READ_BODE3 Read saved GainPhase Result complex values from a Bode3 ZIP.
% Scope: observed Bode Analyzer Suite 3.50 XML layout, no arbitrary math traces.
z=java.util.zip.ZipFile(char(file)); cleanup=onCleanup(@()z.close());
entry=z.getEntry('TraceValues.xml'); assert(~isempty(entry),'TraceValues.xml missing.');
stream=z.getInputStream(entry);scanner=java.util.Scanner(stream,'UTF-8');
scanner.useDelimiter('\A');xml=char(scanner.next());scanner.close();
block=regexp(xml,'<GainPhase>([\s\S]*?)</GainPhase>','tokens','once');
assert(~isempty(block),'Saved GainPhase data missing.');
items=regexp(block{1},'<item\s[^>]+>','match');
freq=zeros(numel(items),1);h=complex(freq);
for k=1:numel(items)
    ft=regexp(items{k},'\sFrequency="([^"]+)"','tokens','once');
    rt=regexp(items{k},'\sResult="\(([^,]+),\s*([^\)]+)\)"','tokens','once');
    assert(~isempty(ft)&&~isempty(rt),'Frequency/Result missing.');
    freq(k)=str2double(ft{1});h(k)=complex(str2double(rt{1}),str2double(rt{2}));
end
assert(numel(freq)>1&&all(isfinite(freq))&&all(diff(freq)>0)&&all(freq>0),'Invalid frequency grid.');
assert(all(isfinite(h))&&all(abs(h)>0),'Invalid complex response.');
wrapped=angle(h)*180/pi;phase=unwrap(angle(h))*180/pi;
data=table(freq,20*log10(abs(h)),wrapped,phase,'VariableNames', ...
    {'Frequency_Hz','Magnitude_dB','Phase_export_deg','Phase_deg'});
end

function results = analyze_phase_delay(opts)
%ANALYZE_PHASE_DELAY Bode response, scope threshold delays and phase correction.
% Example: analyze_phase_delay(ScopeFile="capture.mat",InputChannel="A",OutputChannel="B")
arguments
    opts.BodeFile (1,1) string = ""
    opts.ScopeFile (1,1) string = ""
    opts.InputChannel (1,1) string = "A"
    opts.OutputChannel (1,1) string = "B"
    opts.TimeUnit (1,1) string = "auto"
    opts.TimeWindow (1,2) double = [-Inf Inf]
    opts.PlateauFraction (1,1) double = 0.15
    opts.SmoothSamples (1,1) double = 1
    opts.OutputDir (1,1) string = ""
    opts.Visible (1,1) string = "on"
end
root=string(fileparts(mfilename('fullpath')));
if opts.OutputDir=="",opts.OutputDir=fullfile(root,'results');end
if ~isfolder(opts.OutputDir),mkdir(opts.OutputDir);end
if opts.BodeFile==""
    files=dir(fullfile(root,'*.csv')); candidates=strings(0);
    for k=1:numel(files)
        p=fullfile(files(k).folder,files(k).name);
        if contains(fileread(p),'Frequency (Hz);'),candidates(end+1)=p;end %#ok<AGROW>
    end
    assert(numel(candidates)==1,'Specify BodeFile: expected exactly one Bode CSV.');
    opts.BodeFile=candidates(1);
end
[~,~,extension]=fileparts(opts.BodeFile);
if strcmpi(extension,'.bode3'),b=read_bode3(opts.BodeFile);else,b=read_bode100(opts.BodeFile);end
f=figure('Visible',opts.Visible,'Color','w','Position',[100 100 1000 740]);
yyaxis left; h1=semilogx(b.Frequency_Hz,b.Magnitude_dB,'LineWidth',1.8);ylabel('Magnitude (dB)');
yyaxis right; h2=semilogx(b.Frequency_Hz,b.Phase_deg,'LineWidth',1.8);ylabel('Phase (deg)');
grid on;xlabel('Frequency (Hz)');title('Bode 100 measured magnitude and phase');
legend([h1 h2],{'Magnitude','Measured phase'},'Location','southwest');
savePlot(f,opts.OutputDir,'bode_response');
writetable(b,fullfile(opts.OutputDir,'bode_response.csv'));
results=struct('bode',b,'options',opts,'status',"bode_only");
if opts.ScopeFile==""
    warning('phase:ScopeMissing','Bode plots saved. Supply ScopeFile (Pico CSV/MAT) and input/output channels to calculate delay.');
    return
end
[t,x,y]=read_scope_waveform(opts.ScopeFile,opts.InputChannel,opts.OutputChannel,opts.TimeUnit);
[delay,d]=estimate_threshold_delay(t,x,y,TimeWindow=opts.TimeWindow, ...
    PlateauFraction=opts.PlateauFraction,SmoothSamples=opts.SmoothSamples);
if any(delay.Delay_s<0),warning('Output leads input: check channel assignment and edge selection.');end
writetable(delay,fullfile(opts.OutputDir,'delay_summary.csv'));
f=figure('Visible',opts.Visible,'Color','w','Position',[100 100 1100 800]);
tiledlayout(3,1);nexttile;plot(t*1e9,[x y]);grid on;xlabel('Time (ns)');ylabel('Exported channel units');legend('Input '+opts.InputChannel,'Output '+opts.OutputChannel);title('Full captured waveforms');
nexttile;plot(d.t*1e9,[d.normalizedInput d.normalizedOutput],'LineWidth',1.2);hold on;grid on;
colors=lines(2);
for k=1:2
    q=delay.Threshold_percent(k)/100;yline(q,':');
    plot([delay.Input_crossing_s(k) delay.Output_crossing_s(k)]*1e9,[q q],'-o','Color',colors(k,:),'LineWidth',2);
end
xlabel('Time (ns)');ylabel('Normalized transition');title('Selected edge: own pre/post plateaus = 0 / 1');
crossings=[delay.Input_crossing_s;delay.Output_crossing_s];
margin=max(0.15*range(crossings),10*d.sampleInterval_s);
xlim([max(d.t(1),min(crossings)-margin),min(d.t(end),max(crossings)+margin)]*1e9);
nexttile;bar(delay.Threshold_percent,delay.Delay_ns);grid on;xticks([10 50]);xlabel('Threshold (%)');ylabel('Output - input (ns)');
title(sprintf('10%%: %.6g ns | 50%%: %.6g ns | sampling: %.6g ns',delay.Delay_ns(1),delay.Delay_ns(2),d.sampleInterval_s*1e9));
savePlot(f,opts.OutputDir,'scope_delay');
for k=1:2
    tag=string(delay.Threshold_percent(k));
    b.('Delay_phase_'+tag+'pct_deg')=-360*b.Frequency_Hz*delay.Delay_s(k);
    b.('Corrected_phase_'+tag+'pct_deg')=b.Phase_deg+360*b.Frequency_Hz*delay.Delay_s(k);
end
writetable(b,fullfile(opts.OutputDir,'phase_corrected.csv'));
f=figure('Visible',opts.Visible,'Color','w','Position',[100 100 1000 700]);
yyaxis left; hm=semilogx(b.Frequency_Hz,b.Magnitude_dB,'Color',[0 0.35 0.7],'LineWidth',1.8);ylabel('Magnitude (dB)');
yyaxis right; hp=semilogx(b.Frequency_Hz,[b.Phase_deg b.Corrected_phase_10pct_deg b.Corrected_phase_50pct_deg],'LineWidth',1.6);
hp(1).Color=[0.4 0.4 0.4];hp(1).LineStyle='--';hp(2).Color=[0.85 0.33 0.1];hp(3).Color=[0.47 0.2 0.65];
grid on;xlabel('Frequency (Hz)');ylabel('Phase (deg)');
legend([hm;hp],{'Magnitude','Measured phase','Corrected: 10% delay','Corrected: 50% delay'},'Location','southwest');
title(sprintf('Magnitude and phase | delays: 10%% = %.3f ns, 50%% = %.3f ns',delay.Delay_ns(1),delay.Delay_ns(2)));
yline(-45,':','-45 deg','HandleVisibility','off');
firstCross=nan(2,1);count=zeros(2,1);notes=strings(2,1);
for k=1:2
    tag=string(delay.Threshold_percent(k));
    crossings=find_phase_crossings(b.Frequency_Hz,b.('Corrected_phase_'+tag+'pct_deg'),-45);
    count(k)=numel(crossings);
    if ~isempty(crossings)
        firstCross(k)=crossings(1);
        label=sprintf('%s%%: %.4g MHz',tag,crossings(1)/1e6);
        align='top';if k==2,align='bottom';end
        xline(crossings(1),':',label,'Color',hp(k+1).Color,'LabelVerticalAlignment',align,'HandleVisibility','off');
        hold on;plot(crossings(1),-45,'o','Color',hp(k+1).Color,'MarkerFaceColor',hp(k+1).Color,'HandleVisibility','off');
        notes(k)=tag+"%: "+sprintf('%.4g MHz',crossings(1)/1e6);
    else
        notes(k)=tag+"%: no downward -45 deg crossing in scan";
    end
end
subtitle(join(notes," | "));
results.phase45=table(delay.Threshold_percent,firstCross,count,'VariableNames', ...
    {'Threshold_percent','First_downward_minus45_Hz','Downward_crossing_count'});
writetable(results.phase45,fullfile(opts.OutputDir,'phase45_summary.csv'));
savePlot(f,opts.OutputDir,'phase_corrected');
results.bode=b;results.delay=delay;results.waveform=d;results.status="complete";
save(fullfile(opts.OutputDir,'analysis.mat'),'results');disp(delay);
end

function savePlot(f,folder,name)
exportgraphics(f,fullfile(folder,name+".png"),'Resolution',180);
savefig(f,fullfile(folder,name+".fig"));
if strcmp(f.Visible,'off'),close(f);end
end

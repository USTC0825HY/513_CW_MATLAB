function summary=run_bandwidth_5pct
%RUN_BANDWIDTH_5PCT Supplement the original batch with 5/10/50% comparisons.
root=fileparts(mfilename('fullpath'));addpath(root);folder=fullfile(root,'相移带宽');
out=fullfile(folder,'results','5pct');if ~isfolder(out),mkdir(out);end
files=dir(fullfile(folder,'*.mat'));names=strings(numel(files),1);v=nan(numel(files),10);allResults=cell(numel(files),1);
for k=1:numel(files)
    [~,name]=fileparts(files(k).name);names(k)=upper(string(name));dest=fullfile(out,names(k));if ~isfolder(dest),mkdir(dest);end
    [t,x,y]=read_scope_waveform(fullfile(folder,files(k).name),'A','B','auto');
    [delay,d]=estimate_threshold_delay(t,x,y,Thresholds=[5;10;50]);
    b=read_bode3(fullfile(folder,names(k)+".bode3"));crossings=nan(3,1);counts=zeros(3,1);
    for j=1:3
        tag=string(delay.Threshold_percent(j));
        b.('Delay_phase_'+tag+'pct_deg')=-360*b.Frequency_Hz*delay.Delay_s(j);
        b.('Corrected_phase_'+tag+'pct_deg')=b.Phase_deg+360*b.Frequency_Hz*delay.Delay_s(j);
        fc=find_phase_crossings(b.Frequency_Hz,b.('Corrected_phase_'+tag+'pct_deg'),-45);
        counts(j)=numel(fc);if ~isempty(fc),crossings(j)=fc(1);end
    end
    phase45=table(delay.Threshold_percent,crossings,counts,'VariableNames',{'Threshold_percent','First_downward_minus45_Hz','Downward_crossing_count'});
    noise=zeros(2,4);channels={d.normalizedInput,d.normalizedOutput};
    for j=1:2
        z=channels{j};i50=find(z(1:end-1)<.5 & z(2:end)>=.5);n=floor(numel(z)*.15);
        ix=find(z(1:i50)<.05 & z(2:i50+1)>=.05);
        noise(j,:)=[std(z(1:n)),max(z(1:n)),numel(ix),numel(find(z(1:n-1)<.05 & z(2:n)>=.05))];
    end
    noiseTable=[table(["A";"B"],'VariableNames',{'Channel'}),array2table(noise,'VariableNames', ...
        {'Baseline_normalized_std','Baseline_normalized_max','Crossings5_before50','Baseline_crossings5'})];
    results=struct('delay',delay,'waveform',d,'bode',b,'phase45',phase45,'noise',noiseTable, ...
        'inputChannel',"A",'outputChannel',"B",'thresholds',[5;10;50],'plateauFraction',.15,'smoothSamples',1);
    save(fullfile(dest,'analysis.mat'),'results');writetable(delay,fullfile(dest,'delay_summary.csv'));
    writetable(b,fullfile(dest,'phase_corrected.csv'));writetable(phase45,fullfile(dest,'phase45_summary.csv'));writetable(noiseTable,fullfile(dest,'noise_diagnostics.csv'));
    v(k,:)=[delay.Delay_ns',crossings'/1e6,b.Corrected_phase_5pct_deg(end),noise(1,1:3)];
    allResults{k}=results;
    % Check 10/50% compatibility against the previous actual-data analysis.
    previous=fullfile(folder,'results',names(k),'analysis.mat');
    if isfile(previous),old=load(previous);assert(max(abs(old.results.delay.Delay_s-delay.Delay_s(2:3)))<1e-15);end
    plotResults(results,dest,names(k));
end
summary=[table(names,'VariableNames',{'Path'}),array2table(v,'VariableNames', ...
    {'Delay5_ns','Delay10_ns','Delay50_ns','Phase45_5_MHz','Phase45_10_MHz','Phase45_50_MHz', ...
    'EndPhase5_deg','InputBaseline_std','InputBaseline_max','InputCrossings5_before50'})];
writetable(summary,fullfile(out,'batch_summary_5pct.csv'));save(fullfile(out,'batch_analysis_5pct.mat'),'summary','allResults');
writeReport(out,summary,allResults);disp(summary);
end

function plotResults(r,out,name)
b=r.bode;d=r.waveform;delay=r.delay;colors=[.1 .55 .2;.85 .33 .1;.47 .2 .65];
f=figure('Visible','off','Color','w','Position',[50 50 1200 700]);
yyaxis left;hm=semilogx(b.Frequency_Hz,b.Magnitude_dB,'LineWidth',1.8);ylabel('Magnitude (dB)');
yyaxis right;p=[b.Corrected_phase_5pct_deg b.Corrected_phase_10pct_deg b.Corrected_phase_50pct_deg];
hp=semilogx(b.Frequency_Hz,p,'LineWidth',1.7);hold on;
notes=strings(3,1);
for j=1:3
    hp(j).Color=colors(j,:);styles={'-','--',':'};hp(j).LineStyle=styles{j};
    fc=r.phase45.First_downward_minus45_Hz(j);q=delay.Threshold_percent(j);
    if isfinite(fc)
        plot(fc,-45,'o','Color',colors(j,:),'MarkerFaceColor',colors(j,:),'HandleVisibility','off');xline(fc,':','Color',colors(j,:),'HandleVisibility','off');
        notes(j)=sprintf('%d%%: %.4f MHz',q,fc/1e6);
    else,notes(j)=sprintf('%d%%: no crossing',q);end
end
yline(-45,':','-45 deg','HandleVisibility','off');ylim([min(-60,min(p,[],'all'))-5,max(10,max(p,[],'all'))+5]);
ylabel('Corrected phase (deg)');xlabel('Frequency (Hz)');grid on;title(name+" | magnitude and 5/10/50% delay-corrected phase",'Interpreter','none');subtitle("f(-45 deg): "+join(notes," | "));
legend([hm;hp],{'Magnitude','5% correction','10% correction','50% correction'},'Location','southwest');saveFigure(f,out,'corrected_bandwidth_5pct');
f=figure('Visible','off','Color','w','Position',[50 50 1200 850]);tiledlayout(2,2);
nexttile([1 2]);plot(d.t*1e9,[d.normalizedInput,d.normalizedOutput]);hold on;grid on;
for j=1:3,q=delay.Threshold_percent(j)/100;plot([delay.Input_crossing_s(j),delay.Output_crossing_s(j)]*1e9,[q q],'-o','Color',colors(j,:),'LineWidth',1.6);end
xlim([min(delay.Input_crossing_s)*1e9-15,max(delay.Output_crossing_s)*1e9+35]);xlabel('Time (ns)');ylabel('Normalized amplitude');title(name+" | thresholds and delays",'Interpreter','none');
subtitle(sprintf('5%% = %.3f ns | 10%% = %.3f ns | 50%% = %.3f ns',delay.Delay_ns));
for j=1:2
    nexttile;z=d.normalizedInput;if j==2,z=d.normalizedOutput;end
    plot(d.t*1e9,z,'.-');hold on;yline(.05,'--','5%');yline(.1,':','10%');grid on;
    tc=delay.Input_crossing_s(1);if j==2,tc=delay.Output_crossing_s(1);end
    plot(tc*1e9,.05,'ro','MarkerFaceColor','r');xlim(tc*1e9+[-10 10]);ylim([-.06 .22]);xlabel('Time (ns)');ylabel('Normalized amplitude');
    label='Input A';if j==2,label='Output B';end
    title(sprintf('%s: selected last 5%% crossing = %.3f ns',label,tc*1e9));
end
saveFigure(f,out,'scope_5pct');
end

function saveFigure(f,out,name)
exportgraphics(f,fullfile(out,name+".png"),'Resolution',180);savefig(f,fullfile(out,name+".fig"));close(f);
end

function writeReport(out,s,allResults)
fid=fopen(fullfile(out,'5%阈值延迟分析报告.md'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# 满阶跃幅度 5%% 阈值延迟补充分析\n\n');
fprintf(fid,'本次延续原有 7 条路径、A 输入/B 输出、全记录首尾各 15%% 中位数平台、不平滑的条件，新增 5%%，同时保留 10%%/50%% 对照。计算与绘图均使用 MATLAB，未扣除 line 参考。\n\n');
fprintf(fid,'## 1. “满幅度 5%%”的定义\n\n这里的满幅度是**各通道稳态平台之间的阶跃变化量**，不是示波器量程的 5%%，也不是过冲峰值的 5%%。阈值电压为 $V_5=V_0+0.05(V_1-V_0)$。对于带直流偏置或负起始电平的波形，必须先减去边沿前平台。\n\n');
fprintf(fid,'以唯一的归一化 50%% 上升交点定位本次边沿，取其前**最后一次向上穿越 5%%**的交点，在线性插值后计算 $\\tau_5=t_{B,5}-t_{A,5}$。这个操作定义与此前 10%% 的规则一致；它不是整条记录里第一次超过 5%% 的时刻。\n\n');
fprintf(fid,'## 2. 延迟与 −45° 频率\n\n| 路径 | 5%%延迟/ns | 10%%延迟/ns | 50%%延迟/ns | 5%%校正−45°/MHz | 10%%校正/MHz | 50%%校正/MHz |\n|---|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(s),fprintf(fid,'| %s | %.3f | %.3f | %.3f | %s | %s | %s |\n',s.Path(k),s.Delay5_ns(k),s.Delay10_ns(k),s.Delay50_ns(k),num(s.Phase45_5_MHz(k)),num(s.Phase45_10_MHz(k)),num(s.Phase45_50_MHz(k)));end
fprintf(fid,'\n频率是校正相位首次下降到 −45° 的交点，使用相邻点间对数频率插值；未观测到表示 1 Hz–10 MHz 扫描内无交点，不外推。公式仍为 $\\phi_{5,\\mathrm{corr}}=\\phi_{\\mathrm{meas}}+360f\\tau_5$。幅频与三种校正相频在同一双纵轴图中绘制。\n\n');
fprintf(fid,'## 3. 5%% 阈值的噪声限制\n\n**全部 7 条记录的输入基线最大偏移均超过自身阶跃幅度的 5%%。** 输入基线标准差约为阶跃幅度的 2%%–3%%；在 50%% 交点之前存在多次噪声或边沿造成的 5%% 上穿。因此，不能将“首次超过 5%%”直接当作信号到达。\n\n');
fprintf(fid,'| 路径 | 输入基线标准差/阶跃幅度 | 输入基线最大偏移/阶跃幅度 | 输入50%%前5%%上穿次数 | 输出50%%前5%%上穿次数 |\n|---|---:|---:|---:|---:|\n');
for k=1:height(s),r=allResults{k};fprintf(fid,'| %s | %.2f%% | %.2f%% | %d | %d |\n',s.Path(k),100*s.InputBaseline_std(k),100*s.InputBaseline_max(k),r.noise.Crossings5_before50(1),r.noise.Crossings5_before50(2));end
fprintf(fid,'\n本报告保留未经平滑的结果，并在波形图中显示选中的 5%% 交点及其附近原始样本。该结果是明确选点规则下的阈值时差，但相对于 10%%/50%% 对噪声和采样点更敏感。末次交点规则不能消除噪声影响；降低阈值不自动提高纯延迟估计准确度。数值显示到 0.001 ns 仅用于复现插值，采样间隔仍约 0.4 ns，没有建立统计置信区间。\n\n');
fprintf(fid,'由于输出边沿变缓，本批 5%% 延迟通常比 10%% 小。较小延迟加回较少相位，因此校正后 −45° 频率可能降低或从无交点变为有交点。这属于阈值选择对等效校正的影响，不是设备物理带宽因算法改变。阈值仍包含滤波与通道偏斜，不能据此唯一分离纯传输延迟。\n\n');
fprintf(fid,'## 4. 每条路径的取点与结果\n\n');
for k=1:height(s)
    r=allResults{k};d=r.waveform;
    fprintf(fid,'### %s\n\n',s.Path(k));
    fprintf(fid,'输入 5%% 阈值电压 %.6f，输出 %.6f（原始 MAT 电压单位）；输入时刻 %.3f ns，输出时刻 %.3f ns。5%% 校正后 10 MHz 相位为 %.3f°。\n\n', ...
        d.inputLevels(1)+.05*diff(d.inputLevels),d.outputLevels(1)+.05*diff(d.outputLevels),r.delay.Input_crossing_s(1)*1e9,r.delay.Output_crossing_s(1)*1e9,s.EndPhase5_deg(k));
    fprintf(fid,'![%s 幅频与三阈值校正相频](%s/corrected_bandwidth_5pct.png)\n\n![%s 阈值与5%%附近样本](%s/scope_5pct.png)\n\n',s.Path(k),s.Path(k),s.Path(k),s.Path(k));
end
fprintf(fid,'## 5. 复现与文件\n\n在 MATLAB 当前目录设为 `Phase_delay` 后运行：\n\n```matlab\nsummary = run_bandwidth_5pct;\n```\n\n');
fprintf(fid,'输出为 `相移带宽/results/5pct`，包含本报告、`batch_summary_5pct.csv`、`batch_analysis_5pct.mat`。各路径下包含三阈值延迟表、三阈值校正相位 CSV、−45°表、噪声诊断、MAT 和 PNG/FIG。原有 10%%/50%% 结果目录保留。程序已逐条核对，重新计算的 10%%/50%% 延迟与此前结果一致。\n');
end

function value=num(x)
if isnan(x),value='未观测到';else,value=sprintf('%.4f',x);end
end

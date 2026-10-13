function summary=run_bandwidth_cable(opts)
%RUN_BANDWIDTH_CABLE Recompute thresholds with explicit cable reference planes.
arguments
    opts.ScopeCableDelay_ns (1,1) double = 10
    opts.BodeCableDelay_ns (1,1) double = 0
end
assert(all(isfinite([opts.ScopeCableDelay_ns,opts.BodeCableDelay_ns]))&&min([opts.ScopeCableDelay_ns,opts.BodeCableDelay_ns])>=0);
root=fileparts(mfilename('fullpath'));addpath(root);folder=fullfile(root,'相移带宽');
out=fullfile(folder,'results',sprintf('cable_scope%gns_bode%gns',opts.ScopeCableDelay_ns,opts.BodeCableDelay_ns));
if ~isfolder(out),mkdir(out);end
files=dir(fullfile(folder,'*.mat'));names=strings(numel(files),1);v=nan(numel(files),15);allResults=cell(numel(files),1);
for k=1:numel(files)
    [~,name]=fileparts(files(k).name);names(k)=upper(string(name));dest=fullfile(out,names(k));if ~isfolder(dest),mkdir(dest);end
    [t,x,y]=read_scope_waveform(fullfile(folder,files(k).name),'A','B','auto');
    [delay,d]=estimate_threshold_delay(t,x,y,Thresholds=[5;10;50]);
    delay.ScopeCableDelay_ns=repmat(opts.ScopeCableDelay_ns,3,1);
    delay.DeviceDelay_ns=delay.Delay_ns-opts.ScopeCableDelay_ns;
    delay.DeviceDelay_s=delay.Delay_s-opts.ScopeCableDelay_ns*1e-9;
    assert(all(delay.DeviceDelay_s>0),'Cable delay exceeds measured threshold delay.');
    b=read_bode3(fullfile(folder,names(k)+".bode3"));
    b.Bode_cable_phase_deg=-360*b.Frequency_Hz*opts.BodeCableDelay_ns*1e-9;
    b.Device_measured_phase_deg=b.Phase_deg-b.Bode_cable_phase_deg;
    fc=nan(3,1);oldfc=fc;bothfc=fc;counts=zeros(3,1);
    for j=1:3
        tag=string(delay.Threshold_percent(j));
        old=b.Phase_deg+360*b.Frequency_Hz*delay.Delay_s(j);
        p=b.Device_measured_phase_deg+360*b.Frequency_Hz*delay.DeviceDelay_s(j);
        both=b.Phase_deg+360*b.Frequency_Hz*opts.ScopeCableDelay_ns*1e-9+360*b.Frequency_Hz*delay.DeviceDelay_s(j);
        b.('Original_correction_'+tag+'pct_deg')=old;
        b.('Corrected_phase_'+tag+'pct_deg')=p;
        b.('Both_same_cable_'+tag+'pct_deg')=both;
        c=find_phase_crossings(b.Frequency_Hz,p,-45);counts(j)=numel(c);if ~isempty(c),fc(j)=c(1);end
        c=find_phase_crossings(b.Frequency_Hz,old,-45);if ~isempty(c),oldfc(j)=c(1);end
        c=find_phase_crossings(b.Frequency_Hz,both,-45);if ~isempty(c),bothfc(j)=c(1);end
        assert(max(abs(both-old))<1e-9,'Common cable must cancel algebraically.');
        expected=360*b.Frequency_Hz*(opts.BodeCableDelay_ns-opts.ScopeCableDelay_ns)*1e-9;
        assert(max(abs(p-old-expected))<1e-9,'Cable correction sign check failed.');
        if isfinite(fc(j)),assert(abs(interp1(log10(b.Frequency_Hz),p,log10(fc(j)))+45)<1e-8);end
    end
    phase45=table(delay.Threshold_percent,fc,oldfc,bothfc,counts,'VariableNames', ...
        {'Threshold_percent','New_minus45_Hz','Original_minus45_Hz','Both_same_cable_minus45_Hz','New_crossing_count'});
    results=struct('options',opts,'delay',delay,'waveform',d,'bode',b,'phase45',phase45);
    save(fullfile(dest,'analysis.mat'),'results');writetable(delay,fullfile(dest,'delay_summary.csv'));
    writetable(b,fullfile(dest,'phase_corrected.csv'));writetable(phase45,fullfile(dest,'phase45_summary.csv'));
    v(k,:)=[delay.Delay_ns',delay.DeviceDelay_ns',fc'/1e6,oldfc'/1e6, ...
        b.Corrected_phase_5pct_deg(end),b.Corrected_phase_10pct_deg(end),b.Corrected_phase_50pct_deg(end)];
    allResults{k}=results;plotResult(results,dest,names(k));
end
summary=[table(names,'VariableNames',{'Path'}),array2table(v,'VariableNames', ...
    {'TotalDelay5_ns','TotalDelay10_ns','TotalDelay50_ns','DeviceDelay5_ns','DeviceDelay10_ns','DeviceDelay50_ns', ...
    'NewPhase45_5_MHz','NewPhase45_10_MHz','NewPhase45_50_MHz','OriginalPhase45_5_MHz','OriginalPhase45_10_MHz','OriginalPhase45_50_MHz', ...
    'EndPhase5_deg','EndPhase10_deg','EndPhase50_deg'})];
writetable(summary,fullfile(out,'cable_summary.csv'));save(fullfile(out,'batch_analysis.mat'),'summary','allResults','opts');
writeReport(out,summary,opts);disp(summary);
end

function plotResult(r,out,name)
b=r.bode;colors=[.1 .55 .2;.85 .33 .1;.47 .2 .65];
f=figure('Visible','off','Color','w','Position',[50 50 1200 740]);
yyaxis left;hm=semilogx(b.Frequency_Hz,b.Magnitude_dB,'LineWidth',1.8);ylabel('Magnitude (dB)');
yyaxis right;p=[b.Corrected_phase_5pct_deg b.Corrected_phase_10pct_deg b.Corrected_phase_50pct_deg];
hp=semilogx(b.Frequency_Hz,p,'LineWidth',1.8);hold on;notes=strings(3,1);
for j=1:3
    hp(j).Color=colors(j,:);styles={'-','--',':'};hp(j).LineStyle=styles{j};fc=r.phase45.New_minus45_Hz(j);
    if isfinite(fc)
        plot(fc,-45,'o','Color',colors(j,:),'MarkerFaceColor',colors(j,:),'HandleVisibility','off');xline(fc,':','Color',colors(j,:),'HandleVisibility','off');
        notes(j)=sprintf('%d%%: %.4f MHz',r.delay.Threshold_percent(j),fc/1e6);
    else,notes(j)=sprintf('%d%%: no crossing',r.delay.Threshold_percent(j));end
end
yline(-45,':','-45 deg','HandleVisibility','off');grid on;
ylim([min(-60,min(p,[],'all'))-5,max(10,max(p,[],'all'))+5]);
ylabel('Corrected phase (deg)');xlabel('Frequency (Hz)');
title(sprintf('%s | cable removed: scope %.3g ns, Bode %.3g ns',name,r.options.ScopeCableDelay_ns,r.options.BodeCableDelay_ns),'Interpreter','none');
subtitle("f(-45 deg): "+join(notes," | "));
legend([hm;hp],{'Magnitude','5% correction','10% correction','50% correction'},'Location','southwest');
exportgraphics(f,fullfile(out,'corrected_bandwidth_cable.png'),'Resolution',180);savefig(f,fullfile(out,'corrected_bandwidth_cable.fig'));close(f);
end

function writeReport(out,s,opts)
fid=fopen(fullfile(out,'线缆延迟修正分析报告.md'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# 考虑线缆延迟后的重新分析\n\n');
fprintf(fid,'本次使用 MATLAB 从原始 7 组示波器 MAT 与 Bode3 重新计算，阈值为 5%%、10%%、50%%，A 输入/B 输出，首尾各 15%% 中位数平台，不平滑。**主结果假设：示波器总延迟含 %.3g ns 线缆；Bode 原始相位中需要另外去除 %.3g ns 线缆。** 这两个参数代表不同测量参考面，不能混用。\n\n',opts.ScopeCableDelay_ns,opts.BodeCableDelay_ns);
fprintf(fid,'用户给定约 10 ns，本次按设定值作为确定的常数输入，未据此建立不确定度。未再叠加 `line.bode3` 的相位延迟，避免重复计算同一项。\n\n');
fprintf(fid,'## 1. 修正公式与参考面\n\n');
fprintf(fid,'设 $\\tau_q$ 为原示波器阈值总延迟，$\\tau_{c,S}$ 为示波器中的线缆延迟，$\\tau_{c,B}$ 为 Bode 测量中要去除的线缆延迟，则：\n\n');
fprintf(fid,'$$\\tau_{q,\\mathrm{device}}=\\tau_q-\\tau_{c,S}$$\n\n$$\\phi_{\\mathrm{device}}=\\phi_{\\mathrm{Bode}}+360f\\tau_{c,B}$$\n\n$$\\phi_{q,\\mathrm{new}}=\\phi_{\\mathrm{Bode}}+360f(\\tau_q-\\tau_{c,S}+\\tau_{c,B}).$$\n\n');
fprintf(fid,'因此相对旧校正结果：\n\n$$\\Delta\\phi=360f(\\tau_{c,B}-\\tau_{c,S}).$$\n\n');
fprintf(fid,'- **仅示波器减去 10 ns，Bode 保持原样：** 新相位比旧相位低 $360f\\times10^{-8}$ 度，即 1 MHz 低 3.6°、10 MHz 低 36°，−45° 交点通常向低频移动。该结果仅在 Bode 无此额外线缆项或已补偿时能直接作为统一参考面的剩余相位。\n');
fprintf(fid,'- **示波器和 Bode 都包含同一 10 ns：** 对两者一致去除线缆，设备阈值延迟仍减少 10 ns，但两项相位修正相互抵消，最终剩余相位及 −45° 频率与旧结果相同。这不是没有考虑线缆，而是统一参考面的结果。\n\n');
fprintf(fid,'仅说明“总延迟含 10 ns”尚不能确定 Bode 是否也含它；本报告明确列出主假设，并给出同线缆情形的对照。应按实际配线、Bode 校准/端口延伸状态选取。\n\n');
fprintf(fid,'## 2. 总延迟与设备阈值延迟\n\n| 路径 | 总5%%/ns | 总10%%/ns | 总50%%/ns | 设备5%%/ns | 设备10%%/ns | 设备50%%/ns |\n|---|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(s),fprintf(fid,'| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |\n',s.Path(k),s{k,2:7});end
fprintf(fid,'\n这里只扣除外部常数线缆延迟；“设备阈值延迟”仍包含滤波对边沿的影响，不等于严格分离出的纯传输延迟。原波形取点时间保留在各路径 `delay_summary.csv`，没有人为移动原始采样时间。\n\n');
fprintf(fid,'## 3. 主假设下的新 −45° 频率\n\n| 路径 | 5%%校正/MHz | 10%%校正/MHz | 50%%校正/MHz | 10MHz新相位5%%/° | 10%%/° | 50%%/° |\n|---|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(s),fprintf(fid,'| %s | %s | %s | %s | %.2f | %.2f | %.2f |\n',s.Path(k),num(s.NewPhase45_5_MHz(k)),num(s.NewPhase45_10_MHz(k)),num(s.NewPhase45_50_MHz(k)),s{k,14:16});end
fprintf(fid,'\n未观测到：1 Hz–10 MHz 扫描内没有首次向下穿越 −45°，不外推。频率按相邻实测点间相位对 log10(f) 线性插值。幅值未改变，所以幅值 −3 dB 带宽也未改变；这里只改变相位校正。\n\n');
fprintf(fid,'## 4. 两边均有相同线缆时的 −45° 对照\n\n下表与旧校正一致，但使用“Bode 去线缆 + 设备延迟扣除”的统一参考面公式重新计算并检验过。\n\n| 路径 | 5%%/MHz | 10%%/MHz | 50%%/MHz |\n|---|---:|---:|---:|\n');
for k=1:height(s),fprintf(fid,'| %s | %s | %s | %s |\n',s.Path(k),num(s.OriginalPhase45_5_MHz(k)),num(s.OriginalPhase45_10_MHz(k)),num(s.OriginalPhase45_50_MHz(k)));end
fprintf(fid,'\n## 5. 图与数据\n\n');
for k=1:height(s),fprintf(fid,'### %s\n\n![主假设下幅频和三阈值校正相位](%s/corrected_bandwidth_cable.png)\n\n',s.Path(k),s.Path(k));end
fprintf(fid,'## 6. 局限与复现\n\n');
fprintf(fid,'5%% 的输入基线存在多次过阈值，仍采用明确 50%% 边沿前最后一次上穿规则，对噪声敏感。采样间隔约 0.4 ns，插值位数不是准确度；“约 10 ns”也不是精确校准。若仅一边的线缆延迟有 1 ns 误差，10 MHz 校正相位会变化 3.6°。若两边同线缆严格一致，该公共项抵消，但不同配线或校准误差不能保证抵消。\n\n');
fprintf(fid,'在 MATLAB 将 `Phase_delay` 设为当前目录：\n\n```matlab\n%% 主假设：仅示波器包含额外线缆\nsummary = run_bandwidth_cable(ScopeCableDelay_ns=10,BodeCableDelay_ns=0);\n%% 两次测量均包含相同线缆\nsummary = run_bandwidth_cable(ScopeCableDelay_ns=10,BodeCableDelay_ns=10);\n```\n\n');
fprintf(fid,'两种运行会写入不同的 `results/cable_scope..._bode...` 子目录。各路径含 PNG/FIG、原始与新相位 CSV、阈值总延迟与设备延迟表、−45°表和 MAT。总表为 `cable_summary.csv`。频域表同时保留 `Original_correction_*`、`Corrected_phase_*` 和 `Both_same_cable_*` 三组相位，便于追溯。\n');
end

function value=num(x)
if isnan(x),value='未观测到';else,value=sprintf('%.4f',x);end
end

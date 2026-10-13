function summary=run_bandwidth_batch
%RUN_BANDWIDTH_BATCH Analyze all paired scope MAT and Bode3 files in 相移带宽.
root=fileparts(mfilename('fullpath'));addpath(root);
folder=fullfile(root,'相移带宽');out=fullfile(folder,'results');
if ~isfolder(out),mkdir(out);end
files=dir(fullfile(folder,'*.mat'));allResults=cell(numel(files),1);
names=strings(numel(files),1);values=nan(numel(files),12);
for k=1:numel(files)
    [~,name]=fileparts(files(k).name);names(k)=upper(string(name));
    bode=fullfile(folder,names(k)+".bode3");
    assert(isfile(bode),'Missing matching Bode3 for %s',name);
    fprintf('\nAnalyzing %s\n',names(k));
    r=analyze_phase_delay(BodeFile=string(bode), ...
        ScopeFile=string(fullfile(files(k).folder,files(k).name)), ...
        InputChannel="A",OutputChannel="B",Visible="off", ...
        OutputDir=string(fullfile(out,names(k))));
    b=r.bode;g=median(b.Magnitude_dB(b.Frequency_Hz<=1000));
    fc=find_phase_crossings(b.Frequency_Hz,b.Magnitude_dB,g-3);
    if isempty(fc),fc=NaN;else,fc=fc(1);end
    values(k,:)=[r.delay.Delay_ns',diff(r.delay.Delay_ns), ...
        r.phase45.First_downward_minus45_Hz'/1e6,g,fc/1e6, ...
        b.Corrected_phase_10pct_deg(end),b.Corrected_phase_50pct_deg(end), ...
        r.waveform.sampleInterval_s*1e9,b.Phase_deg(end),b.Frequency_Hz(end)/1e6];
    allResults{k}=r;
    plot_corrected_bandwidth(r,fullfile(out,names(k)),names(k));
    bodeData=b;save(fullfile(out,names(k),'bode_extracted.mat'),'bodeData');
end
summary=[table(names,'VariableNames',{'Path'}),array2table(values,'VariableNames', ...
    {'Delay10_ns','Delay50_ns','Difference_ns','Phase45_10_MHz','Phase45_50_MHz', ...
    'LowFrequencyGain_dB','Magnitude3dB_MHz','EndPhase10_deg','EndPhase50_deg', ...
    'SampleInterval_ns','EndMeasuredPhase_deg','EndFrequency_MHz'})];
writetable(summary,fullfile(out,'batch_summary.csv'));
save(fullfile(out,'batch_analysis.mat'),'summary','allResults');
f=figure('Visible','off','Color','w','Position',[50 50 1150 850]);tiledlayout(2,1);
nexttile;bar(summary{:,2:3});grid on;xticks(1:height(summary));xticklabels(names);xtickangle(20);
ylabel('Threshold delay (ns)');legend('10%','50%','Location','northwest');title('Input A to output B: threshold delays');
nexttile;bar(summary{:,5:6});grid on;xticks(1:height(summary));xticklabels(names);xtickangle(20);
ylabel('First downward -45 deg frequency (MHz)');legend('10% correction','50% correction','Location','northwest');
title('Corrected phase bandwidth');subtitle('Missing bars: no downward -45 deg crossing in measured range');
exportgraphics(f,fullfile(out,'batch_comparison.png'),'Resolution',180);savefig(f,fullfile(out,'batch_comparison.fig'));close(f);
% Keep the line reference separate: its scope waveform has not been converted.
line=read_bode3(fullfile(folder,'line.bode3'));writetable(line,fullfile(out,'line_bode_response.csv'));
writeReport(out,summary,allResults,line);
disp(summary);
end

function writeReport(out,s,allResults,line)
fid=fopen(fullfile(out,'相移带宽分析报告.md'),'w','n','UTF-8');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'# 相移带宽：7 条路径延迟与校正相位分析报告\n\n');
fprintf(fid,'本报告由 MATLAB 批量生成，输入为同名配对的 7 个 PicoScope MAT 和 7 个 Bode100 `.bode3`。所有路径统一按 **A（通道 1）输入、B（通道 2）输出**计算；文件名作为路径标签，未依据数值重新交换配对。实际接线与两次测量设置仍需一致。\n\n');
fprintf(fid,'## 1. 延迟与带宽汇总\n\n');
fprintf(fid,'| 路径 | 10%%延迟/ns | 50%%延迟/ns | 差值/ns | 10%%校正后−45°/MHz | 50%%校正后−45°/MHz | 幅值−3dB/MHz |\n|---|---:|---:|---:|---:|---:|---:|\n');
for k=1:height(s)
    fprintf(fid,'| %s | %.2f | %.2f | %.2f | %s | %s | %s |\n',s.Path(k),s.Delay10_ns(k),s.Delay50_ns(k),s.Difference_ns(k),num(s.Phase45_10_MHz(k)),num(s.Phase45_50_MHz(k)),num(s.Magnitude3dB_MHz(k)));
end
fprintf(fid,'\n“未观测到”表示扫描范围内没有从大于 −45° 向小于或等于 −45° 的交点，不表示无穷带宽，也不作频段外外推。这里的相位带宽是**给定延迟校正下首次下降至 −45° 的频率**，与幅值下降 3 dB 的带宽是不同指标。\n\n![延迟与校正相位带宽对比](batch_comparison.png)\n\n');
fprintf(fid,'## 2. 幅频及相位结果\n\n| 路径 | 低频增益/dB | 扫描上限/MHz | 上限原始相位/° | 上限10%%校正/° | 上限50%%校正/° |\n|---|---:|---:|---:|---:|---:|\n');
for k=1:height(s)
    fprintf(fid,'| %s | %.3f | %.3g | %.2f | %.2f | %.2f |\n',s.Path(k),s.LowFrequencyGain_dB(k),s.EndFrequency_MHz(k),s.EndMeasuredPhase_deg(k),s.EndPhase10_deg(k),s.EndPhase50_deg(k));
end
fprintf(fid,'\n低频增益取不高于 1 kHz 的幅值中位数。幅值 −3 dB 频率以该值减 3 dB 为目标，在相邻实测点间按对数频率插值。它是扫频网格下的估计，不是额外测得的精确截止点。\n\n');
fprintf(fid,'## 3. 计算方法\n\n');
fprintf(fid,'每个示波器记录均使用全记录首尾各 15%% 样本中位数估计各自稳态平台，不做平滑。归一化定义为 $u=(V-V_0)/(V_1-V_0)$；10%%、50%% 是各通道自身阶跃幅度的比例，不共用同一个电压阈值，也不以过冲峰值为 100%%。阈值到达时间采用相邻采样点线性插值，延迟为 $\\tau_q=t_{B,q}-t_{A,q}$。\n\n');
fprintf(fid,'Bode3 中读取 `TraceValues.xml` 的 `GainPhase` 复数 `Result`，由 $20\\log_{10}|H|$ 和展开后的 $\\arg H$ 恢复幅值及连续相位。与此前 JG22–JG18 官方导出 CSV 的核对：幅值最大差约 $3.6\\times10^{-15}$ dB，相位最大差约 $3.4\\times10^{-13}$ 度，频率一致。此读取器针对本批文件的保存格式。\n\n');
fprintf(fid,'扣除延迟使用：\n\n$$\\phi_{q,\\mathrm{corr}}(f)=\\phi_{\\mathrm{meas}}(f)+360f\\tau_q.$$\n\n频率用 Hz，延迟用秒，相位用度。理想纯延迟幅值为 1，扣除后幅频曲线不变。原始幅频/相频和校正结果均使用同一张左右双纵轴图，图中标注 −45° 水平线及每种校正的首次下降交点。若有多个交点，`phase45_summary.csv` 同时记录下降交点数量。\n\n');
fprintf(fid,'相位 −45° 交点在相邻点之间假设相位对 $\\log_{10}f$ 线性，插值得到频率。图中标注数值保留约四位有效数字，不代表仪器准确度达到该位数。\n\n');
fprintf(fid,'## 4. 如何理解差异\n\n');
fprintf(fid,'- 所有路径的 50%% 延迟都比 10%% 延迟长，差值来自输出边沿在 10%%→50%% 区间相对输入变缓，不能直接解释为额外一段固定传输延迟。\n');
fprintf(fid,'- 50%% 延迟校正会比 10%% 多加回 $360f(\\tau_{50}-\\tau_{10})$ 的相位，因此其校正相位总是更高，−45° 交点通常移向高频或不再出现在扫描范围内。\n');
fprintf(fid,'- 校正相位变正不表示原始设备让信号提前到达，而是采用的常数延迟已加回超过该频率总相位滞后的量。不能把任一种剩余相位直接认定为滤波器单独的相移。\n');
fprintf(fid,'- 阈值延迟包含边沿形状、滤波和测量链路影响。没有明确滤波器模型与参考面校准时，不能唯一分离纯传输延迟与滤波器相移；不能仅按“校正后最接近零”选择真实延迟。\n');
fprintf(fid,'- 路径间延迟或相位差异也可能与测量时的配置、配线和输入幅度有关。本报告保留文件配对，未执行文件夹内配置硬件的 `.tcl` 脚本。\n\n');
fprintf(fid,'## 5. line 参考文件与不确定度\n\n');
fprintf(fid,'目录另有 `line.bode3` 和 `line.psdata`，但没有 `line.mat`。已提取线缆频响到 `line_bode_response.csv`：扫描上限 %.4g MHz 处幅值 %.4f dB，相位 %.4f°，对应相位延迟约 %.3f ns。此值由频响相位推算，不是示波器阈值延迟。\n\n',line.Frequency_Hz(end)/1e6,line.Magnitude_dB(end),line.Phase_deg(end),-line.Phase_deg(end)/(360*line.Frequency_Hz(end))*1e9);
fprintf(fid,'**本批结果没有减去 line 参考。** 在未确认 line 是否对应同一参考面、线缆与配置，以及频响是否已作补偿前，直接扣除可能重复校正。line 的 10%%/50%% 延迟仍需对应 MAT；不以频域相位延迟代替。\n\n');
fprintf(fid,'有限采样间隔、插值、噪声、探头通道偏斜和平台选择都会影响结果。此次每条路径仅分析一个已导出的记录，没有重复采集建立置信区间；两种阈值之差不是统计误差条。相位对延迟误差很敏感，例如 10 MHz 处 1 ns 会产生 3.6° 校正差。\n\n');
fprintf(fid,'## 6. 各路径结果与图\n\n');
for k=1:height(s)
    r=allResults{k};d=r.waveform;
    fprintf(fid,'### %s\n\n',s.Path(k));
    fprintf(fid,'实际样本数 %d，采样间隔 %.4g ns。输入平台 %.5f → %.5f，输出平台 %.5f → %.5f（MAT 导出电压值）。\n\n',numel(d.t),d.sampleInterval_s*1e9,d.inputLevels,d.outputLevels);
    fprintf(fid,'| 阈值 | 输入时刻/ns | 输出时刻/ns | 延迟/ns | 校正后−45°/MHz |\n|---|---:|---:|---:|---:|\n');
    for j=1:2
        fprintf(fid,'| %d%% | %.3f | %.3f | %.3f | %s |\n',r.delay.Threshold_percent(j),r.delay.Input_crossing_s(j)*1e9,r.delay.Output_crossing_s(j)*1e9,r.delay.Delay_ns(j),num(r.phase45.First_downward_minus45_Hz(j)/1e6));
    end
    fprintf(fid,'\n![%s 校正相位与幅值（放大相位刻度）](%s/corrected_bandwidth.png)\n\n[原始与校正相位完整对比](%s/phase_corrected.png)\n\n![%s 阈值延迟](%s/scope_delay.png)\n\n',s.Path(k),s.Path(k),s.Path(k),s.Path(k),s.Path(k));
end
fprintf(fid,'## 7. 复现与输出文件\n\n在 MATLAB 中将 `Phase_delay` 设为当前文件夹，运行：\n\n```matlab\nsummary = run_bandwidth_batch;\n```\n\n');
fprintf(fid,'每条路径的子目录包含原始 Bode 图、波形延迟图、标注 −45° 频率的校正图（PNG/FIG）、原始/校正 CSV、阈值表、−45° 交点表、`analysis.mat` 和 `bode_extracted.mat`。总目录包含 `batch_summary.csv`、`batch_analysis.mat` 和对比图。NaN 表示未观测到交点；原始文件不被修改。重复运行会更新同名结果及本报告。\n');
end

function value=num(x)
if isnan(x),value='未观测到';else,value=sprintf('%.4f',x);end
end

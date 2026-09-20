function sheets = buildSummarySheets(folder, config)
%BUILDSUMMARYSHEETS Select report-facing values; never recompute core metrics.
note = conditionNote(config);
sheets = struct('name',{},'title',{},'note',{},'headers',{},'data',{});
if exists(folder,'ADC_vpp_codepp_summary.csv')
    t=read(folder,'ADC_vpp_codepp_summary.csv');
    [~,idx]=unique(string(t.Channel),'stable'); t1=t(idx,:);
    sheets(1)=make('刻度',note,{'接口','输入频率（Hz）','斜率k（Vpp/CodePp）','截距b（Vpp）','R²','状态/备注'}, ...
        columns(t1,{'Channel','ExpectedFrequencyHz','SlopeVppPerCodePp','InterceptVpp','CalibrationR2','Conclusion'}));
    sheets(1).note=[note '；Vpp=k×CodePp+b；详细有效点及排除原因见evidence。'];
    c=read(folder,'ADC_critical_input_estimate.csv');
    data=columns(c,{'Channel','LastUnclippedInputVpp','FirstClippedInputVpp','CriticalInputVpp','CriticalInputDbm','Status'});
    range=cell(height(c),1);
    for k=1:height(c)
        mask=string(t.Channel)==string(c.Channel(k));
        v=t.InputVoltageVpp(mask); range{k}=sprintf('%.6g～%.6g',min(v),max(v));
        data{k,6}=strrep(strrep(char(string(data{k,6})),'unbracketed_extrapolation','未括住临界点，外推'), 'bracketed_estimate','夹逼范围内估计');
    end
    sheets(2)=make('动态范围',note,{'接口','扫描范围（Vpp）','最高未削顶（Vpp）','首次削顶（Vpp）','99%临界输入（Vpp）','99%临界输入（dBm）','状态/备注'},[data(:,1) range data(:,2:end)]);
elseif exists(folder,'dac_scale_summary.csv')
    t=read(folder,'dac_scale_summary.csv'); m=read(folder,'dac_scale_measurements.csv');
    data=columns(t,{'device','slope_v_per_code_vpp','intercept_v','fit_r_squared','formal_conclusion'});
    data(:,1)={interfaceLabel(config,m)};
    data=[data(:,1) repmat({field(config,'toneFrequencyHz',NaN)},height(t),1) repmat({max(m.output_vpp_v)},height(t),1) data(:,2:end)];
    sheets=make('刻度', [note '；Vpp=k×码幅+b；码幅定义：' char(field(config,'codeVppDefinition','未记录'))], ...
        {'接口','输出频率（Hz）','最大实测Vpp（V）','斜率k（V/码幅）','截距b（V）','R²','状态/备注'},data);
elseif exists(folder,'ADC_bandwidth_summary.csv')
    t=read(folder,'ADC_bandwidth_summary.csv');
    factor=field(config,'bandwidthScaleFactor',1);
    measured=t.Bandwidth3dBHz(1)/factor;
    d={interfaceLabel(config,t),sprintf('%.6g～%.6g',min(t.FileFrequencyHz),max(t.FileFrequencyHz)),measured,char(string(t.CoverageStatus(1)))};
    if ~isfinite(measured), d{end}=[d{end} '；有效点未形成可靠−3 dB交点']; end
    d{end}=[d{end} '；暂不能判定'];
    headers={'接口','扫频范围（Hz）','实测−3 dB带宽（Hz）','状态/备注'};
    if strcmpi(field(config,'deviceId',''),'AD2208')
        headers=[headers(1:3) {'30 MHz相对幅度（dB）','80 MHz文件点相对幅度（dB）','80 MHz点拟合频率（Hz）'} headers(4)];
        d=[d(1:3) {atFrequency(t,30e6,'RelativeDb'),atFrequency(t,80e6,'RelativeDb'),atFrequency(t,80e6,'FitFrequencyHz')} d(4)];
    elseif factor~=1 || contains(upper(char(field(config,'deviceId',''))),'128')
        headers=[headers(1:3) {'板级换算带宽（Hz）','换算系数'} headers(4)];
        converted=NaN; if factor~=1, converted=t.Bandwidth3dBHz(1); end
        d=[d(1:3) {converted,factor} d(4)];
    end
    sheets=make('带宽',[note '；无可靠交点时留空；换算值与实测值分开。'],headers,d);
elseif exists(folder,'ADC_SFDR_summary.csv')
    t=read(folder,'ADC_SFDR_summary.csv');
    data=columns(t,{'FileName','FundamentalFrequencyHz','SFDR'});
    headers={'接口/文件','分析基波频率（Hz）','SFDR（dB）'};
    if strcmpi(field(config,'deviceId',''),'AD9245')
        data=[data columns(t,{'SNR','SINAD','THD','ENOB'})];
        headers=[headers {'SNR（dB）','SINAD（dB）','THD（dB）','ENOB（bit）'}];
    end
    sheets=make('SFDR',[note '；THD=10log10(谐波功率/基波功率)；正式结论需核对测量条件。'],headers,data);
elseif exists(folder,'ADC_inl_dnl_summary.csv')
    t=read(folder,'ADC_inl_dnl_summary.csv');
    sheets=make('INL_DNL',[note '；部分码域正弦码密度；INL为best-fit；统计覆盖不足不可用于验收。'], ...
        {'接口','拟合输入频率（Hz）','最大绝对INL（LSB）','最大绝对DNL（LSB）','状态/备注'}, ...
        columns(t,{'Channel','FrequencyHz','MaxAbsINL_LSB','MaxAbsDNL_LSB','Status'}));
elseif exists(folder,'ADC_isolation_summary.csv')
    t=read(folder,'ADC_isolation_summary.csv');
    sheets=isolationSheets(t,'DrivenChannel','QuietChannel','IsolationDb','ExpectedFrequencyHz',note);
elseif exists(folder,'dac_isolation_summary.csv')
    t=read(folder,'dac_isolation_summary.csv');
    sheets=isolationSheets(t,'driven_label','victim_label','isolation_db','frequency_hz',note);
elseif exists(folder,'dac_noise_summary.csv')
    t=read(folder,'dac_noise_summary.csv');
    data=columns(t,{'input_file','sample_rate_hz','duration_s','welch_resolution_hz','asd_check_actual_hz','asd_at_1hz_uV_per_sqrtHz','integrated_noise_uVrms','formal_conclusion'});
    data(:,2)=num2cell(t.sample_rate_hz/1e3);
    band=field(config,'integratedBandHz',[NaN NaN]);
    sheets=make('输出噪声',note,{'接口/文件','采样率（kS/s）','时长（s）','频点间隔（Hz）','1 Hz附近实际频点（Hz）','ASD（μV/√Hz）',sprintf('%.6g～%.6g Hz积分噪声（μVrms）',band(1),band(2)),'状态/备注'},data);
elseif exists(folder,'input_equiv_noise_summary.csv')
    t=read(folder,'input_equiv_noise_summary.csv');
    data=columns(t,{'interface','sample_rate_hz','duration_s','frequency_resolution_hz','asd_check_actual_hz','input_asd_at_check_n_v_per_sqrt_hz','formal_state'});
    data(:,2)=num2cell(t.sample_rate_hz/1e3); data(:,6)=num2cell(t.input_asd_at_check_n_v_per_sqrt_hz/1e3);
    sheets=make('输入等效噪声',[note '；未扣PICO/DAC本底。'],{'接口','采样率（kS/s）','时长（s）','频点间隔（Hz）','1 Hz附近实际频点（Hz）','ASD（μV/√Hz）','状态/备注'},data);
else
    matches=dir(fullfile(folder,'*_input_noise_summary.csv'));
    if ~isempty(matches)
        t=read(folder,matches(1).name);
        data=columns(t,{'Channel','BandStartHz','BandEndHz','BandAsdMedianNvPerSqrtHz','BandAsdP95NvPerSqrtHz','BandAsdMaxNvPerSqrtHz','BandAsdMaxFrequencyHz','FormalStatus'});
        sheets=make('ILA输入噪声',note,{'接口','频带下限（Hz）','频带上限（Hz）','中位ASD（nV/√Hz）','95%分位ASD（nV/√Hz）','最大ASD（nV/√Hz）','最大值频率（Hz）','状态/备注'},data);
    end
end
if isempty(sheets)
    error('converter:report:SummaryMissing','未找到支持的指标汇总：%s',folder);
end
end

function sheets=isolationSheets(t,drive,victim,value,freq,note)
% Accept the established DAC output field spelling across versions.
if height(t)==0 || ~ismember(value,t.Properties.VariableNames)
    sheets=make('隔离度', [note '；没有提供有效驱动/受扰配对。'], ...
        {'驱动/受扰','最差隔离度（dB）','状态/备注'}, ...
        {'',NaN,'未测试：没有配对清单'});
    return;
end
if ~ismember(drive,t.Properties.VariableNames), drive='driven_channel'; end
if ~ismember(victim,t.Properties.VariableNames), victim='victim_channel'; end
if ~ismember(freq,t.Properties.VariableNames), freq='tone_frequency_hz'; end
if ~ismember(freq,t.Properties.VariableNames), t.(freq)=NaN(height(t),1); end
frequencies=unique(t.(freq)); sheets=struct('name',{},'title',{},'note',{},'headers',{},'data',{});
for k=1:numel(frequencies)
    mask=t.(freq)==frequencies(k); if isnan(frequencies(k)), mask=isnan(t.(freq)); end
    rows=t(mask,:); drives=unique(string(rows.(drive)),'stable');
    labels=unique([string(rows.(drive));string(rows.(victim))],'stable');
    data=cell(numel(drives),numel(labels)+3);
    for r=1:numel(drives)
        data{r,1}=char(drives(r)); vals=[];
        for c=1:numel(labels)
            match=string(rows.(drive))==drives(r) & string(rows.(victim))==labels(c);
            if labels(c)==drives(r), data{r,c+1}='—';
            elseif any(match)
                v=rows.(value)(match); data{r,c+1}=min(v); vals=[vals;v(:)]; %#ok<AGROW>
            end
        end
        finiteVals=vals(isfinite(vals)); if ~isempty(finiteVals), data{r,end-1}=min(finiteVals); end
        data{r,end}='未测组合留空；参考面/噪声底未确认时暂不能判定';
    end
    name=sprintf('隔离度_%d',k);
    sheets(k)=make(name,sprintf('%s；驱动频率 %.9g Hz；矩阵单位dB。',note,frequencies(k)), ...
        [{'驱动/受扰'} cellstr(labels(:).') {'最差隔离度（dB）','状态/备注'}],data);
end
end

function s=make(name,note,headers,data)
s=struct('name',name,'title',name,'note',note,'headers',{headers},'data',{data});
end
function cells=columns(t,names)
cells=cell(height(t),numel(names));
for k=1:numel(names)
    if ~ismember(names{k},t.Properties.VariableNames)
        error('converter:report:SummaryColumnMissing', ...
            '汇总缺少字段%s；拒绝用空白掩盖导出错误。',names{k});
    end
    v=t.(names{k});
    if iscell(v), cells(:,k)=v; elseif isstring(v) || iscategorical(v), cells(:,k)=cellstr(string(v));
    elseif isnumeric(v) || islogical(v), cells(:,k)=num2cell(v); else, cells(:,k)=cellstr(string(v)); end
end
end
function t=read(folder,name)
t=readtable(fullfile(folder,name),'Delimiter',',','TextType','string');
end
function tf=exists(folder,name)
tf=isfile(fullfile(folder,name));
end
function v=field(s,name,fallback)
if isfield(s,name) && ~isempty(s.(name)), v=s.(name); else, v=fallback; end
end
function note=conditionNote(config)
note=sprintf('%s；%s',char(field(config,'deviceId','')),char(field(config,'referencePlane','参考面未记录')));
if isfield(config,'hardwareGain'), note=[note sprintf('；电压增益 %.9g',config.hardwareGain)]; end
if isfield(config,'fpgaGain'), note=[note sprintf('；FPGA增益 %.9g',config.fpgaGain)]; end
note=[note '；空白=未测或不可计算，完整依据见evidence。'];
end
function label=interfaceLabel(config,t)
label=char(field(config,'deviceId','未指定'));
if ismember('Channel',t.Properties.VariableNames) && height(t)>0
    label=char(string(t.Channel(1))); return;
end
if isfield(config,'dataFolder') && ~isempty(config.dataFolder)
    [~,name]=fileparts(config.dataFolder); label=[label ' / ' name];
elseif ismember('FileName',t.Properties.VariableNames) && height(t)>0
    label=[label ' / ' char(string(t.FileName(1)))];
end
end
function value=atFrequency(t,freq,column)
value=NaN;
idx=find(abs(t.FileFrequencyHz-freq)<=max(1,abs(freq))*1e-9,1);
if ~isempty(idx) && ismember(column,t.Properties.VariableNames), value=t.(column)(idx); end
end

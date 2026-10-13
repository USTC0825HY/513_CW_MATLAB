function [config, rows, cancelled] = resolveNoiseCalibration(config, device, channels, interactive, pico)
%RESOLVENOISECALIBRATION Resolve calibration before creating any output.
% Report-backed PICO pairs the ADC with the same board's DA9726 JG18.
cancelled = false;
rows = struct([]);
adcFields = {'reportCalibration','noiseCalibration','adcCalibrationRows','calibrationWorkbook'};
present = adcFields(cellfun(@(n) hasValue(config,n),adcFields));
dacFields = {'kDacVPerCodePp','dacSummaryPath'};
dacPresent = dacFields(cellfun(@(n) hasValue(config,n),dacFields));
if numel(present)>1 || numel(dacPresent)>1
    error('converter:calibration:ConflictingSources','刻度来源冲突：%s。每端只提供一种来源。',strjoin([present dacPresent],', '));
end
if isfield(config,'calibrationSelection')
    rows=config.calibrationSelection.adc;
    expected=coreRows(rows);
    consistent=all(strcmp({rows.device},device)) && ...
        isequal(sort(string({rows.channel})),sort(reshape(string(channels),1,[])));
    if pico
        consistent=consistent && isequaln(config.adcCalibrationRows,expected) && ...
            config.kDacVPerCodePp==config.calibrationSelection.dac.slopeVPerCode;
    else
        consistent=consistent && isequaln(config.noiseCalibration,rows);
    end
    if strcmp(config.calibrationSelection.sourceType,'report_table')
        consistent=consistent && all(strcmp({rows.boardType},config.boardType)) && ...
            strcmp(config.calibrationSelection.requestedState,config.calibrationState);
    end
    if ~consistent
        error('converter:calibration:ReplayMismatch', ...
            '保存的刻度记录与当前参数不一致。重新选择板型时请只传板型、版本及本次分析参数。');
    end
    return;
end
if isempty(present)
    if ~isempty(dacPresent)
        error('converter:calibration:ConflictingSources', ...
            '内置 ADC 刻度配套使用同板 DA9726；自定义 DAC 时请同时指定自定义 ADC 刻度。');
    end
    if ~hasValue(config,'boardType')
        if ~interactive
            error('converter:calibration:BoardRequired', ...
                '参数调用请设置 options.boardType=''jianding'' 或 ''jiaqiang''，例如 struct(''boardType'',''jianding'')。');
        end
        [index,ok] = listdlg('ListString',{'鉴定件','电性加强件'}, ...
            'SelectionMode','single','PromptString','选择本次数据的板型');
        if ~ok, cancelled=true; return; end
        boards = {'jianding','jiaqiang'};
        config.boardType = boards{index};
    end
    if ~hasValue(config,'calibrationState'), config.calibrationState='current'; end
    config.boardType=validatestring(config.boardType,{'jianding','jiaqiang'});
    config.calibrationState=validatestring(config.calibrationState,{'current','before','after'});
    rows = converter.calibration.reportCalibration(device,config.boardType,config.calibrationState,channels);
    sourceType = 'report_table';
    if pico
        % State selection concerns the ADC; JG18 keeps its own unique state.
        dac = converter.calibration.reportCalibration('DA9726',config.boardType,'current',{'DAC1_JG18'});
        config.kDacVPerCodePp = dac.slopeVPerCode;
        config.dacCalibrationSource = dac.sourceDocument;
    else
        dac = struct([]);
    end
else
    sourceType = 'user_calibration';
    source = present{1};
    if strcmp(source,'calibrationWorkbook')
        custom = converter.calibration.loadAdcCalibration(config.calibrationWorkbook);
    else
        custom = config.(source);
    end
    rows = normalizeCustom(custom,device,channels);
    if pico
        if isempty(dacPresent)
            error('converter:calibration:CustomDacRequired', ...
                '自定义 PICO 刻度请同时设置 kDacVPerCodePp 或 dacSummaryPath。');
        end
        if strcmp(dacPresent{1},'dacSummaryPath')
            t = readtable(config.dacSummaryPath,'TextType','string');
            if height(t)~=1,error('converter:calibration:AmbiguousDac','DAC 刻度 CSV 必须明确为一条 JG18 记录。');end
            config.kDacVPerCodePp = t.slope_v_per_code_vpp(1);
        end
        validateattributes(config.kDacVPerCodePp,{'numeric'},{'scalar','real','finite','positive'});
        dac = struct('sourceType','user_calibration','slopeVPerCode',config.kDacVPerCodePp);
        if hasValue(config,'dacSummaryPath')
            dac.sourcePath = config.dacSummaryPath;
            dac.sourceSha256 = converter.runtime.sha256File(config.dacSummaryPath);
            if ismember('intercept_v',t.Properties.VariableNames),dac.interceptV=t.intercept_v(1);end
            if ismember('fit_r_squared',t.Properties.VariableNames),dac.fitR2=t.fit_r_squared(1);end
        end
        config.dacCalibrationSource = '用户指定刻度';
    else
        if ~isempty(dacPresent),error('converter:calibration:UnusedDac','ILA 换算只需要 ADC 刻度。');end
        dac=struct([]);
    end
    if hasValue(config,'calibrationWorkbook')
        for k=1:numel(rows)
            rows(k).sourceDocument=config.calibrationWorkbook;
            rows(k).sourceDocumentSha256=converter.runtime.sha256File(config.calibrationWorkbook);
        end
    end
end
config.calibrationSelection=struct('sourceType',sourceType,'adc',rows,'dac',dac);
if strcmp(sourceType,'report_table')
    config.calibrationSelection.requestedState=config.calibrationState;
    catalogPath=fullfile(fileparts(mfilename('fullpath')),'report_calibrations_20261004.csv');
    config.calibrationSelection.catalogSha256=converter.runtime.sha256File(catalogPath);
else
    config.calibrationSelection.userSourceField=source;
    config.calibrationSelection.userProvidedRows=custom;
end
% Normalize aliases to one consumer field. Full source records stay above.
for k=1:numel(adcFields)
    if isfield(config,adcFields{k}),config=rmfield(config,adcFields{k});end
end
if pico
    config.adcCalibrationRows=coreRows(rows);
    config.adcCalibrationSource=rows(1).sourceDocument;
    config.calibrationWorkbook='';
    if isfield(config,'dacSummaryPath'),config=rmfield(config,'dacSummaryPath');end
else
    config.noiseCalibration=rows;
end
config.calibrationSource=sourceType;
config.calibrationSourceSha256=rows(1).sourceDocumentSha256;
if ~pico,config.noiseCalibrationSource=sourceType;end
if ~isfield(config,'parameterSources'),config.parameterSources=struct();end
config.parameterSources.calibrationSelection=sourceType;
if pico
    config.parameterSources.adcCalibrationRows=sourceType;
    config.parameterSources.kDacVPerCodePp=sourceType;
else
    config.parameterSources.noiseCalibration=sourceType;
end
for k=1:numel(rows)
    fprintf('刻度：%s / %s / %s / %s；k=%.12g V/code\n', ...
        rows(k).boardType,device,rows(k).channel,rows(k).calibrationState,rows(k).slopeVPerCode);
end
if pico,fprintf('DA9726 JG18：k=%.12g V/code；%s\n',config.kDacVPerCodePp,config.dacCalibrationSource);end
end

function yes=hasValue(s,name)
yes=isfield(s,name) && ~isempty(s.(name));
if yes && (ischar(s.(name)) || isstring(s.(name))),yes=all(strlength(string(s.(name)))>0);end
end

function rows=normalizeCustom(custom,device,channels)
if ~isstruct(custom),error('converter:calibration:InvalidCustom','自定义刻度必须是结构体数组。');end
channels=cellstr(string(channels));
template=struct('device',device,'channel','','slopeVPerCode',NaN, ...
    'interceptV',NaN,'fitR2',NaN,'calibrationFrequencyHz',NaN,'pointCount',NaN, ...
    'sourceDocument','用户指定刻度','sourceDocumentSha256','','sourceSection','用户指定刻度', ...
    'boardType','user','calibrationState','user','unit','V/code');
rows=repmat(template,numel(channels),1);
for k=1:numel(channels)
    if isfield(custom,'channel'),names={custom.channel};else,names={custom.interface};end
    match=strcmp(names,channels{k});
    if isfield(custom,'device'),match=match & strcmp({custom.device},device);end
    if nnz(match)~=1,error('converter:calibration:InvalidCustom','%s/%s 自定义刻度必须唯一匹配。',device,channels{k});end
    c=custom(match);rows(k).channel=channels{k};
    if isfield(c,'slopeVPerCode')
        rows(k).slopeVPerCode=c.slopeVPerCode;
        pairs={'interceptV','interceptV';'fitR2','fitR2';'calibrationFrequencyHz','calibrationFrequencyHz';'pointCount','pointCount'};
    else
        rows(k).slopeVPerCode=c.slope;
        pairs={'intercept','interceptV';'r2','fitR2'};
    end
    for j=1:size(pairs,1),if isfield(c,pairs{j,1}),rows(k).(pairs{j,2})=c.(pairs{j,1});end,end
    validateattributes(rows(k).slopeVPerCode,{'numeric'},{'scalar','real','finite','positive'});
end
end

function out=coreRows(rows)
out=repmat(struct('device','','interface','','slope',NaN,'intercept',NaN,'r2',NaN,'dataGroup',''),numel(rows),1);
for k=1:numel(rows)
    c=rows(k);out(k)=struct('device',c.device,'interface',c.channel,'slope',c.slopeVPerCode, ...
        'intercept',c.interceptV,'r2',c.fitR2,'dataGroup',[c.boardType '/' c.calibrationState ' / ' c.sourceDocument]);
end
end

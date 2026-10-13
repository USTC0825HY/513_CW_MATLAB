function rows = reportCalibration(device, boardType, calibrationState, channels)
%REPORTCALIBRATION Select by board, device, interface and rework state.
% rows = converter.calibration.reportCalibration('AD2208','jianding', ...
%     'current', {'ADC6_JG24'});
% current chooses after if present, otherwise the unique unchanged record.
if nargin < 2 || strlength(string(boardType)) == 0
    error('converter:calibration:BoardRequired','内置刻度需要 boardType=''jianding'' 或 ''jiaqiang''。');
end
boardType = validatestring(boardType, {'jianding','jiaqiang'});
if nargin < 3 || isempty(calibrationState), calibrationState = 'current'; end
calibrationState = validatestring(calibrationState, {'current','before','after'});
catalog = converter.calibration.calibrationCatalog();
catalog = catalog(strcmp({catalog.device},device) & strcmp({catalog.boardType},boardType));
if isempty(catalog), error('converter:calibration:UnknownDevice','没有 %s/%s 刻度。',boardType,device); end
if nargin < 4 || isempty(channels), channels = unique({catalog.channel},'stable'); end
channels = cellstr(string(channels));
rows = catalog([]);
for k = 1:numel(channels)
    candidates = catalog(strcmp({catalog.channel},channels{k}));
    if strcmp(calibrationState,'current')
        if any(strcmp({candidates.calibrationState},'after'))
            selected = candidates(strcmp({candidates.calibrationState},'after'));
        else
            selected = candidates;
        end
    else
        selected = candidates(strcmp({candidates.calibrationState},calibrationState));
    end
    if numel(selected) ~= 1
        error('converter:calibration:StateUnavailable', ...
            '%s/%s/%s 请求 %s；可用版本：%s。',boardType,device,channels{k}, ...
            calibrationState,strjoin({candidates.calibrationState},', '));
    end
    validateattributes(selected.slopeVPerCode,{'numeric'},{'scalar','real','finite','positive'});
    rows(end+1,1) = selected; %#ok<AGROW>
end
end

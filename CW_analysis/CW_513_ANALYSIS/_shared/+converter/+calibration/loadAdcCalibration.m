function [rows, sourceType] = loadAdcCalibration(sourcePath)
%LOADADCCALIBRATION Read bundled report values or an explicit legacy workbook.
bundledPath = which('converter.calibration.reportCalibration');
rows = struct('device',{},'interface',{},'slope',{}, ...
    'intercept',{},'r2',{},'dataGroup',{});
if strcmpi(char(java.io.File(char(sourcePath)).getCanonicalPath()), ...
        char(java.io.File(bundledPath).getCanonicalPath()))
    sourceType = 'calibration_configuration';
    catalog = converter.calibration.reportCalibration();
    catalog = catalog(ismember({catalog.device},{'AD2208','AD9245','AD677'}));
    for k = 1:numel(catalog)
        c = catalog(k);
        rows(end+1) = struct('device',c.device,'interface',c.channel, ...
            'slope',c.slopeVPerCode,'intercept',c.interceptV,'r2',c.fitR2, ...
            'dataGroup',[c.sourceDocument ' / ' c.sourceSection]); %#ok<AGROW>
    end
else
    sourceType = 'calibration_workbook';
    if ~isfile(sourcePath)
        error('cw513:CalibrationMissing','刻度文件不存在：%s',sourcePath);
    end
    cells = readcell(sourcePath,'Sheet','刻度参数');
    for k = 3:size(cells,1)
        if isempty(cells{k,1}) || isempty(cells{k,2}), continue; end
        rows(end+1) = struct('device',char(string(cells{k,1})), ...
            'interface',char(string(cells{k,2})),'slope',double(cells{k,4}), ...
            'intercept',double(cells{k,5}),'r2',double(cells{k,6}), ...
            'dataGroup',char(string(cells{k,3}))); %#ok<AGROW>
    end
end
end

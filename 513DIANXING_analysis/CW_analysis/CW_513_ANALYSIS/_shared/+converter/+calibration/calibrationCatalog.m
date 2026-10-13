function rows = calibrationCatalog()
%CALIBRATIONCATALOG Report-table records including historical rework states.
file = fullfile(fileparts(mfilename('fullpath')), 'report_calibrations_20261004.csv');
options = detectImportOptions(file, 'TextType','string', 'Encoding','UTF-8');
numericFields = {'slopeVPerCode','interceptV','fitR2','calibrationFrequencyHz', ...
    'pointCount','sourceTable','sourceRow'};
options = setvartype(options, numericFields, 'double');
options = setvartype(options, setdiff(options.VariableNames,numericFields), 'string');
t = readtable(file, options);
rows = table2struct(t);
names = t.Properties.VariableNames;
for k = 1:numel(rows)
    for j = 1:numel(names)
        value = rows(k).(names{j});
        if isstring(value)
            if ismissing(value), value = ""; end
            rows(k).(names{j}) = char(value);
        end
    end
end
end

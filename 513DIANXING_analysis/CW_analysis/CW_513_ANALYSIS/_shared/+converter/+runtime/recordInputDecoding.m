function recordInputDecoding(runFolder, metadata)
%RECORDINPUTDECODING Record the radix and coding used by the actual CSV read.
filePath = fullfile(runFolder, 'input_decoding.csv');
row = struct2table(metadata, 'AsArray', true);
names = row.Properties.VariableNames;
for k = 1:numel(names)
    if ischar(row.(names{k}))
        row.(names{k}) = string(row.(names{k}));
    end
end
if isfile(filePath)
    previous = readtable(filePath, 'Delimiter', ',', 'TextType', 'string');
    row = [previous; row];
end
converter.report.writeTable(row, filePath);
end

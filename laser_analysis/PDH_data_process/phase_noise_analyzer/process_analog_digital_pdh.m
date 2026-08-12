%% Load two exported data files
data_si1_prototype_20260624 = import_phase_noise_data();
if isempty(data_si1_prototype_20260624)
    disp('第一个文件未导入，处理已中止。');
    return;
end

data_analog_digital_pdh = import_phase_noise_data();
if isempty(data_analog_digital_pdh)
    disp('第二个文件未导入，处理已中止。');
    return;
end

% Add source prefixes so equal trace names remain individually selectable.
for traceIndex = 1:numel(data_si1_prototype_20260624)
    data_si1_prototype_20260624(traceIndex).TraceName = ...
        ['[电1腔 20260624] ', data_si1_prototype_20260624(traceIndex).TraceName];
end
for traceIndex = 1:numel(data_analog_digital_pdh)
    data_analog_digital_pdh(traceIndex).TraceName = ...
        ['[模数PDH] ', data_analog_digital_pdh(traceIndex).TraceName];
end

combined_data = {data_si1_prototype_20260624, data_analog_digital_pdh};
plot_phase_noise(combined_data, {});

%% Interactively select traces
all_trace_names = {};
for fileIndex = 1:numel(combined_data)
    currentFile = combined_data{fileIndex};
    all_trace_names = [all_trace_names, {currentFile.TraceName}]; %#ok<AGROW>
end

[indx, tf] = listdlg( ...
    'PromptString', {'请选择要在同一张图上对比的曲线', '(按住Ctrl或Shift可进行多选):'}, ...
    'SelectionMode', 'multiple', ...
    'ListString', all_trace_names, ...
    'Name', '选择要绘制的相噪数据', ...
    'ListSize', [360, 280]);

if tf == 1 && ~isempty(indx)
    plot_phase_noise(combined_data, all_trace_names(indx));
else
    disp('操作取消：未选择任何要绘制的数据。');
end

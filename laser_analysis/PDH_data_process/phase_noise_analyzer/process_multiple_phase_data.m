%% Load three exported data files
data_8cm = import_phase_noise_data();
if isempty(data_8cm)
    disp('8 cm腔数据未导入，处理已中止。');
    return;
end

data_si1_prototype_20260618 = import_phase_noise_data();
if isempty(data_si1_prototype_20260618)
    disp('电1腔 20260618数据未导入，处理已中止。');
    return;
end

data_si1_prototype_20260624 = import_phase_noise_data();
if isempty(data_si1_prototype_20260624)
    disp('电1腔 20260624数据未导入，处理已中止。');
    return;
end

datasets = {data_8cm, data_si1_prototype_20260618, data_si1_prototype_20260624};
prefixes = {'[8cm腔] ', '[电1腔 20260618] ', '[电1腔 20260624] '};
for fileIndex = 1:numel(datasets)
    for traceIndex = 1:numel(datasets{fileIndex})
        datasets{fileIndex}(traceIndex).TraceName = ...
            [prefixes{fileIndex}, datasets{fileIndex}(traceIndex).TraceName];
    end
end
combined_data = datasets;

plot_phase_noise(combined_data, {});

%% Interactively select traces
all_trace_names = {};
for fileIndex = 1:numel(combined_data)
    all_trace_names = [all_trace_names, {combined_data{fileIndex}.TraceName}]; %#ok<AGROW>
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

% Process 技物所激光器驱动板数据
%%Load data
data_jws = import_phase_noise_data();
if isempty(data_jws)
    disp('第一个文件未导入，处理已中止。');
    return;
end
 data_pinzhun = import_phase_noise_data();
if isempty(data_pinzhun)
    disp('第二个文件未导入，处理已中止。');
    return;
end

for traceIndex = 1:numel(data_jws)
    data_jws(traceIndex).TraceName = ...
        ['[8cm腔测试] ', data_jws(traceIndex).TraceName];
end

for traceIndex = 1:numel(data_pinzhun)
    data_pinzhun(traceIndex).TraceName = ...
        ['[8cm腔测试] ', data_pinzhun(traceIndex).TraceName];
end

combined_data = {data_jws, data_pinzhun};
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

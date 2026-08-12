function fig = plot_phase_noise(dataCellArray, targetNames)
    %PLOT_PHASE_NOISE Plot traces with unit-aware axis scaling.
    if nargin < 2
        targetNames = {};
    end
    if ~iscell(dataCellArray)
        error('PhaseNoise:InvalidInput', 'dataCellArray必须是结构体元胞数组。');
    end

    selected = struct('TraceName', {}, 'XData', {}, 'YData', {}, ...
        'XUnit', {}, 'YUnit', {}, 'SourceFile', {});
    for fileIndex = 1:numel(dataCellArray)
        currentFile = dataCellArray{fileIndex};
        for traceIndex = 1:numel(currentFile)
            if isempty(targetNames) || ismember(currentFile(traceIndex).TraceName, targetNames)
                selected(end + 1) = currentFile(traceIndex); %#ok<AGROW>
            end
        end
    end
    if isempty(selected)
        warning('PhaseNoise:NoMatchingTrace', '没有找到匹配的Trace名称。');
        fig = gobjects(0);
        return;
    end

    xUnits = unique({selected.XUnit});
    yUnits = unique({selected.YUnit});
    if numel(xUnits) ~= 1 || numel(yUnits) ~= 1
        error('PhaseNoise:MixedUnits', ...
            '不能在同一坐标轴比较不同单位的数据。X单位: %s；Y单位: %s', ...
            strjoin(xUnits, ', '), strjoin(yUnits, ', '));
    end
    xUnit = xUnits{1};
    yUnit = yUnits{1};
    isDb = contains(lower(yUnit), 'db');

    fig = figure('Name', 'PhaseNoiseComparison', 'Position', [100, 100, 900, 560]);
    ax = axes(fig);
    hold(ax, 'on');
    grid(ax, 'on');
    set(ax, 'XScale', 'log');
    if isDb
        set(ax, 'YScale', 'linear');
        graphTitle = '相位噪声对比';
    else
        set(ax, 'YScale', 'log');
        graphTitle = '频率噪声/稳定度对比';
    end

    legendLabels = cell(1, numel(selected));
    for traceIndex = 1:numel(selected)
        x = selected(traceIndex).XData;
        y = selected(traceIndex).YData;
        valid = isfinite(x) & isfinite(y) & x > 0;
        if ~isDb
            valid = valid & y > 0;
        end
        if ~any(valid)
            error('PhaseNoise:NoPlottableData', ...
                'Trace %s在当前坐标尺度下没有有效数据。', selected(traceIndex).TraceName);
        end
        plot(ax, x(valid), y(valid), 'LineWidth', 1.5);
        legendLabels{traceIndex} = selected(traceIndex).TraceName;
    end

    xlabel(ax, sprintf('Offset Frequency (%s)', xUnit), ...
        'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax, sprintf('Noise Spectrum (%s)', yUnit), ...
        'FontSize', 12, 'FontWeight', 'bold');
    title(ax, graphTitle, 'FontSize', 14);
    legend(ax, legendLabels, 'Location', 'best', 'FontSize', 10, 'Interpreter', 'none');
    hold(ax, 'off');
end

function dataStruct = import_phase_noise_data(filename)
    %IMPORT_PHASE_NOISE_DATA Import paired X/Y columns exported by Python.
    if nargin < 1 || isempty(filename)
        [file, path] = uigetfile('*.csv', '请选择相噪数据CSV文件');
        if isequal(file, 0)
            disp('操作取消：未选择任何文件。');
            dataStruct = struct([]);
            return;
        end
        filename = fullfile(path, file);
    end

    if ~isfile(filename)
        error('PhaseNoise:FileNotFound', '数据文件不存在: %s', filename);
    end

    dataTable = readtable(filename, 'VariableNamingRule', 'preserve');
    numCols = width(dataTable);
    if numCols == 0 || mod(numCols, 2) ~= 0
        error('PhaseNoise:InvalidColumns', ...
            'CSV必须由成对的X/Y列组成，当前列数为%d。', numCols);
    end

    dataStruct = struct('TraceName', {}, 'XData', {}, 'YData', {}, ...
        'XUnit', {}, 'YUnit', {}, 'SourceFile', {});
    sourceName = string(filename);

    for pairIndex = 1:(numCols / 2)
        xIndex = 2 * pairIndex - 1;
        yIndex = xIndex + 1;
        xCol = dataTable{:, xIndex};
        yCol = dataTable{:, yIndex};
        if ~isnumeric(xCol) || ~isnumeric(yCol)
            error('PhaseNoise:NonNumericData', ...
                '第%d/%d列必须是数值型X/Y数据。', xIndex, yIndex);
        end

        xHeader = dataTable.Properties.VariableNames{xIndex};
        yHeader = dataTable.Properties.VariableNames{yIndex};
        xTokens = regexp(xHeader, '^(.*?)_X\((.*?)\)$', 'tokens', 'once');
        yTokens = regexp(yHeader, '^(.*?)_Y\((.*?)\)$', 'tokens', 'once');
        if isempty(xTokens) || isempty(yTokens)
            error('PhaseNoise:InvalidHeader', ...
                '列名必须采用 Name_X(unit)/Name_Y(unit) 格式: %s, %s', xHeader, yHeader);
        end
        if ~strcmp(xTokens{1}, yTokens{1})
            error('PhaseNoise:MismatchedPair', ...
                'X/Y列名称不匹配: %s, %s', xHeader, yHeader);
        end

        traceName = xTokens{1};
        xUnit = xTokens{2};
        yUnit = yTokens{2};
        validIdx = isfinite(xCol) & isfinite(yCol) & xCol > 0;
        if contains(lower(strrep(yUnit, ' ', '')), 'sqrt')
            invalidY = yCol <= 0;
            if any(invalidY & isfinite(yCol))
                warning('PhaseNoise:InvalidASD', ...
                    '%s: %s包含%d个非正%s数据点，已剔除。', ...
                    filename, traceName, nnz(invalidY & isfinite(yCol)), yUnit);
            end
            validIdx = validIdx & ~invalidY;
        end
        if ~any(validIdx)
            error('PhaseNoise:NoValidData', '%s中Trace %s没有有效数据。', filename, traceName);
        end

        dataStruct(pairIndex).TraceName = traceName;
        dataStruct(pairIndex).XData = xCol(validIdx);
        dataStruct(pairIndex).YData = yCol(validIdx);
        dataStruct(pairIndex).XUnit = xUnit;
        dataStruct(pairIndex).YUnit = yUnit;
        dataStruct(pairIndex).SourceFile = sourceName;
    end
end

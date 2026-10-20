function response = cw513_platform_outputs(response,folder,result)
%CW513_PLATFORM_OUTPUTS Read actual result data and saved FIG graphics.
%   This output adapter contains no measurement formulas or pass criteria.
response.run_folder = folder;
response.final_config = localConfig(folder,result);
response.artifacts = localArtifacts(folder);
response.tables = localTables(folder,response.final_config,result);
response.plots = {};
response.status = 'success';
if isfile(converter.runtime.evidencePath(folder,'STATUS_PARTIAL.txt'))
    response.status = 'partial';
elseif isfile(converter.runtime.evidencePath(folder,'STATUS_FAILED.txt'))
    error('cw513:platform:AnalysisFailed', ...
        'The analysis saved STATUS_FAILED.txt. Review its run log: %s',folder);
end
figures = dir(fullfile(folder,'**','*.fig'));
for k = 1:numel(figures)
    file = fullfile(figures(k).folder,figures(k).name);
    try
        plots = localFigurePlots(file);
        response.plots = [response.plots plots];
    catch exception
        response.warnings{end+1} = sprintf('Interactive plot unavailable for %s: %s', ...
            figures(k).name,exception.message);
    end
end
if isempty(response.plots)
    response.warnings{end+1} = 'No supported numeric FIG graphics; view the saved PNG and numeric tables.';
end
end

function config = localConfig(folder,result)
config = struct();
if isstruct(result) && isscalar(result) && isfield(result,'config')
    config = result.config;
end
file = converter.runtime.evidencePath(folder,'run_config.mat');
if isfile(file)
    saved = load(file);
    if isfield(saved,'config'), config = saved.config;
    elseif isfield(saved,'options'), config = saved.options; end
end
end

function artifacts = localArtifacts(folder)
listing = dir(fullfile(folder,'**','*'));
listing = listing(~[listing.isdir]);
artifacts = cell(1,numel(listing));
for k = 1:numel(listing)
    [~,~,extension] = fileparts(listing(k).name);
    artifacts{k} = struct('name',listing(k).name, ...
        'path',fullfile(listing(k).folder,listing(k).name), ...
        'kind',lower(strrep(extension,'.','')),'size_bytes',listing(k).bytes);
end
end

function tables = localTables(folder,config,result)
tables = {};
evidence = fullfile(folder,'evidence');
if ~isfolder(evidence), evidence = folder; end
try
    sheets = converter.report.buildSummarySheets(evidence,config);
    for k = 1:numel(sheets)
        tables{end+1} = struct('name',sheets(k).name, ...
            'columns',{sheets(k).headers},'rows',{localRows(sheets(k).data)}, ...
            'note',sheets(k).note,'source_file',fullfile(folder,'结果汇总.xlsx')); %#ok<AGROW>
    end
catch exception
    if ~strcmp(exception.identifier,'converter:report:SummaryMissing'), rethrow(exception); end
    files = dir(fullfile(evidence,'*summary.csv'));
    for k = 1:numel(files)
        file = fullfile(files(k).folder,files(k).name);
        value = readtable(file,'TextType','string','VariableNamingRule','preserve');
        tables{end+1} = localTable(value,files(k).name,file); %#ok<AGROW>
    end
    if isempty(tables) && istable(result)
        tables = {localTable(result,'Analysis result','MATLAB public entry return value')};
    end
end
end

function value = localTable(t,name,source)
value = struct('name',name,'columns',{t.Properties.VariableNames}, ...
    'rows',{localRows(table2cell(t))},'note','','source_file',source);
end

function rows = localRows(data)
rows = cell(1,size(data,1));
for k = 1:size(data,1)
    row = data(k,:);
    for j = 1:numel(row)
        if isstring(row{j})
            if ismissing(row{j}), row{j} = []; else, row{j} = char(row{j}); end
        end
    end
    rows{k} = row;
end
end

function plots = localFigurePlots(file)
fig = openfig(file,'new','invisible');
cleanup = onCleanup(@() close(fig));
plots = {};
axesList = findall(fig,'Type','axes');
for k = numel(axesList):-1:1
    ax = axesList(k);
    if ismember(get(ax,'Tag'),{'legend','Colorbar'}), continue; end
    plot = struct('kind','line','title',localString(ax.Title.String), ...
        'x_label',localString(ax.XLabel.String),'y_label',localString(ax.YLabel.String), ...
        'x_scale',get(ax,'XScale'),'y_scale',get(ax,'YScale'), ...
        'series',{{}},'source_file',file,'display_only_decimation',false);
    if isempty(plot.title), [~,plot.title] = fileparts(file); end
    children = findall(ax);
    for j = numel(children):-1:1
        object = children(j);
        if ~isprop(object,'XData') || ~isprop(object,'YData'), continue; end
        if isprop(object,'CData') && strcmp(get(object,'Type'),'image')
            matrix = get(object,'CData');
            if ~isnumeric(matrix) || ~ismatrix(matrix), continue; end
            plot.kind = 'heatmap';
            plot.matrix = localMatrixRows(matrix);
            plot.row_labels = cellstr(string(get(ax,'YTickLabel'))).';
            plot.column_labels = cellstr(string(get(ax,'XTickLabel'))).';
            plot.clim = get(ax,'CLim');
            continue;
        end
        x = get(object,'XData'); y = get(object,'YData');
        if ~isnumeric(x) || ~isnumeric(y) || ~isreal(x) || ~isreal(y) || ...
                ~isvector(x) || ~isvector(y) || numel(x)~=numel(y) || isempty(x)
            continue;
        end
        style = 'line';
        if strcmp(get(object,'Type'),'scatter'), style = 'scatter'; end
        if ~ismember(get(object,'Type'),{'line','scatter','bar','stair'}), continue; end
        label = '';
        if isprop(object,'DisplayName'), label = get(object,'DisplayName'); end
        if isempty(label), label = sprintf('Curve %d',numel(plot.series)+1); end
        indices = localIndices(y,12000);
        plot.display_only_decimation = plot.display_only_decimation || numel(indices)<numel(y);
        plot.series{end+1} = struct('label',label,'name',label, ...
            'x',{num2cell(x(indices(:)).')},'y',{num2cell(y(indices(:)).')},'style',style);
    end
    if ~isempty(plot.series) || strcmp(plot.kind,'heatmap')
        plots{end+1} = plot; %#ok<AGROW>
    end
end
% MATLAB's heatmap chart is not an axes/image object.
allObjects = findall(fig);
for k = 1:numel(allObjects)
    object = allObjects(k);
    if ~isa(object,'matlab.graphics.chart.HeatmapChart'), continue; end
    plots{end+1} = struct('kind','heatmap','title',localString(object.Title), ...
        'x_label',localString(object.XLabel),'y_label',localString(object.YLabel), ...
        'x_scale','linear','y_scale','linear','series',{{}}, ...
        'matrix',{localMatrixRows(object.ColorData)}, ...
        'row_labels',{cellstr(string(object.YData)).'}, ...
        'column_labels',{cellstr(string(object.XData)).'}, ...
        'source_file',file,'display_only_decimation',false); %#ok<AGROW>
end
end

function rows = localMatrixRows(matrix)
rows = cell(1,size(matrix,1));
for k=1:size(matrix,1), rows{k}=num2cell(matrix(k,:)); end
end

function indices = localIndices(values,maximum)
count = numel(values);
if count<=maximum, indices = (1:count)'; return; end
edges = round(linspace(1,count+1,floor(maximum/2)+1));
indices = zeros(2*(numel(edges)-1),1);
for k = 1:numel(edges)-1
    segment = values(edges(k):edges(k+1)-1);
    [~,lo] = min(segment); [~,hi] = max(segment);
    indices(2*k-1:2*k) = edges(k)-1+sort([lo;hi]);
end
indices = unique(indices,'stable');
end

function value = localString(value)
if ischar(value)
    if size(value,1)<=1, return; end
    value = strjoin(cellstr(value),' ');
else
    value = char(strjoin(string(value(:)),' '));
end
end

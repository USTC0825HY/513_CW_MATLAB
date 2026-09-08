function [files, dataFolder] = selectCaptureFiles(dataFolder, selectedFiles, extension, titleText)
%SELECTCAPTUREFILES Select and validate a capture subset without creating output.
if isempty(dataFolder)
    dataFolder = pwd;
    if ~isempty(selectedFiles)
        first = cellstr(string(selectedFiles));
        if java.io.File(first{1}).isAbsolute()
            dataFolder = fileparts(first{1});
        end
    end
end
dataFolder = char(dataFolder);
if ~isfolder(dataFolder)
    error('converter:io:DataFolderNotFound', '数据目录不存在：%s', dataFolder);
end
if isempty(selectedFiles)
    [selectedFiles, selectedPath] = uigetfile(fullfile(dataFolder, ['*' extension]), ...
        titleText, 'MultiSelect', 'on');
    if isequal(selectedFiles, 0)
        files = {};
        return;
    end
    dataFolder = selectedPath;
end
dataFolder = char(java.io.File(char(dataFolder)).getCanonicalPath());
files = cellstr(string(selectedFiles));
files = files(:).';
paths = cell(size(files));
stems = cell(size(files));
for k = 1:numel(files)
    paths{k} = converter.io.resolveInputPath(dataFolder, files{k});
    [~, stem, ext] = fileparts(paths{k});
    if ~isfile(paths{k}) || ~strcmpi(ext, extension)
        error('converter:io:InputFileNotFound', '输入文件不存在或扩展名错误：%s', paths{k});
    end
    stems{k} = lower(regexprep(stem, '[^A-Za-z0-9_-]', '_'));
end
if numel(unique(lower(string(paths)))) ~= numel(paths)
    error('converter:io:DuplicateInput', '同一文件重复选择，请去重后运行。');
end
if numel(unique(stems)) ~= numel(stems)
    error('converter:io:OutputNameCollision', ...
        '所选文件生成的图谱名称重复，请分别运行以保留每份结果。');
end
end

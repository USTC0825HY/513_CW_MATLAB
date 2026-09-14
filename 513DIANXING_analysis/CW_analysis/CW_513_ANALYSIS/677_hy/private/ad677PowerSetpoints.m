function setpoints = ad677PowerSetpoints(dataFolder, selectedFiles)
%AD677POWERSETPOINTS Build a Vpp-only manifest for the selected CSV files.

fileNames = string(selectedFiles(:));
fileCount = numel(fileNames);
inputVoltageVpp = NaN(fileCount, 1);
for fileIndex = 1:fileCount
    inputVoltageVpp(fileIndex) = parseVpp(fileNames(fileIndex));
end
inputPowerSource = repmat("Vpp parsed from CSV filename", fileCount, 1);
loadText = "load unknown";
manifestPath = fullfile(dataFolder, 'run_manifest.json');
if isfile(manifestPath)
    manifest = jsondecode(fileread(manifestPath));
    validateManifest(manifest, fileNames, inputVoltageVpp);
    inputPowerSource(:) = ...
        "run_manifest points.amplitude, filename and source readback agree";
    if isfield(manifest, 'source') && isfield(manifest.source, 'load')
        loadText = "generator LOAD=" + string(manifest.source.load);
    end
end
definition = repmat( ...
    "SDG6032X-E displayed Vpp; " + loadText + ...
    "; board connector and ADC-pin amplitude were not independently measured", ...
    fileCount, 1);
setpoints = table(fileNames, NaN(fileCount, 1), inputVoltageVpp, ...
    NaN(fileCount, 1), inputPowerSource, definition, ...
    'VariableNames', {'FileName', 'InputPowerDbm', 'InputVoltageVpp', ...
    'ReferenceImpedanceOhm', 'InputPowerSource', 'InputPowerDefinition'});
end

function value = parseVpp(fileName)
token = regexp(char(fileName), '(?i)_([0-9]+(?:\.[0-9]+)?)Vpp_', ...
    'tokens', 'once');
if isempty(token)
    error('ad677:VppParseFailed', '文件名无法解析 Vpp：%s。', fileName);
end
value = str2double(token{1});
end

function validateManifest(manifest, fileNames, inputVoltageVpp)
if ~isfield(manifest, 'status') || ~strcmpi(manifest.status, 'complete')
    error('ad677:IncompleteManifest', 'run_manifest 状态不是 complete。');
end
if ~isfield(manifest, 'capture_attempts') || ~isfield(manifest, 'points')
    error('ad677:InvalidManifest', 'run_manifest 缺少采集或激励点信息。');
end
attempts = manifest.capture_attempts;
points = manifest.points;
for fileIndex = 1:numel(fileNames)
    attemptIndex = findAttempt(attempts, fileNames(fileIndex));
    pointIndex = double(attempts(attemptIndex).point_index);
    point = points(pointIndex);
    if ~strcmpi(attempts(attemptIndex).status, 'valid') || ...
            ~strcmpi(point.status, 'committed')
        error('ad677:InvalidCaptureStatus', ...
            '文件 %s 在 manifest 中不是有效采集。', fileNames(fileIndex));
    end
    if ~strcmpi(point.amplitude_unit, 'Vpp') || ...
            abs(double(point.amplitude) - inputVoltageVpp(fileIndex)) > 1e-12
        error('ad677:ManifestVppMismatch', ...
            '文件名 Vpp 与 manifest 不一致：%s。', fileNames(fileIndex));
    end
end
end

function index = findAttempt(attempts, fileName)
[~, selectedStem, selectedExt] = fileparts(fileName);
fileName = string(selectedStem) + string(selectedExt);
index = [];
for attemptIndex = 1:numel(attempts)
    [~, manifestName, extension] = fileparts(attempts(attemptIndex).raw_path);
    if strcmpi(string(manifestName) + string(extension), fileName)
        index = attemptIndex;
        break;
    end
end
if isempty(index)
    error('ad677:ManifestFileMissing', ...
        'run_manifest 未覆盖文件：%s。', fileName);
end
end

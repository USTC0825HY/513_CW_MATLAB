function manifest = read_test_manifest(filePath, requiredFields)
%READ_TEST_MANIFEST Read and normalize the s26-s35 manifest CSV.
%   MANIFEST = laser_analysis.read_test_manifest(FILEPATH) preserves text
%   metadata, converts known numeric fields, and resolves relative source
%   paths against the manifest directory.
%
%   MANIFEST = ...(..., REQUIREDFIELDS) additionally checks that the named
%   columns exist and contain at least one nonmissing value.

arguments
    filePath (1, 1) string
    requiredFields string = strings(0, 1)
end

if strlength(strtrim(filePath)) == 0 || ~isfile(filePath)
    error('laser_analysis:ManifestNotFound', ...
        'Manifest file does not exist: %s', filePath);
end

manifest = readtable(filePath, 'Delimiter', ',', 'TextType', 'string', ...
    'VariableNamingRule', 'preserve');
names = matlab.lang.makeValidName(lower(manifest.Properties.VariableNames));
manifest.Properties.VariableNames = names;

textFields = [ ...
    "case_id", "channel", "source_file", "format", "radix", "coding", ...
    "stimulus_unit", "reference_plane", "data_role", "direction", ...
    "aggressor_channel", "victim_channel", "requirement_id", "status", ...
    "notes", "data_variable", "time_variable", "reference_variable", ...
    "input_variable", "output_variable", "metric", "operator", "unit", ...
    "calibration_source", "reference_channel"];
numericFields = [ ...
    "fs_hz", "data_column", "time_column", "voltage_column", ...
    "reference_column", "frequency_column", "phase_noise_column", ...
    "input_column", "output_column", "bits", ...
    "first_data_row", "stimulus_frequency_hz", "stimulus_level", ...
    "load_ohm", "temperature_c", "cycle", "tau0_s", ...
    "center_frequency_hz", "carrier_frequency_hz", "cable_skew_s", ...
    "limit_value", "lower_limit", "upper_limit", ...
    "calibration_slope_v_per_code", "calibration_intercept_v", ...
    "code_value", "reference_value", "measured_value", ...
    "expected_value", "tolerance", "value", "measurement_resolution_s", ...
    "band_low_hz", "band_high_hz"];

for k = 1:numel(textFields)
    name = char(textFields(k));
    if ~ismember(name, manifest.Properties.VariableNames)
        manifest.(name) = strings(height(manifest), 1);
    else
        manifest.(name) = string(manifest.(name));
    end
end
for k = 1:numel(numericFields)
    name = char(numericFields(k));
    if ~ismember(name, manifest.Properties.VariableNames)
        manifest.(name) = nan(height(manifest), 1);
    else
        manifest.(name) = localToDouble(manifest.(name));
    end
end

manifestDir = fileparts(char(filePath));
for k = 1:height(manifest)
    source = strtrim(manifest.source_file(k));
    if strlength(source) > 0 && ~localIsAbsolutePath(source)
        manifest.source_file(k) = string(fullfile(manifestDir, source));
    end
end

for k = 1:numel(requiredFields)
    name = char(lower(requiredFields(k)));
    if ~ismember(name, manifest.Properties.VariableNames)
        error('laser_analysis:ManifestColumn', ...
            'Manifest lacks required column: %s', name);
    end
    value = manifest.(name);
    if isstring(value)
        hasValue = any(strlength(strtrim(value)) > 0);
    else
        hasValue = any(isfinite(value));
    end
    if ~hasValue
        error('laser_analysis:ManifestValue', ...
            'Manifest column %s contains no usable value.', name);
    end
end
end

function value = localToDouble(raw)
%LOCALTODOUBLE Convert numeric, logical, cell, or string columns to double.
if isnumeric(raw) || islogical(raw)
    value = double(raw);
else
    value = str2double(string(raw));
end
value = value(:);
end

function tf = localIsAbsolutePath(pathValue)
%LOCALISABSOLUTEPATH Detect Windows drive, UNC, and rooted paths.
textValue = char(pathValue);
tf = ~isempty(regexp(textValue, '^[A-Za-z]:[\\/]', 'once')) || ...
    startsWith(textValue, '\\') || startsWith(textValue, '/');
end

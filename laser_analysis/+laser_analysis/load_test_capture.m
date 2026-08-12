function capture = load_test_capture(row)
%LOAD_TEST_CAPTURE Load one explicit manifest row into a uniform capture.
%   CAPTURE = laser_analysis.load_test_capture(ROW) supports MAT, numeric
%   CSV/TXT, and Vivado-style code CSV. It returns value, optional time and
%   reference vectors, sample rate, unit, raw code, and source metadata.
%
%   Standard MAT schemas A/Tinterval and C1_data/C1_time are recognized.
%   Other MAT layouts must provide data_variable/time_variable. ADC code
%   conversion requires bits, coding, and calibration_slope_v_per_code.
%   No sample rate or physical reference plane is inferred from a folder
%   name.

arguments
    row table
end
if height(row) ~= 1
    error('laser_analysis:ManifestRow', ...
        'load_test_capture requires exactly one manifest row.');
end

source = string(row.source_file(1));
if strlength(strtrim(source)) == 0 || ~isfile(source)
    error('laser_analysis:SourceNotFound', ...
        'Capture source does not exist: %s', source);
end

format = lower(strtrim(string(row.format(1))));
if strlength(format) == 0
    [~, ~, extension] = fileparts(source);
    format = erase(lower(string(extension)), ".");
end

capture = localEmptyCapture();
capture.source_file = source;
capture.reference_plane = string(row.reference_plane(1));
capture.format = format;

switch format
    case "mat"
        capture = localLoadMat(capture, row);
    case {"csv", "txt", "ila_csv"}
        capture = localLoadText(capture, row);
    otherwise
        error('laser_analysis:UnsupportedFormat', ...
            'Unsupported capture format: %s', format);
end

capture.value = double(capture.value(:));
capture.time_s = double(capture.time_s(:));
capture.reference = double(capture.reference(:));
if ~isempty(capture.time_s) && numel(capture.time_s) ~= numel(capture.value)
    error('laser_analysis:CaptureLength', ...
        'Time and value vectors have different lengths in %s.', source);
end
if ~isempty(capture.reference) && numel(capture.reference) ~= numel(capture.value)
    error('laser_analysis:CaptureLength', ...
        'Reference and value vectors have different lengths in %s.', source);
end

finiteMask = isfinite(capture.value);
if ~isempty(capture.time_s)
    finiteMask = finiteMask & isfinite(capture.time_s);
end
if ~isempty(capture.reference)
    finiteMask = finiteMask & isfinite(capture.reference);
end
capture.value = capture.value(finiteMask);
if ~isempty(capture.time_s), capture.time_s = capture.time_s(finiteMask); end
if ~isempty(capture.reference), capture.reference = capture.reference(finiteMask); end
if ~isempty(capture.raw_code), capture.raw_code = capture.raw_code(finiteMask); end

if ~isfinite(capture.fs_hz) && numel(capture.time_s) >= 2
    delta = diff(capture.time_s);
    delta = delta(isfinite(delta) & delta > 0);
    if ~isempty(delta)
        capture.fs_hz = 1 / median(delta);
    end
end
if isempty(capture.time_s) && isfinite(capture.fs_hz)
    capture.time_s = (0:numel(capture.value) - 1).' / capture.fs_hz;
end
capture.sample_count = numel(capture.value);
capture.sha256 = laser_analysis.sha256_file(source);
end

function capture = localLoadMat(capture, row)
%LOCALLOADMAT Load a configured or recognized MAT time-series schema.
data = load(capture.source_file);
dataName = localResolveVariable(data, string(row.data_variable(1)), ...
    ["A", "C1_data", "voltage", "data"]);
timeName = localResolveVariable(data, string(row.time_variable(1)), ...
    ["C1_time", "time_s", "time"], true);
referenceName = localResolveVariable(data, ...
    string(row.reference_variable(1)), ["reference", "C2_data"], true);

capture.value = double(data.(dataName)(:));
if strlength(timeName) > 0
    capture.time_s = double(data.(timeName)(:));
end
if strlength(referenceName) > 0
    capture.reference = double(data.(referenceName)(:));
end
capture.fs_hz = row.fs_hz(1);
if ~isfinite(capture.fs_hz)
    if isfield(data, 'Tinterval') && isfinite(double(data.Tinterval(1))) && ...
            double(data.Tinterval(1)) > 0
        capture.fs_hz = 1 / double(data.Tinterval(1));
    elseif isfield(data, 'fs') && isfinite(double(data.fs(1)))
        capture.fs_hz = double(data.fs(1));
    end
end
capture.unit = "V";
end

function capture = localLoadText(capture, row)
%LOCALLOADTEXT Load numeric voltage columns or decode an ILA code column.
dataColumn = row.data_column(1);
if ~isfinite(dataColumn), dataColumn = row.voltage_column(1); end
if ~isfinite(dataColumn)
    error('laser_analysis:ManifestValue', ...
        'Text capture requires data_column or voltage_column.');
end
dataColumn = round(dataColumn);

radix = lower(strtrim(string(row.radix(1))));
isCode = capture.format == "ila_csv" || strlength(radix) > 0;
if isCode
    raw = readcell(capture.source_file, 'Delimiter', ',');
    firstRow = row.first_data_row(1);
    if ~isfinite(firstRow)
        firstRow = localFindFirstCodeRow(raw(:, dataColumn), radix);
    end
    code = localParseCode(raw(round(firstRow):end, dataColumn), radix);
    valid = isfinite(code);
    code = code(valid);
    bits = row.bits(1);
    if ~isfinite(bits)
        error('laser_analysis:ManifestValue', ...
            'Code capture requires bits.');
    end
    signedCode = localDecodeCode(code, round(bits), string(row.coding(1)));
    capture.raw_code = signedCode;
    slope = row.calibration_slope_v_per_code(1);
    intercept = row.calibration_intercept_v(1);
    if isfinite(slope)
        if ~isfinite(intercept), intercept = 0; end
        capture.value = signedCode .* slope + intercept;
        capture.unit = "V";
    else
        capture.value = signedCode;
        capture.unit = "code";
    end
else
    matrix = readmatrix(capture.source_file);
    if dataColumn > size(matrix, 2)
        error('laser_analysis:ManifestColumn', ...
            'data_column exceeds available columns in %s.', capture.source_file);
    end
    capture.value = matrix(:, dataColumn);
    timeColumn = row.time_column(1);
    if isfinite(timeColumn)
        capture.time_s = matrix(:, round(timeColumn));
    end
    referenceColumn = row.reference_column(1);
    if isfinite(referenceColumn)
        capture.reference = matrix(:, round(referenceColumn));
    end
    capture.unit = "V";
end
capture.fs_hz = row.fs_hz(1);
end

function name = localResolveVariable(data, requested, candidates, optional)
%LOCALRESOLVEVARIABLE Resolve a requested name or a documented MAT schema.
if nargin < 4, optional = false; end
if strlength(strtrim(requested)) > 0
    if ~isfield(data, requested)
        error('laser_analysis:MatSchema', ...
            'MAT file lacks variable %s.', requested);
    end
    name = requested;
    return;
end
name = "";
for k = 1:numel(candidates)
    if isfield(data, candidates(k))
        name = candidates(k);
        return;
    end
end
if ~optional
    error('laser_analysis:MatSchema', ...
        'MAT file lacks a recognized data variable.');
end
end

function firstRow = localFindFirstCodeRow(values, radix)
%LOCALFINDFIRSTCODEROW Find the first parseable code token in a CSV column.
for k = 1:numel(values)
    if isfinite(localParseOneCode(values{k}, radix))
        firstRow = k;
        return;
    end
end
error('laser_analysis:NoCodeData', 'No parseable code token was found.');
end

function code = localParseCode(values, radix)
%LOCALPARSECODE Parse decimal or hexadecimal code tokens.
code = nan(numel(values), 1);
for k = 1:numel(values)
    code(k) = localParseOneCode(values{k}, radix);
end
end

function value = localParseOneCode(raw, radix)
%LOCALPARSEONECODE Parse one numeric, decimal, or hexadecimal token.
if isnumeric(raw) && isscalar(raw)
    value = double(raw);
    return;
end
token = strtrim(string(raw));
token = erase(token, "'");
token = regexprep(token, '^0[xX]', '');
if strlength(token) == 0
    value = NaN;
elseif radix == "hex"
    value = hex2dec(char(token));
else
    value = str2double(token);
end
end

function signedCode = localDecodeCode(code, bits, coding)
%LOCALDECODECODE Convert raw ADC words to signed or unipolar code.
coding = lower(strtrim(coding));
if coding == "twos_complement"
    signedCode = code;
    wrapMask = signedCode >= 2^(bits - 1);
    signedCode(wrapMask) = signedCode(wrapMask) - 2^bits;
elseif coding == "offset_binary"
    signedCode = code - 2^(bits - 1);
elseif coding == "unipolar"
    signedCode = code;
else
    error('laser_analysis:ManifestValue', ...
        'coding must be twos_complement, offset_binary, or unipolar.');
end
signedCode = double(signedCode(:));
end

function capture = localEmptyCapture()
%LOCALEMPTYCAPTURE Return the stable capture struct contract.
capture = struct('source_file', "", 'format', "", 'value', [], ...
    'time_s', [], 'reference', [], 'raw_code', [], 'fs_hz', NaN, ...
    'unit', "", 'reference_plane', "", 'sample_count', 0, 'sha256', "");
end

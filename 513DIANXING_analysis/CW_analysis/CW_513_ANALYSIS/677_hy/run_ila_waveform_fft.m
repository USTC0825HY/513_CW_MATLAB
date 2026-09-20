function results = run_ila_waveform_fft(csvFiles, resultDir, opts)
%RUN_ILA_WAVEFORM_FFT GUI / batch entry for ila_waveform_fft on ILA CSVs.
%
%   run_ila_waveform_fft()                          % GUI multi-select
%   results = run_ila_waveform_fft(csvFiles)        % explicit file list
%   results = run_ila_waveform_fft(csvFiles, resultDir)
%   results = run_ila_waveform_fft(csvFiles, resultDir, opts)
%
%   csvFiles  char | string | cellstr/string array of CSV paths. Omitted
%             (or []) opens a multi-select file dialog ('*.csv;*.CSV').
%   resultDir output BASE folder. Every invocation creates a fresh
%             timestamped subfolder run_<yyyyMMdd_HHmmss>_ila_fft inside it,
%             shared by all analysed files, so nothing is ever written
%             directly into a data folder. '' (default) resolves the base
%             with the repo layout convention: data folder named "raw" ->
%             sibling "results"; data folder one level below "raw" ->
%             "results" next to that "raw"; otherwise "results" inside the
%             data folder. GUI mode offers this base in a folder dialog
%             (Cancel keeps the default base).
%   opts      option struct forwarded to ila_waveform_fft. signalColumn /
%             validColumn are auto-resolved per CSV and override anything
%             passed here. autoToneMarkers defaults to true in this entry.
%
%   Per CSV the entry auto-detects (signal, valid) column pairs:
%     * signal: header containing "adc" and "data" (case-insensitive),
%       excluding valid/vld columns -- e.g. "adc1_data[15:0]" (dual-driver
%       captures) and "u_ad677_2/adc_data[15:0]" (single-channel captures);
%     * valid:  header obtained by replacing "data" with "data_vld" (old
%       format) or "valid" (new format). Gated mode is used when a valid
%       column exists, raw mode @ ilaClockHz otherwise (with a warning).
%
%   Output naming is unique: <csv basename>__<signal>.png/.mat/__spectrum.csv
%   inside the timestamped run folder, appending __1, __2 ... when the same
%   csv+signal is analysed again into the same folder, so repeated or
%   multi-folder runs never overwrite.
%
%   Example:
%     results = run_ila_waveform_fft( ...
%         {'G:\...\X3_X13_NOISE.CSV', 'G:\...\01_freq\raw\...\..._10kHz_sweep_....csv'}, ...
%         'D:\analysis_out', struct('window','blackmanharris'));
%
%   results is a struct array (one element per signal per CSV) with all
%   fields returned by ila_waveform_fft.

if nargin < 1
    csvFiles = [];
end
if nargin < 2 || isempty(resultDir)
    resultDir = '';
elseif ~ischar(resultDir) && ~isstring(resultDir)
    error('run_ila_waveform_fft:usage', 'resultDir must be a char/string path.');
end
if nargin < 3
    opts = struct();
end

% ---- GUI file selection when no list is given -----------------------------
if isempty(csvFiles)
    [sel, selPath] = uigetfile({'*.csv;*.CSV', 'CSV capture exports'}, ...
        'Select CSV files (multi-select allowed)', 'MultiSelect', 'on');
    if isequal(sel, 0)
        fprintf('run_ila_waveform_fft: cancelled at file selection, nothing done.\n');
        if nargout > 0
            results = struct('file', {}, 'signalName', {}, 'mode', {}, ...
                'fsHz', {}, 'dc', {}, 'pkpk', {}, 'cyclePeriod', {}, ...
                'figureFile', {});
        end
        return;
    end
    if iscell(sel)
        csvFiles = fullfile(selPath, sel(:));
    else
        csvFiles = {fullfile(selPath, sel)};
    end
    defaultDir = resolveResultsBase(char(csvFiles{1}));
    picked = uigetdir(defaultDir, ...
        'Select output BASE folder (timestamped run_xxx_ila_fft is created inside; Cancel = default)');
    if ~isequal(picked, 0)
        resultDir = char(picked);
    end
end

files = string(csvFiles);
files = files(:);
if files.numel() == 0
    error('run_ila_waveform_fft:usage', 'Empty csvFiles list.');
end

% ---- one timestamped run folder per invocation, never the data folder ----
if isempty(resultDir)
    outBase = resolveResultsBase(char(files(1)));
else
    outBase = char(resultDir);
end
runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
runDir = fullfile(outBase, ['run_' runStamp '_ila_fft']);
fprintf('run_ila_waveform_fft: outputs -> %s\n', runDir);

% ---- defaults for this entry; user opts win except forced fields ---------
callDefaults = struct('autoToneMarkers', true);
callOpts = callDefaults;
fn = fieldnames(opts);
for k = 1:numel(fn)
    callOpts.(fn{k}) = opts.(fn{k});   % unknown fields rejected downstream
end

% ---- per-file loop --------------------------------------------------------
results = [];
for iFile = 1:numel(files)
    csvFile = char(files(iFile));
    if ~isfile(csvFile)
        warning('run_ila_waveform_fft:missing', 'File not found, skipped: %s', csvFile);
        continue;
    end
    try
        pairs = detectAdcPairs(csvFile);
    catch err
        warning('run_ila_waveform_fft:header', ...
            'Cannot read header of %s (%s); skipped.', csvFile, err.message);
        continue;
    end
    if isempty(pairs)
        warning('run_ila_waveform_fft:nocolumn', ...
            'No "adc*data" column found in %s; skipped. Run ila_waveform_fft directly with signalColumn for non-ADC columns.', ...
            csvFile);
        continue;
    end
    for k = 1:numel(pairs)
        thisOpts = callOpts;
        thisOpts.signalColumn = pairs(k).signal;
        thisOpts.validColumn = pairs(k).valid;
        thisOpts.resultDir = runDir;
        try
            r = ila_waveform_fft(csvFile, thisOpts);
        catch err
            warning('run_ila_waveform_fft:analysis', ...
                'Analysis failed for %s / %s: %s', csvFile, pairs(k).signal, err.message);
            continue;
        end
        topFreq = NaN;
        if ~isempty(r.peaks.freqHz)
            [~, im] = max(r.peaks.amp);
            topFreq = r.peaks.freqHz(im);
        end
        fprintf('%-42s | %-24s | %-28s | fs=%9.4g Hz | dc=%+8.2f | pkpk=%7g | cycleP=%s | topPeak=%s Hz\n', ...
            getbasename(csvFile), r.signalName, r.mode, r.fsHz, r.dc, r.pkpk, ...
            num2str(r.cyclePeriod, '%g'), num2str(topFreq, '%.4g'));
        results = appendResult(results, r); %#ok<AGROW>
    end
end
fprintf('run_ila_waveform_fft: %d analyses done.\n', numel(results));
end

%% ----------------------------------------------------------------- local
function base = resolveResultsBase(csvFile)
%Repo results layout: data folder named "raw" -> sibling "results"; data
%folder one level below "raw" -> "results" next to that "raw"; otherwise
%a "results" folder inside the data folder.
dataFolder = fileparts(csvFile);
[parentOfData, dataName] = fileparts(dataFolder);
[parentOfParent, parentName] = fileparts(parentOfData);
if strcmpi(dataName, 'raw')
    base = fullfile(parentOfData, 'results');
elseif strcmpi(parentName, 'raw')
    base = fullfile(parentOfParent, 'results');
else
    base = fullfile(dataFolder, 'results');
end
end

function pairs = detectAdcPairs(csvFile)
importOpts = detectImportOptions(csvFile, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve');
headers = string(importOpts.VariableNames);
% compare on names with the bus-width suffix "[...]" stripped
base = lower(regexprep(headers, '\[.*$', ''));
base = strtrim(base);

sigMask = contains(base, 'adc') & contains(base, 'data') & ...
    ~contains(base, 'valid') & ~contains(base, 'vld');
sigIdx = find(sigMask);
pairs = struct('signal', {}, 'valid', {});
for k = 1:numel(sigIdx)
    sigBase = base(sigIdx(k));
    v = '';
    cand1 = regexprep(sigBase, 'data', 'data_vld');
    cand2 = regexprep(sigBase, 'data', 'valid');
    hit = find(base == cand1, 1);
    if isempty(hit)
        hit = find(base == cand2, 1);
    end
    if isempty(hit)  % prefix fallback: <sig-prefix>*valid/vld
        pref = regexp(sigBase, '^(.*?)(data.*)$', 'tokens', 'once');
        if ~isempty(pref)
            hit = find(startsWith(base, pref{1}) & ...
                (contains(base, 'valid') | contains(base, 'vld')), 1);
        end
    end
    if ~isempty(hit)
        v = headers(hit);
    end
    pairs(end+1) = struct('signal', headers(sigIdx(k)), 'valid', v); %#ok<AGROW>
end
end

function out = appendResult(results, r)
keep = {'file', 'signalName', 'mode', 'fsHz', 'dc', 'pkpk', ...
    'cyclePeriod', 'figureFile'};
s = struct();
for k = 1:numel(keep)
    s.(keep{k}) = r.(keep{k});
end
if isempty(results)
    out = s;
else
    out = [results, s];
end
end

function b = getbasename(p)
[~, b, e] = fileparts(p);
if isempty(b)
    b = e;
end
end

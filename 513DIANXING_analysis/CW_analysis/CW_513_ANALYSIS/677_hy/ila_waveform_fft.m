function result = ila_waveform_fft(csvFile, opts)
%ILA_WAVEFORM_FFT Generic waveform + single-sided FFT analysis for CSV captures.
%
%   result = ILA_WAVEFORM_FFT(csvFile)
%   result = ILA_WAVEFORM_FFT(csvFile, opts)
%
%   Works on any comma-separated capture export with a header row:
%     * Vivado ILA CSV exports (100 MHz clock domain, buses held between
%       strobes), and
%     * plain uniformly sampled numeric CSV columns (e.g. scope exports),
%       provided opts.sampleRateHz is given.
%
%   Two analysis modes:
%     * Gated mode (default when opts.validColumn is set): the signal is
%       resampled at the strobe rows only. The effective sample rate is
%       derived from the measured strobe spacing and opts.ilaClockHz, and
%       uniformity of the spacing is checked and reported. This is the
%       correct mode for ILA-captured ADC buses whose code only updates on
%       a valid strobe (held rows would otherwise dominate the FFT).
%     * Raw mode: the full column is analysed at opts.sampleRateHz (or
%       opts.ilaClockHz for ILA files).
%
%   opts fields (all optional, struct(); partial override supported):
%     signalColumn   header name, case-insensitive substring, or column
%                    index. Default: 4 (Vivado ILA ADC data convention).
%     validColumn    header name/substring/index of the 0/1 strobe column.
%                    '' (default) selects raw mode.
%     ilaClockHz     ILA capture clock for gated mode (default 100e6).
%     sampleRateHz   explicit sample rate for raw mode; NaN = ilaClockHz.
%     codeFormat     'auto' (default) | 'signed16' | 'raw'.
%                    'auto' passes numeric columns through and converts
%                    4-digit hex text columns to int16 two's complement.
%     window         'hann' (default) | 'rect' | 'hamming' | 'blackman' |
%                    'blackmanharris' | 'flattop'.
%     removeDC       true (default) removes the record mean before the FFT;
%                    the DC value is still reported in the result.
%     voltsPerCount  NaN (default) keeps native counts with unitLabel;
%                    a finite value rescales amplitudes to volts.
%     unitLabel      amplitude label, default 'LSB'.
%     toneMarkersHz  vector of expected tone frequencies drawn as dashed
%                    vertical lines on the spectrum (default []).
%     autoToneMarkers false (default) | true. Detects the repetition period
%                    P of the code sequence (lag 2..64, accepted when the
%                    lag-P residual std < 30% of signal std) and marks
%                    tones at k*fs/P. Meant for limit-cycle captures.
%     peakCount      spectral peaks tabulated/annotated (default 6).
%     maxFreqHz      spectrum x-limit, NaN = Nyquist (default NaN).
%     logSpectrum    false (default) linear y; true plots 20*log10.
%     titlePrefix    prepended to figure titles (default '').
%     resultDir      exact output folder; '' (default) creates a timestamped
%                    run folder run_<yyyyMMdd_HHmmss>_ila_fft under the
%                    conventional results base (sibling of a "raw" data
%                    folder, else "results" inside the data folder). The
%                    data folder itself is never used for outputs.
%     saveFigures    true (default) saves PNG + result .mat + spectrum CSV.
%     showFigures    false (default) keeps figures invisible (batch use).
%
%   result fields: file, signalName, mode, fsHz, t (s), x (native counts),
%   dc, pkpk, spacingStats (gated), fHz, amp (single-sided amplitude,
%   window-corrected), peaks (struct: freqHz/amp), cyclePeriod,
%   toneMarkersHzUsed, figureFile, matFile, spectrumCsvFile.
%
%   Example (AD677 dual-driver ILA capture):
%     r = ila_waveform_fft('G:\...\X3_X13_NOISE.CSV', struct( ...
%          'signalColumn','adc1_data', 'validColumn','adc1_valid', ...
%          'toneMarkersHz',[20.833e3 41.667e3], 'titlePrefix','ADC1 tc '));
%
%   The function uses base MATLAB only (no toolbox windows; window shapes
%   are computed locally).

if nargin < 1
    error('ila_waveform_fft:usage', ...
        'csvFile is required. For GUI multi-file use run_ila_waveform_fft().');
end
opts = overrideDefaults(opts);

%% ------------------------------------------------------------------ read
importOpts = detectImportOptions(csvFile, 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve', 'TextType', 'char');
headers = string(importOpts.VariableNames);
sigIdx = resolveColumn(headers, opts.signalColumn, 'signalColumn');
signalName = char(headers(sigIdx));

useGated = false;
validIdx = NaN;
if ~isempty(opts.validColumn)
    validIdx = resolveColumn(headers, opts.validColumn, 'validColumn');
    useGated = true;
end

% signed16 forces a text read so all-digit hex words (e.g. "0013") are not
% pre-converted to decimal by the import sniffer.
if strcmpi(opts.codeFormat, 'signed16')
    importOpts.VariableTypes{sigIdx} = 'char';
end
tbl = readtable(csvFile, importOpts);

xAll = decodeColumn(tbl.(sigIdx), opts.codeFormat);

%% ------------------------------------------------------- mode + sampling
spacingStats = struct('min', NaN, 'median', NaN, 'max', NaN, 'uniform', true, ...
    'uniqueSpacings', []);
t = [];
fs = NaN;
if useGated
    validRaw = double(tbl.(validIdx));
    validRows = find(validRaw > 0.5);
    if numel(validRows) < 4
        error('ila_waveform_fft:strobe', ...
            'Only %d strobe rows found; need >=4 for spectrum.', numel(validRows));
    end
    x = xAll(validRows);
    spacing = diff(validRows);
    spacingStats.min = min(spacing);
    spacingStats.median = median(spacing);
    spacingStats.max = max(spacing);
    spacingStats.uniqueSpacings = unique(spacing);
    spread = (spacingStats.max - spacingStats.min) / spacingStats.median;
    spacingStats.uniform = spread <= opts.gatedTolerance;
    if ~spacingStats.uniform
        warning('ila_waveform_fft:spacing', ...
            'Strobe spacing not uniform (min=%d, med=%d, max=%d ILA cycles); spectrum uses median rate.', ...
            spacingStats.min, spacingStats.median, spacingStats.max);
    end
    fs = opts.ilaClockHz / spacingStats.median;
    t = (validRows - validRows(1)) / opts.ilaClockHz;
    mode = sprintf('gated @ %s (1 strobe / %g ILA cycles)', engUnitHz(fs), spacingStats.median);
else
    x = xAll;
    if isnan(opts.sampleRateHz)
        fs = opts.ilaClockHz;
    else
        fs = opts.sampleRateHz;
    end
    t = (0:numel(x)-1).' / fs;
    mode = sprintf('raw @ %s', engUnitHz(fs));
end
clear xAll;

dc = mean(x);
pkpk = max(x) - min(x);
xZenith = x - dc * double(opts.removeDC);

%% ----------------------------------------------------------------- scale
voltsPerCount = opts.voltsPerCount;
scaleFactor = 1;
ampLabel = opts.unitLabel;
if ~isnan(voltsPerCount)
    scaleFactor = voltsPerCount;
    ampLabel = 'V';
end

%% ------------------------------------------------- optional tone autodetect
toneMarkers = opts.toneMarkersHz(:);
cyclePeriod = NaN;
% gated only: raw ILA buses are held staircases whose sparse transitions
% make any small lag look "periodic" and would false-trigger the detector
if opts.autoToneMarkers && useGated && numel(x) >= 12
    cyclePeriod = detectCyclePeriod(x);
    if ~isnan(cyclePeriod) && cyclePeriod > 1
        m = (1:cyclePeriod - 1) * fs / cyclePeriod;
        toneMarkers = unique([toneMarkers; m(m > 0 & m <= fs / 2).']);
    end
end
plotOpts = opts;
plotOpts.toneMarkersHz = toneMarkers;

%% --------------------------------------------------------------- spectrum
n = numel(xZenith);
w = makeWindow(opts.window, n);
nfft = max(2^nextpow2(n), n);
X = fft(xZenith .* w, nfft);
halfN = floor(nfft / 2) + 1;
amp = abs(X(1:halfN)) / sum(w);           % DC-correct single-sided
amp(2:end-1) = 2 * amp(2:end-1);
f = (0:halfN-1).' * fs / nfft;
amp = amp * scaleFactor;

peakTbl = findPeaks(f, amp, opts.peakCount);
if isnan(opts.maxFreqHz)
    fLimit = fs / 2;
else
    fLimit = min(opts.maxFreqHz, fs / 2);
end

%% -------------------------------------------------------------- figure
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1150 780]);
% force light-theme rendering regardless of the MATLAB desktop theme:
% without these defaults the axes interior, grid and text follow dark mode
% and exported PNGs come out mostly black
set(fig, 'DefaultAxesColor', 'w', ...
    'DefaultAxesXColor', 'k', 'DefaultAxesYColor', 'k', 'DefaultAxesZColor', 'k', ...
    'DefaultTextColor', 'k', ...
    'DefaultAxesGridColor', [0.15 0.15 0.15], ...
    'DefaultLegendColor', 'w', 'DefaultLegendTextColor', 'k');
try
    plotWaveform(fig, t, x, dc, pkpk, signalName, mode, opts);
    plotSpectrum(fig, f, amp, fLimit, peakTbl, ampLabel, signalName, plotOpts);
catch err
    close(fig);
    rethrow(err);
end

%% ------------------------------------------------------------- outputs
baseName = matlab.lang.makeValidName([getbasename(csvFile) '__' signalName]);
outFiles = struct('figureFile', '', 'matFile', '', 'spectrumCsvFile', '');
if opts.saveFigures
    if ~isempty(opts.resultDir)
        outDir = opts.resultDir;
    else
        outDir = defaultRunDir(csvFile);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    % never overwrite earlier outputs of same csv+signal: add __1, __2, ...
    stem = baseName;
    suffix = 0;
    while any(isfile(fullfile(outDir, [stem '.png'])) || ...
              isfile(fullfile(outDir, [stem '.mat'])) || ...
              isfile(fullfile(outDir, [stem '__spectrum.csv'])))
        suffix = suffix + 1;
        stem = sprintf('%s__%d', baseName, suffix);
    end
    baseName = stem;
    outFiles.figureFile = fullfile(outDir, [baseName '.png']);
    exportgraphics(fig, outFiles.figureFile, 'Resolution', 130);
    outFiles.matFile = fullfile(outDir, [baseName '.mat']);
    resultSnapshot = struct('file', csvFile, 'signalName', signalName, ...
        'mode', mode, 'fsHz', fs, 't', t, 'x', x, 'dc', dc, 'pkpk', pkpk, ...
        'spacingStats', spacingStats, 'fHz', f, 'amp', amp, 'peaks', peakTbl, ...
        'cyclePeriod', cyclePeriod, 'toneMarkersHzUsed', toneMarkers);
    save(outFiles.matFile, '-struct', 'resultSnapshot');
    outFiles.spectrumCsvFile = fullfile(outDir, [baseName '__spectrum.csv']);
    writematrix([f, amp], outFiles.spectrumCsvFile);
end
if opts.showFigures
    set(fig, 'Visible', 'on');
else
    close(fig);
end

result = struct('file', csvFile, 'signalName', signalName, 'mode', mode, ...
    'fsHz', fs, 't', t, 'x', x, 'dc', dc, 'pkpk', pkpk, ...
    'spacingStats', spacingStats, 'fHz', f, 'amp', amp, 'peaks', peakTbl, ...
    'cyclePeriod', cyclePeriod, 'toneMarkersHzUsed', toneMarkers, ...
    'figureFile', outFiles.figureFile, 'matFile', outFiles.matFile, ...
    'spectrumCsvFile', outFiles.spectrumCsvFile);
end

%% ----------------------------------------------------------------- local
function outDir = defaultRunDir(csvFile)
%Timestamped run folder under the conventional results base; never writes
%into the data folder itself (see run_ila_waveform_fft help for layout).
runStamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
outDir = fullfile(resolveResultsBase(csvFile), ['run_' runStamp '_ila_fft']);
end

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

function opts = overrideDefaults(in)
def = struct('signalColumn', 4, 'validColumn', '', 'ilaClockHz', 100e6, ...
    'sampleRateHz', NaN, 'codeFormat', 'auto', 'window', 'hann', ...
    'removeDC', true, 'voltsPerCount', NaN, 'unitLabel', 'LSB', ...
    'toneMarkersHz', [], 'autoToneMarkers', false, 'peakCount', 6, ...
    'maxFreqHz', NaN, 'logSpectrum', false, 'titlePrefix', '', ...
    'resultDir', '', 'saveFigures', true, 'showFigures', false, ...
    'gatedTolerance', 0.001);
if isempty(in)
    opts = def;
    return;
end
opts = def;
fn = fieldnames(in);
for k = 1:numel(fn)
    if ~isfield(opts, fn{k})
        error('ila_waveform_fft:option', 'Unknown option "%s".', fn{k});
    end
    opts.(fn{k}) = in.(fn{k});
end
end

function idx = resolveColumn(headers, want, what)
if isnumeric(want)
    idx = want;
    if idx < 1 || idx > numel(headers)
        error('ila_waveform_fft:column', '%s index %d out of range (1..%d).', ...
            what, idx, numel(headers));
    end
    return;
end
wantS = lower(strtrim(string(want)));
hit = find(headers == wantS, 1);
if isempty(hit)  % substring match, first hit
    hit = find(~cellfun(@isempty, strfind(lower(headers), wantS)), 1);
end
if isempty(hit)
    error('ila_waveform_fft:column', ...
        '%s "%s" not found. Available columns:\n%s', what, wantS, ...
        strjoin(cellstr(headers'), newline));
end
idx = hit;
end

function x = decodeColumn(col, codeFormat)
switch lower(codeFormat)
    case 'raw'
        x = double(col);
    case 'signed16'
        x = double(trySigned16(col));
    otherwise  % auto
        if isnumeric(col)
            x = double(col);
        else
            x = double(trySigned16(col));
        end
end
x = x(:);
end

function v = trySigned16(col)
s = string(col);
n = numel(s);
v = zeros(n, 1, 'int16');
parsed = false(n, 1);
for k = 1:n
    tok = strtrim(s(k));
    if ~isempty(tok) && all(ismember(char(tok), '0123456789abcdefABCDEF'))
        v(k) = typecast(uint16(sscanf(char(tok), '%x')), 'int16');
        parsed(k) = true;
    end
end
if ~all(parsed)
    error('ila_waveform_fft:format', ...
        'Column contains non-hex text entries; set codeFormat=''raw'' or fix the export radix.');
end
end

function p = detectCyclePeriod(x)
%First lag in 2..min(64, floor(n/3)) whose lagged residual std falls below
%30% of the signal std; NaN when no strong repetition exists.
xm = x(:) - mean(x);
base = std(xm);
if base <= 0
    p = NaN;
    return;
end
n = numel(xm);
maxLag = min(64, floor(n / 3));
if maxLag < 2
    p = NaN;
    return;
end
for cand = 2:maxLag
    if std(xm(1:end-cand) - xm(1+cand:end)) < 0.3 * base
        p = cand;
        return;
    end
end
p = NaN;
end

function w = makeWindow(name, n)
switch lower(name)
    case 'rect'
        w = ones(n, 1);
    case 'hann'
        w = 0.5 - 0.5 * cos(2 * pi * (0:n-1)' / max(n - 1, 1));
    case 'hamming'
        w = 0.54 - 0.46 * cos(2 * pi * (0:n-1)' / max(n - 1, 1));
    case 'blackman'
        w = 0.42 - 0.5 * cos(2 * pi * (0:n-1)' / max(n - 1, 1)) ...
            + 0.08 * cos(4 * pi * (0:n-1)' / max(n - 1, 1));
    case 'blackmanharris'
        a = [0.35875 0.48829 0.14128 0.01168];
        m = (0:n-1)' / max(n - 1, 1);
        w = a(1) - a(2)*cos(2*pi*m) + a(3)*cos(4*pi*m) - a(4)*cos(6*pi*m);
    case 'flattop'
        a = [0.21557895 0.41663158 0.277263158 0.083578947 0.006947368];
        m = (0:n-1)' / max(n - 1, 1);
        w = a(1) - a(2)*cos(2*pi*m) + a(3)*cos(4*pi*m) - a(4)*cos(6*pi*m) ...
            + a(5)*cos(8*pi*m);
    otherwise
        error('ila_waveform_fft:window', 'Unknown window "%s".', name);
end
end

function p = findPeaks(f, amp, peakCount)
p = struct('freqHz', [], 'amp', []);
if numel(f) < 3
    return;
end
threshold = 0.05 * max(amp(2:end));
cand = [];
for k = 2:numel(amp) - 1
    if amp(k) > amp(k-1) && amp(k) >= amp(k+1) && amp(k) > threshold
        % parabolic refine on log amplitude
        a0 = log(amp(k-1) + eps); a1 = log(amp(k) + eps); a2 = log(amp(k+1) + eps);
        delta = 0.5 * (a0 - a2) / (a0 - 2*a1 + a2 + eps);
        delta = max(min(delta, 1), -1);
        cand = [cand; f(k) + delta * (f(2) - f(1)), amp(k) - (a0 - a2) * delta / 4]; %#ok<AGROW>
    end
end
if isempty(cand)
    return;
end
[~, order] = sort(cand(:, 2), 'descend');
cand = cand(order(1:min(end, peakCount)), :);
[~, order] = sort(cand(:, 1), 'ascend');
cand = cand(order, :);
p.freqHz = cand(:, 1);
p.amp = cand(:, 2);
end

function plotWaveform(fig, t, x, dc, pkpk, signalName, mode, opts)
ax = subplot(2, 1, 1, 'Parent', fig);
stairs(ax, t * 1e6, x, 'LineWidth', 1.1);
hold(ax, 'on');
yline(ax, dc, ':', sprintf('mean %+.1f', dc), 'Color', [0.5 0.5 0.5], ...
    'LabelHorizontalAlignment', 'left');
plot(ax, t * 1e6, x, '.', 'MarkerSize', 4);
hold(ax, 'off');
grid(ax, 'on');
xlabel(ax, 'time (#mus)');
ylabel(ax, sprintf('code (%s)', opts.unitLabel));
title(ax, sprintf('%s%s  |  %s  |  N=%d, pk-pk=%g %s', opts.titlePrefix, ...
    signalName, mode, numel(x), pkpk, opts.unitLabel), 'Interpreter', 'none');
end

function plotSpectrum(fig, f, amp, fLimit, peakTbl, ampLabel, signalName, opts)
ax = subplot(2, 1, 2, 'Parent', fig);
if opts.logSpectrum
    ampPlot = @(a) 20 * log10(a + eps);
    plot(ax, f / 1e3, ampPlot(amp), 'LineWidth', 1.1);
    ylabel(ax, sprintf('amplitude (dB%s)', ampLabel));
else
    ampPlot = @(a) a;
    plot(ax, f / 1e3, amp, 'LineWidth', 1.1);
    ylabel(ax, sprintf('amplitude (%s)', ampLabel));
end
hold(ax, 'on');
mk = opts.toneMarkersHz(:).';
mk = mk(mk > 0 & mk <= fLimit);
for k = 1:numel(mk)
    xline(ax, mk(k) / 1e3, '--', sprintf('%.3f k', mk(k) / 1e3), ...
        'Color', [0.85 0.2 0.2]);
end
if ~isempty(peakTbl.freqHz)
    plot(ax, peakTbl.freqHz / 1e3, ampPlot(peakTbl.amp), 'v', 'MarkerFaceColor', 'r');
    for k = 1:numel(peakTbl.freqHz)
        text(ax, peakTbl.freqHz(k) / 1e3, ampPlot(peakTbl.amp(k)), ...
            sprintf('  %.3f k', peakTbl.freqHz(k) / 1e3), 'Rotation', 90, ...
            'FontSize', 8, 'VerticalAlignment', 'top');
    end
end
hold(ax, 'off');
grid(ax, 'on');
xlim(ax, [0 fLimit / 1e3]);
xlabel(ax, 'frequency (kHz)');
title(ax, sprintf('%s%s  amplitude spectrum (%s window, DC %s)', ...
    opts.titlePrefix, signalName, opts.window, ...
    ternary(opts.removeDC, 'removed', 'kept')), 'Interpreter', 'none');
end

function s = ternary(cond, a, b)
if cond
    s = a;
else
    s = b;
end
end

function s = engUnitHz(f)
if f >= 1e9
    s = sprintf('%.4g GHz', f / 1e9);
elseif f >= 1e6
    s = sprintf('%.6g MHz', f / 1e6);
elseif f >= 1e3
    s = sprintf('%.6g kHz', f / 1e3);
else
    s = sprintf('%.6g Hz', f);
end
end

function b = getbasename(p)
[~, b, e] = fileparts(p);
if isempty(b)
    b = e;
end
end

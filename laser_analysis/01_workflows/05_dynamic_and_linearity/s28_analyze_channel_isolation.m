function result = s28_analyze_channel_isolation(cfg)
%S28_ANALYZE_CHANNEL_ISOLATION Analyze aggressor-victim isolation.
%   RESULT = s28_analyze_channel_isolation(CFG) fits the same stimulus tone
%   in an excited channel and a victim channel, then computes
%   20*log10(Aaggressor/Avictim). ADC ILA and DAC oscilloscope captures use
%   the same amplitude-fit method.
%
%   Rows are paired by case_id, aggressor_channel, and victim_channel.
%   Both channel rows must have the same explicit reference_plane and a
%   valid stimulus_frequency_hz. Otherwise the numeric evidence is retained
%   but the compliance status is 暂不能判定.

arguments
    cfg (1, 1) struct
end

manifest = laser_analysis.read_test_manifest(cfg.manifestFile, ...
    ["case_id", "channel", "source_file", "aggressor_channel", ...
    "victim_channel"]);
pairKeys = unique(manifest(:, ...
    {'case_id', 'aggressor_channel', 'victim_channel'}), 'rows', 'stable');
rows = cell(height(pairKeys), 11);
curveRows = cell(0, 6);
sourceRows = cell(0, 7);

for k = 1:height(pairKeys)
    key = pairKeys(k, :);
    groupMask = manifest.case_id == key.case_id & ...
        manifest.aggressor_channel == key.aggressor_channel & ...
        manifest.victim_channel == key.victim_channel;
    group = manifest(groupMask, :);
    aggressorRow = group(group.channel == key.aggressor_channel, :);
    victimRow = group(group.channel == key.victim_channel, :);
    reason = "";
    aggressorAmplitude = NaN;
    victimAmplitude = NaN;
    toneHz = localUniqueFinite(group.stimulus_frequency_hz);
    if height(aggressorRow) ~= 1 || height(victimRow) ~= 1
        reason = "每个通道组合必须恰有一条 aggressor 和 victim 记录";
    elseif ~isfinite(toneHz)
        reason = "激励频率缺失或不一致";
    else
        aggressor = laser_analysis.load_test_capture(aggressorRow);
        victim = laser_analysis.load_test_capture(victimRow);
        if ~isfinite(aggressor.fs_hz) || ~isfinite(victim.fs_hz) || ...
                toneHz >= min(aggressor.fs_hz, victim.fs_hz) / 2
            reason = "采样率缺失或激励超出 Nyquist";
        else
            aggressorFit = laser_analysis.fit_tone( ...
                aggressor.time_s, aggressor.value, toneHz);
            victimFit = laser_analysis.fit_tone( ...
                victim.time_s, victim.value, toneHz);
            aggressorAmplitude = aggressorFit.amplitude;
            victimAmplitude = victimFit.amplitude;
            sourceRows = [sourceRows; localSourceRows( ...
                key.case_id, aggressorRow, aggressor); ...
                localSourceRows(key.case_id, victimRow, victim)]; %#ok<AGROW>
        end
    end
    if aggressorAmplitude > 0 && victimAmplitude > 0
        isolationDb = 20 * log10(aggressorAmplitude / victimAmplitude);
    else
        isolationDb = NaN;
    end
    subsystem = localIsolationSubsystem(group.data_role);
    requirement = laser_analysis.find_requirement(cfg, "isolation", subsystem);
    status = laser_analysis.evaluate_requirement( ...
        isolationDb, requirement, cfg.formalEnabled);
    referencePlanes = unique(strtrim(group.reference_plane));
    if strlength(reason) > 0 || numel(referencePlanes) ~= 1 || ...
            strlength(referencePlanes) == 0
        status = "暂不能判定";
    end
    rows(k, :) = {key.case_id, key.aggressor_channel, ...
        key.victim_channel, toneHz, aggressorAmplitude, victimAmplitude, ...
        isolationDb, subsystem, localRequirementId(requirement), status, reason};
    curveRows(end + 1, :) = {key.case_id, key.victim_channel, ...
        "isolation", toneHz, isolationDb, "dB"}; %#ok<AGROW>
end

details = cell2table(rows, 'VariableNames', { ...
    'case_id', 'aggressor_channel', 'victim_channel', ...
    'stimulus_frequency_hz', 'aggressor_amplitude', 'victim_amplitude', ...
    'isolation_db', 'subsystem', 'requirement_id', 'status', 'reason'});
summary = localSummary(details);
curves = cell2table(curveRows, 'VariableNames', { ...
    'case_id', 'channel', 'curve_type', 'x_value', 'y_value', 'unit'});
sources = cell2table(sourceRows, 'VariableNames', { ...
    'case_id', 'channel', 'source_file', 'sha256', 'reference_plane', ...
    'calibration_source', 'sample_count'});
output = laser_analysis.write_evidence_bundle( ...
    cfg, summary, details, curves, sources);
figureHandle = localPlot(details);
figurePath = laser_analysis.save_evidence_figure( ...
    figureHandle, output, "channel_isolation", cfg);
result = struct('config', cfg, 'summary', summary, 'details', details, ...
    'curves', curves, 'sources', sources, 'output', output, ...
    'figure', figurePath);
save(output.resultMat, 'result', '-append');
end

function row = localSourceRows(caseId, manifestRow, capture)
%LOCALSOURCEROWS Build one source provenance row.
row = {caseId, manifestRow.channel, capture.source_file, capture.sha256, ...
    capture.reference_plane, manifestRow.calibration_source, ...
    capture.sample_count};
end

function value = localUniqueFinite(values)
%LOCALUNIQUEFINITE Return one unique finite number or NaN.
values = unique(values(isfinite(values)));
if isscalar(values), value = values; else, value = NaN; end
end

function subsystem = localIsolationSubsystem(dataRole)
%LOCALISOLATIONSUBSYSTEM Select ADC or DAC from explicit data_role.
dataRole = lower(strtrim(dataRole));
if any(contains(dataRole, "dac"))
    subsystem = "dac";
elseif any(contains(dataRole, "adc"))
    subsystem = "adc";
else
    subsystem = "";
end
end

function id = localRequirementId(requirement)
%LOCALREQUIREMENTID Return the unique requirement id when available.
if height(requirement) == 1
    id = requirement.requirement_id;
else
    id = "";
end
end

function summary = localSummary(details)
%LOCALSUMMARY Report the worst isolation pair for each subsystem.
subsystems = unique(details.subsystem, 'stable');
rows = cell(numel(subsystems), 6);
for k = 1:numel(subsystems)
    mask = details.subsystem == subsystems(k);
    part = details(mask, :);
    valid = find(isfinite(part.isolation_db));
    if isempty(valid)
        worst = NaN;
        pair = "";
        status = "暂不能判定";
    else
        [worst, index] = min(part.isolation_db(valid));
        row = part(valid(index), :);
        pair = row.aggressor_channel + "->" + row.victim_channel;
        status = row.status;
    end
    rows(k, :) = {subsystems(k), worst, pair, status, ...
        height(part), nnz(part.status == "暂不能判定")};
end
summary = cell2table(rows, 'VariableNames', { ...
    'subsystem', 'worst_isolation_db', 'worst_pair', 'status', ...
    'pair_count', 'undetermined_count'});
end

function figureHandle = localPlot(details)
%LOCALPLOT Plot isolation values by channel pair.
figureHandle = figure('Visible', 'off', 'Color', 'w');
labels = details.aggressor_channel + "->" + details.victim_channel;
bar(categorical(labels), details.isolation_db);
ylabel('Isolation (dB)');
title('Channel isolation');
grid on;
end

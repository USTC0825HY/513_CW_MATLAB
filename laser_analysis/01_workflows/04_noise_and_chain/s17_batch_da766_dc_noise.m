% s17_batch_da766_dc_noise - Batch DA766 DC-noise ASD and integrated-noise analysis
% Requirement: 12 uV/sqrt(Hz) at 1 Hz and <1 mVrms over 1 kHz--100 kHz.

clc;
dataRoot = "F:\\01_Laser\\20260727_513test\\513_CW_DATA\\DA766\\03_DCNoise";
asdCheckHz = 1; asdLimit_uVPerSqrtHz = 12;
integratedBandHz = [1e3, 100e3]; integratedLimit_mVrms = 1;
targetResolutionHz = 1; overlapRatio = 0.5; windowType = "hann";
removeMean = true; hardwareGain = 1;

channelDirs = dir(dataRoot);
channelDirs = channelDirs([channelDirs.isdir] & ~ismember({channelDirs.name},{'.','..'}));
allSummary = table();
for c = 1:numel(channelDirs)
    channelDir = fullfile(channelDirs(c).folder, channelDirs(c).name);
    rawFiles = dir(fullfile(channelDir, "raw", "**", "*.mat"));
    if isempty(rawFiles), continue; end
    resultRoot = fullfile(channelDir, "result"); asdDir = fullfile(resultRoot, "ASD");
    integratedDir = fullfile(resultRoot, "integrated_noise");
    if ~exist(asdDir,"dir"), mkdir(asdDir); end
    if ~exist(integratedDir,"dir"), mkdir(integratedDir); end
    channelSummary = repmat(localEmptyResult(), numel(rawFiles), 1);
    for k = 1:numel(rawFiles)
        matPath = fullfile(rawFiles(k).folder, rawFiles(k).name);
        fprintf("[%s %d/%d] %s\n",channelDirs(c).name,k,numel(rawFiles),matPath);
        channelSummary(k) = localAnalyzeOne(matPath,channelDirs(c).name,asdDir,integratedDir, ...
            asdCheckHz,asdLimit_uVPerSqrtHz,integratedBandHz,integratedLimit_mVrms, ...
            targetResolutionHz,overlapRatio,windowType,removeMean,hardwareGain);
    end
    channelTable = struct2table(channelSummary);
    writetable(channelTable,fullfile(resultRoot,channelDirs(c).name+"_summary.csv"));
    writetable(channelTable(:,{'input_file','input_path','source_samples','dropped_nonfinite', ...
        'sample_rate_hz','duration_s','asd_at_check_uV_per_sqrtHz','asd_limit_uV_per_sqrtHz', ...
        'asd_1hz_judgment','band_asd_max_uV_per_sqrtHz','integrated_noise_mVrms', ...
        'integrated_limit_mVrms','integrated_judgment'}),fullfile(asdDir,channelDirs(c).name+"_ASD_summary.csv"));
    writetable(channelTable(:,{'input_file','input_path','source_samples','dropped_nonfinite', ...
        'sample_rate_hz','duration_s','integrated_band_start_hz','integrated_band_end_hz', ...
        'integrated_noise_mVrms','integrated_limit_mVrms','integrated_judgment'}), ...
        fullfile(integratedDir,channelDirs(c).name+"_integrated_noise_summary.csv"));
    save(fullfile(resultRoot,channelDirs(c).name+"_analysis_parameters.mat"), ...
        "dataRoot","asdCheckHz","asdLimit_uVPerSqrtHz","integratedBandHz", ...
        "integratedLimit_mVrms","targetResolutionHz","overlapRatio","windowType", ...
        "removeMean","hardwareGain");
    allSummary = [allSummary; channelTable]; %#ok<AGROW>
end
topResult = fullfile(dataRoot,"result"); if ~exist(topResult,"dir"), mkdir(topResult); end
writetable(allSummary,fullfile(topResult,"DA766_DCNoise_summary.csv"));
save(fullfile(topResult,"DA766_DCNoise_summary.mat"),"allSummary","dataRoot", ...
    "asdCheckHz","asdLimit_uVPerSqrtHz","integratedBandHz","integratedLimit_mVrms", ...
    "targetResolutionHz","overlapRatio","windowType","removeMean","hardwareGain");
fprintf("Completed %d input files.\n",height(allSummary));

function result = localAnalyzeOne(matPath,channelName,asdDir,integratedDir,asdCheckHz,asdLimit,bandHz, ...
    integratedLimit_mVrms,targetResolutionHz,overlapRatio,windowType,removeMean,hardwareGain)
data = load(matPath);
if isfield(data,"A"), variableName = "A"; elseif isfield(data,"B"), variableName = "B";
else, error("No A/B waveform in %s",matPath); end
raw = double(data.(variableName)(:)); inputSamples = numel(raw); valid = isfinite(raw);
voltage = raw(valid)/hardwareGain; if removeMean, voltage = voltage-mean(voltage); end
fs = 1/double(data.Tinterval(1)); N = numel(voltage);
windowLength = max(16,min(N,round(fs/targetResolutionHz))); nfft = windowLength;
overlapLength = floor(overlapRatio*windowLength);
if lower(windowType)=="hann", win = hann(windowLength,"periodic");
else, error("Unsupported window type: %s",windowType); end
[psd,f] = pwelch(voltage,win,overlapLength,nfft,fs); asd = sqrt(psd); asd_uV = asd*1e6;
[~,idxCheck] = min(abs(f-asdCheckHz)); bandMask = f>=bandHz(1) & f<=min(bandHz(2),fs/2);
covered = bandHz(2)<=fs/2; bandMax = max(asd_uV(bandMask)); bandP95 = prctile(asd_uV(bandMask),95);
integratedVrms = sqrt(trapz(f(bandMask),psd(bandMask)));
if covered && integratedVrms*1e3<integratedLimit_mVrms, intJudge="满足";
elseif covered, intJudge="不满足"; else, intJudge="暂不能判定"; end
if asd_uV(idxCheck)<asdLimit, asdJudge="满足"; else, asdJudge="不满足"; end
[~,stem,~] = fileparts(matPath); safeStem = regexprep(stem,"[^A-Za-z0-9_-]","_");
specTable = table(f,psd,asd,asd_uV,'VariableNames',{'frequency_hz','psd_V2_per_Hz','asd_V_per_sqrtHz','asd_uV_per_sqrtHz'});
writetable(specTable,fullfile(asdDir,channelName+"_"+safeStem+"_spectrum.csv"));
fig=figure("Visible","off"); loglog(f(2:end),asd_uV(2:end),"LineWidth",1); grid on; hold on;
yline(asdLimit,"r--","12 uV/sqrtHz"); xline(asdCheckHz,"k--","1 Hz"); xline(bandHz(1),"m--","1 kHz"); xline(bandHz(2),"m--","100 kHz");
xlabel("Frequency (Hz)"); ylabel("ASD (uV/sqrtHz)"); title(channelName+" "+stem+" ASD");
exportgraphics(fig,fullfile(asdDir,channelName+"_"+safeStem+"_ASD.png"),"Resolution",180); close(fig);
fig=figure("Visible","off"); loglog(f(2:end),psd(2:end),"LineWidth",1); grid on; hold on; xline(bandHz(1),"m--","1 kHz"); xline(bandHz(2),"m--","100 kHz");
xlabel("Frequency (Hz)"); ylabel("PSD (V^2/Hz)"); title(channelName+" "+stem+" PSD");
exportgraphics(fig,fullfile(asdDir,channelName+"_"+safeStem+"_PSD.png"),"Resolution",180); close(fig);
intTable=table(string(channelName),string(stem),string(matPath),integratedVrms*1e3,integratedLimit_mVrms,string(intJudge),bandHz(1),bandHz(2),covered, ...
    'VariableNames',{'channel','input_file','input_path','integrated_noise_mVrms','integrated_limit_mVrms','judgment','band_start_hz','band_end_hz','fully_covered'});
writetable(intTable,fullfile(integratedDir,channelName+"_"+safeStem+"_integrated_noise.csv"));
result=localEmptyResult(); result.channel=string(channelName); result.input_file=string(stem); result.input_path=string(matPath); result.variable=variableName;
result.source_samples=inputSamples; result.dropped_nonfinite=inputSamples-N; result.sample_rate_hz=fs; result.duration_s=N/fs;
result.welch_window_samples=windowLength; result.welch_overlap_samples=overlapLength; result.welch_nfft=nfft; result.welch_resolution_hz=fs/nfft;
result.asd_at_check_hz=f(idxCheck); result.asd_at_check_uV_per_sqrtHz=asd_uV(idxCheck); result.asd_limit_uV_per_sqrtHz=asdLimit; result.asd_1hz_judgment=asdJudge;
result.band_asd_max_uV_per_sqrtHz=bandMax; result.band_asd_p95_uV_per_sqrtHz=bandP95; result.integrated_band_start_hz=bandHz(1); result.integrated_band_end_hz=bandHz(2);
result.integrated_noise_mVrms=integratedVrms*1e3; result.integrated_limit_mVrms=integratedLimit_mVrms; result.integrated_judgment=intJudge; result.fully_covered=covered;
end

function r=localEmptyResult()
r=struct("channel","","input_file","","input_path","","variable","","source_samples",NaN,"dropped_nonfinite",NaN,"sample_rate_hz",NaN,"duration_s",NaN, ...
"welch_window_samples",NaN,"welch_overlap_samples",NaN,"welch_nfft",NaN,"welch_resolution_hz",NaN,"asd_at_check_hz",NaN,"asd_at_check_uV_per_sqrtHz",NaN,"asd_limit_uV_per_sqrtHz",NaN, ...
"asd_1hz_judgment","","band_asd_max_uV_per_sqrtHz",NaN,"band_asd_p95_uV_per_sqrtHz",NaN,"integrated_band_start_hz",NaN,"integrated_band_end_hz",NaN,"integrated_noise_mVrms",NaN,"integrated_limit_mVrms",NaN,"integrated_judgment","","fully_covered",false);
end

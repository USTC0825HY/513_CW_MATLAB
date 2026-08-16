function [resultTable, outputDir] = run_da9726_noise_current(dataRoot)
%RUN_DA9726_NOISE_CURRENT Analyze the current DA9726 noise campaign.
%   [RESULT, OUTPUTDIR] = RUN_DA9726_NOISE_CURRENT(DATAROOT) runs the
%   s11 ASD-only workflow on eight explicit PicoScope MAT files.
%   It derives sampling rate from Tinterval, preserves every raw file, and
%   writes a timestamped evidence bundle below DATAROOT\results.

resultTable = table();

workflowFolder = fileparts(mfilename('fullpath'));
analysisRoot = fileparts(fileparts(workflowFolder));
addpath(analysisRoot);
addpath(fullfile(analysisRoot, 'utilities'));

if nargin < 1 || isempty(dataRoot)
    dataRoot = fullfile('F:', '01_Laser', '20260727_513test', ...
        'CW_Data', '513_CW_DATA', 'DA9726', '03_Noise');
end
dataRoot = char(dataRoot);
if ~isfolder(dataRoot)
    error('DA9726 noise data root does not exist: %s', dataRoot);
end

requirements = laser_analysis.requirement_profile('digital_lock', 'CW');
asdRequirement = requirements( ...
    requirements.requirement_id == "DL-CW-DAC-ASD-1HZ", :);
if height(asdRequirement) ~= 1 || asdRequirement.state ~= "approved"
    error('Approved DA9726 noise requirements could not be resolved.');
end

inputFiles = [ ...
    string(fullfile(dataRoot, 'DAC1_JG18', 'JG_18_250kSPS_20s.mat')); ...
    string(fullfile(dataRoot, 'DAC2_JG20', 'JG_20_250kSPS_20s.mat')); ...
    string(fullfile(dataRoot, 'DAC3_JG21', 'JG21_250kSPS_20s_CHC.mat')); ...
    string(fullfile(dataRoot, 'DAC4_JG23', 'JG23_250kSPS_20s_CHD.mat')); ...
    string(fullfile(dataRoot, 'DAC4_JG23', ...
    'JG23_250kSPS_20s_CHD_CODE_HEX250.mat')); ...
    string(fullfile(dataRoot, 'DAC4_JG23', ...
    'JG23_250kSPS_20s_CHD_CODE_HEX500.mat')); ...
    string(fullfile(dataRoot, 'DAC4_JG23', ...
    'JG23_250kSPS_20s_CHD_CODE_HEX1000.mat')); ...
    string(fullfile(dataRoot, 'DAC5_JG25', 'JG25_250kSPS_20s_CHB.mat'))];
dataVariables = ["A"; "A"; "C"; "D"; "D"; "D"; "D"; "B"];

% The portable runtime creates the timestamped run folder itself.  Keep
% this value as the result parent to avoid nested run directories.
runFolder = fullfile(dataRoot, 'results');

dacNoiseCfgOverride = struct();
dacNoiseCfgOverride.analysisName = "DA9726";
dacNoiseCfgOverride.dataDir = string(dataRoot);
dacNoiseCfgOverride.outputDir = runFolder;
dacNoiseCfgOverride.inputFiles = inputFiles;
dacNoiseCfgOverride.dataVariables = dataVariables;
dacNoiseCfgOverride.hardwareGain = 1;
dacNoiseCfgOverride.asdCheckHz = 1;
dacNoiseCfgOverride.asdLimit_uVPerSqrtHz = asdRequirement.limit_a;
dacNoiseCfgOverride.asdOnly = true;
dacNoiseCfgOverride.integratedBandHz = [1e3, 100e3];
dacNoiseCfgOverride.targetResolutionHz = 0.2;
dacNoiseCfgOverride.overlapRatio = 0.5;
dacNoiseCfgOverride.windowType = "hann";
dacNoiseCfgOverride.minimumAsdSegmentCount = 4;
dacNoiseCfgOverride.maximumAsdBinRelativeError = 0.25;
dacNoiseCfgOverride.referencePlane = ...
    "DA9726 connector output; acquisition load not encoded in MAT/PNG";
dacNoiseCfgOverride.calibrationSource = ...
    "PicoScope MAT channel in volts; hardwareGain=1";
dacNoiseCfgOverride.requirementAsdId = asdRequirement.requirement_id;
dacNoiseCfgOverride.requirementIntegratedId = "";
dacNoiseCfgOverride.requirementSourceDocument = ...
    asdRequirement.source_document;
dacNoiseCfgOverride.requirementSourceSha256 = ...
    asdRequirement.source_sha256;
dacNoiseCfgOverride.formalEnabled = false;
dacNoiseCfgOverride.formalLimitation = ...
    "High-impedance acquisition condition is required but not recorded in MAT or PNG";
dacNoiseCfgOverride.showFigure = false; %#ok<STRNU>

run(fullfile(workflowFolder, 's11_analyze_dac_output_noise_metrics.m'));
outputDir = cfg.outputDir;
end

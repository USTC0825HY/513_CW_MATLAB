function paths = setup_laser_analysis()
%SETUP_LASER_ANALYSIS Add current Laser analysis folders to the MATLAB path.
%   PATHS = setup_laser_analysis() adds the repository root, utilities,
%   public workflows, and specialized active tools. Archive and reference
%   folders are intentionally excluded to avoid duplicate function names.
%
%   Run this once after starting MATLAB:
%       cd('F:\01_Laser\code\matlab\laser_analysis')
%       paths = setup_laser_analysis();

root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root, 'utilities'));
addpath(genpath(fullfile(root, '01_workflows')));

specializedFolders = ["PDH_data_process", "yang_scale"];
for k = 1:numel(specializedFolders)
    folder = fullfile(root, specializedFolders(k));
    if isfolder(folder)
        addpath(genpath(folder));
    end
end

paths = laser_test_paths();
end

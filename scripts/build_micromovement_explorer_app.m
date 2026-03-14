% build_micromovement_explorer_app.m
%
% Build recipe for compiling the micromovement browser as a standalone app.
%
% Requirements:
%   - MATLAB Compiler toolbox
%   - adjust outputDir / optional bundled data paths as needed

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
appEntry = fullfile(repoRoot, 'CODE', 'APPS', 'launchMicromovementExplorerApp.m');
outputDir = fullfile(repoRoot, 'build', 'micromovement_explorer_app');

if ~license('test', 'MATLAB_Compiler')
    error('MATLAB Compiler license is not available in this MATLAB session.');
end

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

appFiles = {
    appEntry
    fullfile(repoRoot, 'resources', 'bodypart_marker_grouping.csv')
    fullfile(repoRoot, 'resources', 'stim_video_encoding_SINGLES.csv')
    };

% Optional: bundle processed MAT data directly into the app package.
% This can make the app large, but is acceptable for collaborator-only use.
optionalDataDir = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest';
if isfolder(optionalDataDir)
    appFiles{end+1} = optionalDataDir; %#ok<SAGROW>
end

buildResults = compiler.build.standaloneApplication(appEntry, ...
    'OutputDir', outputDir, ...
    'TreatInputsAsNumeric', false, ...
    'AdditionalFiles', appFiles, ...
    'ExecutableName', 'MicromovementExplorer');

disp(buildResults);

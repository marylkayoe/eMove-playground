% launch_emowear_accel_browser.m
%
% Convenience launcher for browsing the downloaded EmoWear MATLAB package.

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
addpath(genpath(fullfile(repoRoot, 'CODE')));

launchEmoWearAccelBrowserApp( ...
    'repoRoot', repoRoot, ...
    'dataRoot', '/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279');

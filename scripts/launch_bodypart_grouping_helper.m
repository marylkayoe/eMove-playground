% launch_bodypart_grouping_helper.m
%
% Opens interactive marker->bodypart grouping helper.
% Edit group assignments and export CSV or MAT from the UI.

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
matFile = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/matlab_from_manifest/SC3001/SC3001_mocap_Take_2025_08_25_05_19_25_PM.mat';
initialCsv = '/Users/yoe/Documents/REPOS/eMove-playground/resources/templates/bodypart_marker_template.csv';
outDir = '/Users/yoe/Documents/REPOS/eMove-playground/resources/templates';

addpath(genpath(fullfile(repoRoot, 'CODE')));
launchBodypartGroupingHelper(matFile, 'initialCsv', initialCsv, 'outputDir', outDir);

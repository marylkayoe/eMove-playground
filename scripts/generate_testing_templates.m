% generate_testing_templates.m
%
% Create starter CSV templates for:
%   1) stimulus video encoding
%   2) bodypart marker grouping
%
% Prerequisites:
%   - master_file_list_preview.csv exists
%   - at least one MAT exists under matlab_from_manifest (for marker names)

clearvars;
clc;

repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
dataRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';

manifestCsv = fullfile(dataRoot, 'master_file_list_preview.csv');
matRoot = fullfile(dataRoot, 'matlab_from_manifest');
outDir = fullfile(repoRoot, 'resources', 'templates');

if ~isfolder(repoRoot)
    error('Repo root missing: %s', repoRoot);
end
if ~isfile(manifestCsv)
    error('Manifest missing: %s', manifestCsv);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

fprintf('\n[1/2] Creating stim encoding template...\n');
stimCsv = fullfile(outDir, 'stim_video_encoding_template.csv');
stimTbl = createStimEncodingTemplateFromManifest(manifestCsv, ...
    'outCsv', stimCsv, ...
    'includeBaseline', true, ...
    'includeDemo', false);
fprintf('Saved: %s (%d rows)\n', stimCsv, height(stimTbl));

fprintf('\n[2/2] Creating bodypart grouping templates...\n');
matFiles = dir(fullfile(matRoot, '*', '*.mat'));
if isempty(matFiles)
    error('No MAT files found under: %s', matRoot);
end
sampleMat = fullfile(matFiles(1).folder, matFiles(1).name);
[markerTbl, groupTbl] = createBodypartGroupingTemplateFromTrialData(sampleMat, ...
    'outputDir', outDir);
fprintf('Saved: %s (%d rows)\n', fullfile(outDir, 'bodypart_marker_template.csv'), height(markerTbl));
fprintf('Saved: %s (%d rows)\n', fullfile(outDir, 'bodypart_groups_template.csv'), height(groupTbl));

fprintf('\nDone.\n');

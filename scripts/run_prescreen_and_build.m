% run_prescreen_and_build.m
%
% End-to-end ingestion helper for the current HUMANMOCAP dataset.
% This script:
%   1) Runs prescreen assignment and saves master file list CSV.
%   2) Optionally copies files into per-subject layout.
%   3) Optionally builds per-subject trialData MAT files.
%   4) Optionally builds trialData directly from manifest (no copy workflow).
%
% Notes:
% - Hardwired exclusions are applied by project code:
%   JANNE, AS2302, XC1301
% - Repeated post-baseline Unity video IDs are handled in
%   buildSelfReportTrialToUnityMap (keep first occurrence).

clearvars;
clc;

%% User Config
repoRoot = '/Users/yoe/Documents/REPOS/eMove-playground';
sourceRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP';
destRoot = '/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject';

% Set true to copy raw files into subject folders under destRoot.
doCopy = false;

% Set true to run trialData MAT building after copy.
runBatchBuild = false;

% Set true to build trialData directly from manifest without copying files.
runBatchBuildFromManifest = true;

%% Path Setup
if ~isfolder(repoRoot)
    error('Repo root does not exist: %s', repoRoot);
end
if ~isfolder(sourceRoot)
    error('Source root does not exist: %s', sourceRoot);
end
if ~exist(destRoot, 'dir')
    mkdir(destRoot);
end

addpath(genpath(fullfile(repoRoot, 'CODE')));

%% 1) Prescreen / Master File List (No Copy)
fprintf('\n[1/3] Running prescreen assignments (no copy)...\n');
assignmentsPreview = buildDatasetAssignments(sourceRoot, destRoot, 'doCopy', false);
previewCsv = fullfile(destRoot, 'master_file_list_preview.csv');
writetable(assignmentsPreview, previewCsv);
fprintf('Saved: %s\n', previewCsv);
fprintf('Rows: %d\n', height(assignmentsPreview));

%% 2) Optional Copy To Subject Layout
if doCopy
    fprintf('\n[2/3] Copying files to subject layout...\n');
    assignmentsCopied = buildDatasetAssignments(sourceRoot, destRoot, 'doCopy', true);
    copiedCsv = fullfile(destRoot, 'master_file_list_copied.csv');
    writetable(assignmentsCopied, copiedCsv);
    fprintf('Saved: %s\n', copiedCsv);
    fprintf('Rows: %d\n', height(assignmentsCopied));

    ensureMatlabSubfolders(destRoot);
else
    fprintf('\n[2/3] Skipped copy stage (doCopy=false).\n');
end

%% 3) Optional trialData Build
if runBatchBuild
    if ~doCopy
        warning('runBatchBuild=true but doCopy=false. Build may find zero subject folders in destRoot.');
    end
    fprintf('\n[3/3] Building trialData MAT files...\n');
    results = buildSubjectTrialDataBatch(destRoot, ...
        'verbose', true, ...
        'continueOnError', true);
    resultsCsv = fullfile(destRoot, 'trialdata_build_results.csv');
    writetable(results, resultsCsv);
    fprintf('Saved: %s\n', resultsCsv);
    fprintf('Rows: %d\n', height(results));
else
    fprintf('\n[3/3] Skipped trialData build stage (runBatchBuild=false).\n');
end

%% 4) Optional trialData Build (Manifest-Only, No Copy)
if runBatchBuildFromManifest
    fprintf('\n[4/4] Building trialData MAT files from manifest (no copy)...\n');
    manifestCsv = previewCsv;
    resultsManifest = buildSubjectTrialDataBatchFromManifest(manifestCsv, ...
        'outputRoot', fullfile(destRoot, 'matlab_from_manifest'), ...
        'verbose', true, ...
        'continueOnError', true);
    resultsManifestCsv = fullfile(destRoot, 'trialdata_build_results_manifest.csv');
    writetable(resultsManifest, resultsManifestCsv);
    fprintf('Saved: %s\n', resultsManifestCsv);
    fprintf('Rows: %d\n', height(resultsManifest));
else
    fprintf('\n[4/4] Skipped manifest-only trialData build stage (runBatchBuildFromManifest=false).\n');
end

fprintf('\nDone.\n');

%% Local Helpers
function ensureMatlabSubfolders(destRoot)
% Create <subject>/matlab folders so buildSubjectTrialDataBatch can run.
    d = dir(destRoot);
    for i = 1:numel(d)
        if ~d(i).isdir
            continue;
        end
        name = d(i).name;
        if any(strcmp(name, {'.', '..', 'stimvideos'}))
            continue;
        end
        if isempty(regexp(name, '^[A-Z]{2}\d{4}$', 'once'))
            continue;
        end

        matlabDir = fullfile(destRoot, name, 'matlab');
        if ~exist(matlabDir, 'dir')
            mkdir(matlabDir);
        end
    end
end

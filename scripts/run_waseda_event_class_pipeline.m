% Run the Waseda ACC unitary/compound event-class summary pipeline.
%
% This script regenerates the scratch analysis outputs and promotes the curated
% event-class comparison figures into figures/WASEDA_ACC_EVENT_CLASSES_20260508.
% It expects Waseda magnitude MAT files produced by the chest-envelope workflow.

clear;
close all;
clc;

set(0, 'DefaultFigureVisible', 'off');

scriptPath = mfilename('fullpath');
repoRoot = fileparts(fileparts(scriptPath));

addpath(fullfile(repoRoot, 'CODE', 'ACCELEROMETER'));
addpath(fullfile(repoRoot, 'CODE', 'ANALYSIS'));

magnitudeFolder = LF_resolveMagnitudeFolder({ ...
    getenv('WASEDA_ACC_MAGNITUDES'), ...
    '/Users/yoe/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES', ...
    '/Users/yoe/Library/CloudStorage/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES', ...
    '/Users/yoe/Documents/DATA/Waseda-ACC/MATLAB-CONVERTED/MAGNITUDES'});

scratchOutputFolder = fullfile(repoRoot, 'scratch', 'waseda_event_class_pipeline_20260508_onset_only');
curatedFigureFolder = fullfile(repoRoot, 'figures', 'WASEDA_ACC_EVENT_CLASSES_20260508');

if ~isfolder(scratchOutputFolder)
    mkdir(scratchOutputFolder);
end
if ~isfolder(curatedFigureFolder)
    mkdir(curatedFigureFolder);
end

analysisOutput = analyzePrimitiveEvents(magnitudeFolder, ...
    'OutputFolder', scratchOutputFolder, ...
    'FigureStem', 'primitive_event_class_pipeline');

figureStemsToPromote = [ ...
    "primitive_event_class_pipeline_event_class_grouped_mean_waveforms", ...
    "primitive_event_class_pipeline_cdfs_by_condition_and_event_class", ...
    "primitive_event_class_pipeline_cdfs_by_subject_and_event_class"];

for figureIndex = 1:numel(figureStemsToPromote)
    figureStem = figureStemsToPromote(figureIndex);
    copyfile(fullfile(scratchOutputFolder, figureStem + ".png"), curatedFigureFolder);
    copyfile(fullfile(scratchOutputFolder, figureStem + ".fig"), curatedFigureFolder);
end

disp(analysisOutput.eventClassSummaryTable);
fprintf('Scratch outputs: %s\n', scratchOutputFolder);
fprintf('Curated figures: %s\n', curatedFigureFolder);

function magnitudeFolder = LF_resolveMagnitudeFolder(candidateFolders)
for folderIndex = 1:numel(candidateFolders)
    candidateFolder = char(string(candidateFolders{folderIndex}));
    if strlength(string(candidateFolder)) == 0
        continue;
    end
    if isfolder(candidateFolder)
        magnitudeFolder = candidateFolder;
        return;
    end
end

error('run_waseda_event_class_pipeline:MissingMagnitudeFolder', ...
    'No Waseda magnitude folder found. Set WASEDA_ACC_MAGNITUDES or update the candidate list.');
end

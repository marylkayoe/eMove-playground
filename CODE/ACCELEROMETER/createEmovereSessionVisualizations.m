function visualizationOutput = createEmovereSessionVisualizations(sessionFolder, varargin)
%CREATEEMOVERESESSIONVISUALIZATIONS Create standard Emovere session figures.
%
% visualizationOutput = createEmovereSessionVisualizations(sessionFolder)
%
% Purpose
%   Read one Emovere app export folder and render a recorded-trial review
%   page. This function is the standard Emovere entry point; it adapts the
%   export into the existing motionData contract and uses
%   plotEnvelopeEventsWithNoiseBand for the accepted residual CWT computation.
%
% Input
%   sessionFolder
%       Folder containing Emovere export files such as:
%       meta.json, lar_summary.json, and lar_diagnostics.csv.
%
% Name-value options
%   'OutputRoot'                  default scratch/emovere_sessions/<sessionID>
%   'OutputStem'                  default <sessionID>_<focusSource>
%   'ResampleToUniformTime'       default true
%       CWT assumes a regular sample grid. When true, the motion-score trace
%       is interpolated onto a median-step grid before saving motionData.
%   'WaveletSource'               default "residual"
%       Passed to plotEnvelopeEventsWithNoiseBand. The accepted Emovere
%       default is "residual".
%   'WaveletFrequencyLimitsHz'    default []
%       If empty, derive [0.1 highHz] from lar_summary.json and Nyquist.
%   'BaselineWindowSeconds'       default []
%       If empty, use lar_summary.params.local_baseline_window_seconds.
%   'NoiseWindowSeconds'          default 30
%   'ThresholdSigma'              default []
%       If empty, use lar_summary.params.within_lar_event_threshold_sigma.
%   'CompoundSubpeakThresholdSigma' default []
%       If empty, use lar_summary.params.within_lar_prominence_sigma.
%   'CompoundSubpeakMinDistanceSeconds' default []
%       If empty, use lar_summary.params.minimum_event_distance_seconds.
%   'WaveletColorPercentile'      default 99
%   'ShowWaveletEventLines'       default true
%   'WindowSeconds'               default []
%       Optional [start end] window in seconds from session start.
%   'CreateReviewPage'            default true
%       Render the non-redundant recorded-trial review page.
%   'CreateAcceptedWaveletFigure' default false
%       Also export the full accepted plotEnvelopeEventsWithNoiseBand figure.
%   'ExportPng'                   default true
%   'ExportFig'                   default true
%   'SavePlotOutput'              default false
%   'CloseFigure'                 default true
%   'FigurePosition'              default [80 70 1500 980]
%   'ReviewFigurePosition'        default [80 70 1500 900]
%
% Output
%   visualizationOutput
%       Struct with paths, metadata, preprocessing notes, and plot output.
%
% Important assumptions
%   lar_diagnostics.motion_score is treated as the scalar motion envelope.
%   plotEnvelopeEventsWithNoiseBand recomputes the local baseline and
%   residual used for the CWT panel. Emovere residual-wavelet visualization
%   should not be reimplemented elsewhere.

inputParserObject = inputParser;

addRequired(inputParserObject, 'sessionFolder', ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputRoot', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'OutputStem', "", ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'ResampleToUniformTime', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WaveletSource', "residual", ...
    @(value) any(strcmpi(string(value), ["eventSignal", "motionEnvelope", "residual"])));

addParameter(inputParserObject, 'WaveletFrequencyLimitsHz', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) > 0 && value(1) < value(2)));

addParameter(inputParserObject, 'BaselineWindowSeconds', [], ...
    @(value) isempty(value) || (isnumeric(value) && isscalar(value) && value > 0));

addParameter(inputParserObject, 'NoiseWindowSeconds', 30, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'ThresholdSigma', [], ...
    @(value) isempty(value) || (isnumeric(value) && isscalar(value) && value > 0));

addParameter(inputParserObject, 'CompoundSubpeakThresholdSigma', [], ...
    @(value) isempty(value) || (isnumeric(value) && isscalar(value) && value > 0));

addParameter(inputParserObject, 'CompoundSubpeakMinDistanceSeconds', [], ...
    @(value) isempty(value) || (isnumeric(value) && isscalar(value) && value > 0));

addParameter(inputParserObject, 'WaveletColorPercentile', 99, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0 && value <= 100);

addParameter(inputParserObject, 'ShowWaveletEventLines', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'WindowSeconds', [], ...
    @(value) isempty(value) || (isnumeric(value) && isvector(value) && numel(value) == 2 && value(1) < value(2)));

addParameter(inputParserObject, 'CreateReviewPage', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'CreateAcceptedWaveletFigure', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'ExportPng', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'ExportFig', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'SavePlotOutput', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'CloseFigure', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'FigurePosition', [80 70 1500 980], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 4);

addParameter(inputParserObject, 'ReviewFigurePosition', [80 70 1500 900], ...
    @(value) isnumeric(value) && isvector(value) && numel(value) == 4);

parse(inputParserObject, sessionFolder, varargin{:});
options = inputParserObject.Results;

sessionFolder = char(string(options.sessionFolder));
if ~isfolder(sessionFolder)
    error('createEmovereSessionVisualizations:MissingSessionFolder', ...
        'Session folder not found: %s', sessionFolder);
end

repoRoot = LF_inferRepoRoot();
addpath(fullfile(repoRoot, 'CODE', 'ACCELEROMETER'));
addpath(fullfile(repoRoot, 'CODE', 'ANALYSIS'));

metaPath = LF_requireFile(sessionFolder, 'meta.json');
summaryPath = LF_requireFile(sessionFolder, 'lar_summary.json');
diagnosticsPath = LF_requireFile(sessionFolder, 'lar_diagnostics.csv');
onlineDiagnosticsPath = fullfile(sessionFolder, 'online_lar_diagnostics.csv');
onlineEventsPath = fullfile(sessionFolder, 'online_lar_events.csv');
batchEventsPath = fullfile(sessionFolder, 'lar_events.csv');

meta = jsondecode(fileread(metaPath));
larSummary = jsondecode(fileread(summaryPath));
diagnostics = readtable(diagnosticsPath, ...
    'TextType', 'string', 'VariableNamingRule', 'preserve');
onlineDiagnostics = LF_readOptionalTable(onlineDiagnosticsPath);
onlineEvents = LF_readOptionalTable(onlineEventsPath);
batchEvents = LF_readOptionalTable(batchEventsPath);

LF_validateDiagnosticsTable(diagnostics);

sessionID = LF_getStringField(meta, 'session_id', 'emovere_session');
focusSource = LF_getStringField(meta, 'focus_source', 'source');
safeStem = LF_safeFileStem(sessionID + "_" + focusSource);
if strlength(string(options.OutputStem)) > 0
    safeStem = char(string(options.OutputStem));
else
    safeStem = char(safeStem);
end

outputRoot = char(string(options.OutputRoot));
if isempty(strtrim(outputRoot))
    outputRoot = fullfile(repoRoot, 'scratch', 'emovere_sessions', safeStem);
end
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

[motionData, preprocessing] = LF_buildMotionData(diagnostics, meta, larSummary, ...
    diagnosticsPath, logical(options.ResampleToUniformTime));

motionDataPath = fullfile(outputRoot, sprintf('%s_motionData.mat', safeStem));
save(motionDataPath, 'motionData');

baselineWindowSeconds = LF_resolveOption(options.BaselineWindowSeconds, ...
    larSummary, {'params', 'local_baseline_window_seconds'}, 5);
thresholdSigma = LF_resolveOption(options.ThresholdSigma, ...
    larSummary, {'params', 'within_lar_event_threshold_sigma'}, 4);
compoundSubpeakThresholdSigma = LF_resolveOption(options.CompoundSubpeakThresholdSigma, ...
    larSummary, {'params', 'within_lar_prominence_sigma'}, 2);
compoundSubpeakMinDistanceSeconds = LF_resolveOption(options.CompoundSubpeakMinDistanceSeconds, ...
    larSummary, {'params', 'minimum_event_distance_seconds'}, 0.3);
waveletFrequencyLimitsHz = LF_resolveWaveletLimits(options.WaveletFrequencyLimitsHz, ...
    larSummary, motionData.meta.sampleRateHz);

acceptedPngPath = "";
acceptedFigPath = "";
reviewPngPath = "";
reviewFigPath = "";
if logical(options.ExportPng) && logical(options.CreateAcceptedWaveletFigure)
    acceptedPngPath = string(fullfile(outputRoot, sprintf('%s_accepted_residual_wavelets.png', safeStem)));
end
if logical(options.ExportFig) && logical(options.CreateAcceptedWaveletFigure)
    acceptedFigPath = string(fullfile(outputRoot, sprintf('%s_accepted_residual_wavelets.fig', safeStem)));
end
if logical(options.ExportPng) && logical(options.CreateReviewPage)
    reviewPngPath = string(fullfile(outputRoot, sprintf('%s_recorded_trial_review.png', safeStem)));
end
if logical(options.ExportFig) && logical(options.CreateReviewPage)
    reviewFigPath = string(fullfile(outputRoot, sprintf('%s_recorded_trial_review.fig', safeStem)));
end

figureTitle = sprintf('Emovere residual-wavelet view: %s | %s', ...
    char(sessionID), char(focusSource));

[figureHandle, plotOutput] = plotEnvelopeEventsWithNoiseBand(motionDataPath, ...
    'BaselineWindowSeconds', baselineWindowSeconds, ...
    'NoiseWindowSeconds', options.NoiseWindowSeconds, ...
    'ThresholdSigma', thresholdSigma, ...
    'CompoundSubpeakThresholdSigma', compoundSubpeakThresholdSigma, ...
    'CompoundSubpeakMinDistanceSeconds', compoundSubpeakMinDistanceSeconds, ...
    'WindowSeconds', options.WindowSeconds, ...
    'ShowMotionEnvelopePanel', logical(options.CreateAcceptedWaveletFigure), ...
    'ShowSlowEnvelope', logical(options.CreateAcceptedWaveletFigure), ...
    'ShowLongEnvelopeMeanPanel', logical(options.CreateAcceptedWaveletFigure), ...
    'WaveletSource', options.WaveletSource, ...
    'ShowWavelet', true, ...
    'ShowWaveletBandPower', logical(options.CreateAcceptedWaveletFigure), ...
    'WaveletFrequencyLimitsHz', waveletFrequencyLimitsHz, ...
    'UseWaveletFrequencyLimits', true, ...
    'WaveletColorPercentile', options.WaveletColorPercentile, ...
    'ShowWaveletEventLines', logical(options.ShowWaveletEventLines), ...
    'FigureTitle', figureTitle, ...
    'FigurePosition', options.FigurePosition, ...
    'OutputPngPath', acceptedPngPath, ...
    'OutputFigPath', acceptedFigPath);

reviewFigureHandle = [];
if logical(options.CreateReviewPage)
    reviewFigureHandle = LF_makeRecordedTrialReviewPage( ...
        diagnostics, onlineDiagnostics, onlineEvents, batchEvents, motionData, ...
        plotOutput, meta, larSummary, options, reviewPngPath, reviewFigPath);
end

plotOutputPath = "";
if logical(options.SavePlotOutput)
    plotOutputForSave = plotOutput;
    if isfield(plotOutputForSave, 'figureHandle')
        plotOutputForSave = rmfield(plotOutputForSave, 'figureHandle');
    end
    plotOutputPath = string(fullfile(outputRoot, sprintf('%s_plotOutput.mat', safeStem)));
    save(plotOutputPath, 'plotOutputForSave', '-v7.3');
end

visualizationOutput = struct();
visualizationOutput.sessionFolder = string(sessionFolder);
visualizationOutput.outputRoot = string(outputRoot);
visualizationOutput.outputStem = string(safeStem);
visualizationOutput.motionDataPath = string(motionDataPath);
visualizationOutput.pngPath = LF_primaryPath(reviewPngPath, acceptedPngPath);
visualizationOutput.figPath = LF_primaryPath(reviewFigPath, acceptedFigPath);
visualizationOutput.reviewPngPath = reviewPngPath;
visualizationOutput.reviewFigPath = reviewFigPath;
visualizationOutput.acceptedWaveletPngPath = acceptedPngPath;
visualizationOutput.acceptedWaveletFigPath = acceptedFigPath;
visualizationOutput.plotOutputPath = plotOutputPath;
visualizationOutput.meta = meta;
visualizationOutput.larSummary = larSummary;
visualizationOutput.preprocessing = preprocessing;
visualizationOutput.options = struct( ...
    'baselineWindowSeconds', baselineWindowSeconds, ...
    'noiseWindowSeconds', options.NoiseWindowSeconds, ...
    'thresholdSigma', thresholdSigma, ...
    'compoundSubpeakThresholdSigma', compoundSubpeakThresholdSigma, ...
    'compoundSubpeakMinDistanceSeconds', compoundSubpeakMinDistanceSeconds, ...
    'waveletSource', string(options.WaveletSource), ...
    'waveletFrequencyLimitsHz', waveletFrequencyLimitsHz);
visualizationOutput.plotOutput = plotOutput;
visualizationOutput.figureHandle = figureHandle;
visualizationOutput.reviewFigureHandle = reviewFigureHandle;

if logical(options.CloseFigure) || ~logical(options.CreateAcceptedWaveletFigure)
    close(figureHandle);
    visualizationOutput.figureHandle = [];
    if isfield(visualizationOutput.plotOutput, 'figureHandle')
        visualizationOutput.plotOutput = rmfield(visualizationOutput.plotOutput, 'figureHandle');
    end
end
if logical(options.CloseFigure) && ~isempty(reviewFigureHandle)
    close(reviewFigureHandle);
    visualizationOutput.reviewFigureHandle = [];
end
end

function repoRoot = LF_inferRepoRoot()
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function filePath = LF_requireFile(folderPath, fileName)
filePath = fullfile(folderPath, fileName);
if ~isfile(filePath)
    error('createEmovereSessionVisualizations:MissingFile', ...
        'Required Emovere export file not found: %s', filePath);
end
end

function tableData = LF_readOptionalTable(filePath)
if isfile(filePath)
    tableData = readtable(filePath, 'TextType', 'string', 'VariableNamingRule', 'preserve');
else
    tableData = table();
end
end

function LF_validateDiagnosticsTable(diagnostics)
requiredVariables = {'wall_ms', 'motion_score'};
missingVariables = setdiff(requiredVariables, diagnostics.Properties.VariableNames);
if ~isempty(missingVariables)
    error('createEmovereSessionVisualizations:BadDiagnosticsTable', ...
        'lar_diagnostics.csv is missing required column(s): %s', ...
        strjoin(missingVariables, ', '));
end
if height(diagnostics) < 10
    error('createEmovereSessionVisualizations:TooFewSamples', ...
        'lar_diagnostics.csv must contain at least 10 samples.');
end
end

function figureHandle = LF_makeRecordedTrialReviewPage(diagnostics, onlineDiagnostics, onlineEvents, ...
    batchEvents, motionData, plotOutput, meta, larSummary, options, pngPath, figPath)
figureHandle = figure('Color', 'w', 'Position', options.ReviewFigurePosition);
tiledLayoutHandle = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

sessionID = LF_getStringField(meta, 'session_id', 'unknown');
focusSource = LF_getStringField(meta, 'focus_source', 'unknown');
sessionMode = LF_getStringField(meta, 'session_mode', 'unknown');
title(tiledLayoutHandle, sprintf('Emovere recorded-trial review: %s | %s', sessionID, focusSource), ...
    'Interpreter', 'none', 'FontSize', 16, 'FontWeight', 'bold');
subtitle(tiledLayoutHandle, sprintf('%s mode | envelope, detector residual, accepted residual CWT', sessionMode), ...
    'Interpreter', 'none', 'FontSize', 10);

timeSec = LF_tableTimeSec(diagnostics);
windowSeconds = LF_resolveDisplayWindow(options.WindowSeconds, timeSec);

motionAxes = nexttile(tiledLayoutHandle);
LF_plotMotionPanel(motionAxes, diagnostics, larSummary, windowSeconds);

residualAxes = nexttile(tiledLayoutHandle);
eventTimeSec = LF_plotResidualPanel(residualAxes, diagnostics, onlineDiagnostics, onlineEvents, ...
    batchEvents, larSummary, windowSeconds);

waveletAxes = nexttile(tiledLayoutHandle);
LF_plotResidualWaveletPanel(waveletAxes, plotOutput, windowSeconds, eventTimeSec);

linkaxes([motionAxes residualAxes waveletAxes], 'x');
xlim(motionAxes, windowSeconds);

if strlength(string(pngPath)) > 0
    exportgraphics(figureHandle, char(string(pngPath)), 'Resolution', 220);
end
if strlength(string(figPath)) > 0
    savefig(figureHandle, char(string(figPath)));
end
end

function LF_plotMotionPanel(axesHandle, diagnostics, larSummary, windowSeconds)
timeSec = LF_tableTimeSec(diagnostics);
motionScore = double(diagnostics.motion_score);
keep = LF_windowMask(timeSec, windowSeconds);

hold(axesHandle, 'on');
plot(axesHandle, timeSec(keep), motionScore(keep), ...
    'Color', [0.02 0.02 0.02], 'LineWidth', 0.9, 'DisplayName', 'motion score');

if ismember('lar_regime_score', diagnostics.Properties.VariableNames)
    larRegimeScore = double(diagnostics.lar_regime_score);
    plot(axesHandle, timeSec(keep), larRegimeScore(keep), ...
        'Color', [0.10 0.35 0.65], 'LineWidth', 1.2, 'DisplayName', 'LAR regime score');
end

exitThreshold = LF_resolveOption([], larSummary, {'lar_exit_threshold'}, NaN);
if isfinite(exitThreshold)
    yline(axesHandle, exitThreshold, '--', ...
        sprintf('LAR exit %.2f', exitThreshold), ...
        'Color', [0.82 0.45 0.05], 'HandleVisibility', 'off');
end

grid(axesHandle, 'on');
xlim(axesHandle, windowSeconds);
ylabel(axesHandle, 'motion score');
title(axesHandle, 'Session motion envelope and LAR-regime score', 'FontWeight', 'normal');

if ismember('is_lar', diagnostics.Properties.VariableNames)
    isLar = LF_toLogicalVector(diagnostics.is_lar);
    LF_plotMaskBouts(axesHandle, timeSec, ~isLar, windowSeconds, [0.97 0.82 0.58], 0.14);
    LF_sendPatchesToBack(axesHandle);
end

legend(axesHandle, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
hold(axesHandle, 'off');
end

function eventTimeSec = LF_plotResidualPanel(axesHandle, diagnostics, onlineDiagnostics, onlineEvents, ...
    batchEvents, larSummary, windowSeconds)
[timeSec, residual, threshold, sourceLabel] = LF_selectResidualTrace(diagnostics, onlineDiagnostics, larSummary);
keep = LF_windowMask(timeSec, windowSeconds);

hold(axesHandle, 'on');
plot(axesHandle, timeSec(keep), residual(keep), ...
    'Color', [0.02 0.02 0.02], 'LineWidth', 0.9, 'DisplayName', sourceLabel);
if ~isempty(threshold)
    plot(axesHandle, timeSec(keep), threshold(keep), ...
        'Color', [0.45 0.45 0.45], 'LineStyle', '--', 'LineWidth', 1.0, ...
        'DisplayName', 'within-LAR threshold');
end

[eventTimeSec, eventPeakValue, eventLabel] = LF_selectEventPeaks(onlineEvents, batchEvents, diagnostics);
eventKeep = LF_windowMask(eventTimeSec, windowSeconds);
if any(eventKeep)
    scatter(axesHandle, eventTimeSec(eventKeep), eventPeakValue(eventKeep), 24, ...
        [0.05 0.35 0.70], 'o', ...
        'MarkerFaceColor', [0.05 0.35 0.70], ...
        'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeAlpha', 0.55, ...
        'DisplayName', eventLabel);
end

if ~isempty(onlineDiagnostics) && ismember('online_state', onlineDiagnostics.Properties.VariableNames)
    onlineTimeSec = LF_tableTimeSec(onlineDiagnostics, double(diagnostics.wall_ms(1)));
    stateNames = string(onlineDiagnostics.online_state);
    larMask = stateNames == "LAR";
    calibrationMask = stateNames == "CALIBRATING";
    LF_plotMaskBouts(axesHandle, onlineTimeSec, larMask, windowSeconds, [0.65 0.86 0.65], 0.10);
    LF_plotMaskBouts(axesHandle, onlineTimeSec, calibrationMask, windowSeconds, [0.72 0.72 0.72], 0.12);
    LF_sendPatchesToBack(axesHandle);
end

grid(axesHandle, 'on');
xlim(axesHandle, windowSeconds);
ylabel(axesHandle, 'residual');
title(axesHandle, 'Detector residual and accepted events', 'FontWeight', 'normal');
legend(axesHandle, 'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
hold(axesHandle, 'off');
end

function LF_plotResidualWaveletPanel(axesHandle, plotOutput, windowSeconds, eventTimeSec)
if ~isfield(plotOutput, 'wavelet') || ~isfield(plotOutput.wavelet, 'magnitude') || isempty(plotOutput.wavelet.magnitude)
    text(axesHandle, 0.5, 0.5, 'No residual wavelet output available.', ...
        'Units', 'normalized', 'HorizontalAlignment', 'center');
    return;
end

waveletOutput = plotOutput.wavelet;
waveletTimeSec = waveletOutput.timeSec(:);
if max(waveletTimeSec, [], 'omitnan') <= diff(windowSeconds) + LF_halfTimeStep(waveletTimeSec) && windowSeconds(1) > 0
    waveletTimeSec = waveletTimeSec + windowSeconds(1);
end

imagesc(axesHandle, waveletTimeSec, waveletOutput.frequencyHz, waveletOutput.magnitude);
axis(axesHandle, 'xy');
colormap(axesHandle, turbo);
colorbar(axesHandle);
ylim(axesHandle, waveletOutput.frequencyLimitsHz);
xlim(axesHandle, windowSeconds);
hold(axesHandle, 'on');
eventTimeSec = eventTimeSec(:);
eventTimeSec = eventTimeSec(LF_windowMask(eventTimeSec, windowSeconds));
for eventIndex = 1:numel(eventTimeSec)
    xline(axesHandle, eventTimeSec(eventIndex), '-', ...
        'Color', [0.95 0.40 0.15], 'HandleVisibility', 'off');
end
grid(axesHandle, 'on');
xlabel(axesHandle, 'time from session start (s)');
ylabel(axesHandle, 'frequency (Hz)');
title(axesHandle, sprintf('Accepted residual CWT: %s', char(string(waveletOutput.waveletName))), ...
    'FontWeight', 'normal');
hold(axesHandle, 'off');
end

function [timeSec, residual, threshold, sourceLabel] = LF_selectResidualTrace(diagnostics, onlineDiagnostics, larSummary)
if ~isempty(onlineDiagnostics) && all(ismember({'wall_ms', 'lar_residual'}, onlineDiagnostics.Properties.VariableNames))
    timeSec = LF_tableTimeSec(onlineDiagnostics, double(diagnostics.wall_ms(1)));
    residual = double(onlineDiagnostics.lar_residual);
    sourceLabel = 'online residual';
    if ismember('within_lar_threshold', onlineDiagnostics.Properties.VariableNames)
        threshold = double(onlineDiagnostics.within_lar_threshold);
    else
        threshold = [];
    end
    return;
end

timeSec = LF_tableTimeSec(diagnostics);
if ismember('lar_residual', diagnostics.Properties.VariableNames)
    residual = double(diagnostics.lar_residual);
    sourceLabel = 'batch residual';
else
    baseline = double(diagnostics.local_baseline);
    residual = max(double(diagnostics.motion_score) - baseline, 0);
    sourceLabel = 'computed residual';
end
thresholdValue = LF_resolveOption([], larSummary, {'within_lar_threshold'}, NaN);
if isfinite(thresholdValue)
    threshold = thresholdValue .* ones(size(residual));
else
    threshold = [];
end
end

function [eventTimeSec, eventPeakValue, eventLabel] = LF_selectEventPeaks(onlineEvents, batchEvents, diagnostics)
sessionStartMs = double(diagnostics.wall_ms(1));
if ~isempty(onlineEvents) && all(ismember({'peak_ms', 'residual_peak'}, onlineEvents.Properties.VariableNames))
    eventTimeSec = (double(onlineEvents.peak_ms) - sessionStartMs) ./ 1000;
    eventPeakValue = double(onlineEvents.residual_peak);
    eventLabel = 'online accepted event';
    return;
end
if ~isempty(batchEvents) && all(ismember({'peak_ms', 'residual_peak'}, batchEvents.Properties.VariableNames))
    eventTimeSec = (double(batchEvents.peak_ms) - sessionStartMs) ./ 1000;
    eventPeakValue = double(batchEvents.residual_peak);
    eventLabel = 'batch event';
    return;
end
eventTimeSec = zeros(0, 1);
eventPeakValue = zeros(0, 1);
eventLabel = 'event';
end

function timeSec = LF_tableTimeSec(tableData, sessionStartMs)
if nargin < 2
    sessionStartMs = double(tableData.wall_ms(1));
end
timeSec = (double(tableData.wall_ms) - sessionStartMs) ./ 1000;
timeSec = timeSec(:);
end

function windowSeconds = LF_resolveDisplayWindow(userWindowSeconds, timeSec)
if isempty(userWindowSeconds)
    windowSeconds = [min(timeSec, [], 'omitnan') max(timeSec, [], 'omitnan')];
else
    windowSeconds = double(userWindowSeconds(:).');
end
end

function keep = LF_windowMask(timeSec, windowSeconds)
keep = timeSec >= windowSeconds(1) & timeSec <= windowSeconds(2);
end

function LF_plotMaskBouts(axesHandle, timeSec, mask, windowSeconds, colorValue, faceAlpha)
if isempty(mask) || numel(mask) ~= numel(timeSec) || ~any(mask)
    return;
end

yl = ylim(axesHandle);
changeVector = diff([false; mask(:); false]);
starts = find(changeVector == 1);
ends = find(changeVector == -1) - 1;
halfStep = LF_halfTimeStep(timeSec);

for boutIndex = 1:numel(starts)
    startSec = timeSec(starts(boutIndex)) - halfStep;
    endSec = timeSec(ends(boutIndex)) + halfStep;
    if endSec < windowSeconds(1) || startSec > windowSeconds(2)
        continue;
    end
    patch(axesHandle, [startSec endSec endSec startSec], ...
        [yl(1) yl(1) yl(2) yl(2)], colorValue, ...
        'FaceAlpha', faceAlpha, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end
end

function halfStep = LF_halfTimeStep(timeSec)
timeDelta = diff(timeSec);
timeDelta = timeDelta(isfinite(timeDelta) & timeDelta > 0);
if isempty(timeDelta)
    halfStep = 0;
else
    halfStep = 0.5 .* median(timeDelta, 'omitnan');
end
end

function LF_sendPatchesToBack(axesHandle)
patchHandles = findobj(axesHandle, 'Type', 'patch');
for patchIndex = 1:numel(patchHandles)
    uistack(patchHandles(patchIndex), 'bottom');
end
end

function logicalVector = LF_toLogicalVector(values)
if islogical(values)
    logicalVector = values(:);
elseif isnumeric(values)
    logicalVector = values(:) ~= 0;
else
    textValues = lower(string(values(:)));
    logicalVector = textValues == "true" | textValues == "1" | textValues == "yes";
end
end

function outputPath = LF_primaryPath(primaryPath, fallbackPath)
if strlength(string(primaryPath)) > 0
    outputPath = primaryPath;
else
    outputPath = fallbackPath;
end
end

function [motionData, preprocessing] = LF_buildMotionData(diagnostics, meta, larSummary, ...
    diagnosticsPath, resampleToUniformTime)
rawTimeSec = (double(diagnostics.wall_ms) - double(diagnostics.wall_ms(1))) ./ 1000;
rawMotionScore = double(diagnostics.motion_score);

validMask = isfinite(rawTimeSec) & isfinite(rawMotionScore);
rawTimeSec = rawTimeSec(validMask);
rawMotionScore = rawMotionScore(validMask);

[rawTimeSec, sortIndex] = sort(rawTimeSec(:));
rawMotionScore = rawMotionScore(sortIndex);
[rawTimeSec, uniqueIndex] = unique(rawTimeSec, 'stable');
rawMotionScore = rawMotionScore(uniqueIndex);

if numel(rawTimeSec) < 10
    error('createEmovereSessionVisualizations:TooFewFiniteSamples', ...
        'The diagnostics table does not contain enough finite time/motion samples.');
end

timeStepSec = diff(rawTimeSec);
timeStepSec = timeStepSec(isfinite(timeStepSec) & timeStepSec > 0);
if isempty(timeStepSec)
    error('createEmovereSessionVisualizations:BadTimeVector', ...
        'Could not estimate sample rate from lar_diagnostics.wall_ms.');
end

medianStepSec = median(timeStepSec, 'omitnan');
sampleRateHz = 1 ./ medianStepSec;
largeGapCount = sum(timeStepSec > 3 .* medianStepSec);

if resampleToUniformTime
    timeSec = (0:medianStepSec:rawTimeSec(end)).';
    motionEnvelope = interp1(rawTimeSec, rawMotionScore, timeSec, 'linear', 'extrap');
    timeMode = "uniform median-step interpolation";
else
    timeSec = rawTimeSec(:);
    motionEnvelope = rawMotionScore(:);
    timeMode = "native diagnostic timestamps";
end

motionData = struct();
motionData.timeSec = timeSec(:);
motionData.motionEnvelope = motionEnvelope(:);
motionData.meta = struct();
motionData.meta.sampleRateHz = sampleRateHz;
motionData.meta.sessionID = LF_getStringField(meta, 'session_id', 'unknown');
motionData.meta.focusSource = LF_getStringField(meta, 'focus_source', 'unknown');
motionData.meta.sessionMode = LF_getStringField(meta, 'session_mode', 'unknown');
motionData.meta.sourceDiagnosticsPath = string(diagnosticsPath);
motionData.meta.sourceDetector = LF_getStringField(larSummary, 'detector', 'unknown');
motionData.meta.motionEnvelopeSource = "lar_diagnostics.motion_score";
motionData.meta.outputCreatedBy = string(mfilename);
motionData.meta.timeMode = timeMode;
motionData.meta.largeGapCount = largeGapCount;

preprocessing = struct();
preprocessing.nRawRows = height(diagnostics);
preprocessing.nFiniteUniqueSamples = numel(rawTimeSec);
preprocessing.nOutputSamples = numel(timeSec);
preprocessing.sampleRateHz = sampleRateHz;
preprocessing.medianStepSec = medianStepSec;
preprocessing.maxStepSec = max(timeStepSec);
preprocessing.largeGapCount = largeGapCount;
preprocessing.resampleToUniformTime = resampleToUniformTime;
preprocessing.timeMode = timeMode;
end

function value = LF_getStringField(inputStruct, fieldName, defaultValue)
if isstruct(inputStruct) && isfield(inputStruct, fieldName) && ~isempty(inputStruct.(fieldName))
    value = string(inputStruct.(fieldName));
else
    value = string(defaultValue);
end
end

function value = LF_resolveOption(userValue, configStruct, fieldPath, defaultValue)
if ~isempty(userValue)
    value = userValue;
    return;
end

value = defaultValue;
current = configStruct;
for pathIndex = 1:numel(fieldPath)
    fieldName = fieldPath{pathIndex};
    if ~isstruct(current) || ~isfield(current, fieldName)
        return;
    end
    current = current.(fieldName);
end

if isnumeric(current) && isscalar(current) && isfinite(current) && current > 0
    value = double(current);
end
end

function limitsHz = LF_resolveWaveletLimits(userValue, larSummary, sampleRateHz)
if ~isempty(userValue)
    limitsHz = double(userValue(:).');
else
    highHz = LF_resolveOption([], larSummary, {'params', 'bandpass_high_hz'}, 12);
    nyquistHz = sampleRateHz ./ 2;
    highHz = min(highHz, 0.95 .* nyquistHz);
    limitsHz = [0.1 highHz];
end

if limitsHz(2) >= sampleRateHz ./ 2
    limitsHz(2) = 0.95 .* sampleRateHz ./ 2;
end
if limitsHz(1) >= limitsHz(2)
    error('createEmovereSessionVisualizations:BadWaveletLimits', ...
        'WaveletFrequencyLimitsHz must fit below Nyquist. Requested [%.3f %.3f], sample rate %.3f Hz.', ...
        limitsHz(1), limitsHz(2), sampleRateHz);
end
end

function safeStem = LF_safeFileStem(textValue)
safeStem = regexprep(string(textValue), '[^A-Za-z0-9_-]+', '_');
safeStem = regexprep(safeStem, '_+', '_');
safeStem = strip(safeStem, '_');
if strlength(safeStem) == 0
    safeStem = "emovere_session";
end
end

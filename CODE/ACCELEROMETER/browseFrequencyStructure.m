function figureHandle = browseFrequencyStructure(varargin)
%BROWSEFREQUENCYSTRUCTURE Small GUI for envelope frequency inspection.
%
% figureHandle = browseFrequencyStructure()
%
% Purpose
%   Open a small GUI for selecting one saved Waseda magnitude MAT file and
%   launching `analyzeFrequencyStructure` with user-set parameters.
%
% Optional name-value inputs
%   'initialMatPath'         Optional MAT file to load at startup.
%   'initialFolder'          Optional folder used for the file chooser.
%   'maxFrequencyHz'         Default 3.0
%   'psdWindowSeconds'       Default 64.0
%   'psdOverlapFraction'     Default 0.50
%   'centerForFrequencyAnalysis' default true

%% Parse inputs
p = inputParser;
p.addParameter('initialMatPath', "", @(x) ischar(x) || isstring(x));
p.addParameter('initialFolder', "", @(x) ischar(x) || isstring(x));
p.addParameter('maxFrequencyHz', 3.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('psdWindowSeconds', 64.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
p.addParameter('psdOverlapFraction', 0.50, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
p.addParameter('centerForFrequencyAnalysis', true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});

initialMatPath = char(string(p.Results.initialMatPath));
initialFolder = char(string(p.Results.initialFolder));

%% Build GUI
figureHandle = uifigure('Name', 'Frequency Structure Browser', ...
    'Color', 'w', ...
    'Position', [100 100 1100 760]);

gridLayout = uigridlayout(figureHandle, [5, 4]);
gridLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x'};
gridLayout.ColumnWidth = {'fit', 220, 220, '1x'};
gridLayout.RowSpacing = 8;
gridLayout.ColumnSpacing = 8;
gridLayout.Padding = [10 10 10 10];

openButton = uibutton(gridLayout, ...
    'Text', 'Choose MAT file', ...
    'ButtonPushedFcn', @(src, event) LF_openMatFile(figureHandle));
openButton.Layout.Row = 1;
openButton.Layout.Column = 1;

analyzeButton = uibutton(gridLayout, ...
    'Text', 'Run analysis', ...
    'ButtonPushedFcn', @(src, event) LF_runAnalysis(figureHandle));
analyzeButton.Layout.Row = 1;
analyzeButton.Layout.Column = 2;

filePathField = uieditfield(gridLayout, 'text', ...
    'Editable', 'off', ...
    'Placeholder', 'No magnitude MAT file selected');
filePathField.Layout.Row = 1;
filePathField.Layout.Column = [3 4];

maxFrequencyLabel = uilabel(gridLayout, 'Text', 'Max frequency (Hz)');
maxFrequencyLabel.Layout.Row = 2;
maxFrequencyLabel.Layout.Column = 1;

maxFrequencyField = uieditfield(gridLayout, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', 'off', ...
    'Value', p.Results.maxFrequencyHz);
maxFrequencyField.Layout.Row = 2;
maxFrequencyField.Layout.Column = 2;

psdWindowLabel = uilabel(gridLayout, 'Text', 'PSD window (s)');
psdWindowLabel.Layout.Row = 2;
psdWindowLabel.Layout.Column = 3;

psdWindowField = uieditfield(gridLayout, 'numeric', ...
    'Limits', [0 Inf], ...
    'LowerLimitInclusive', 'off', ...
    'Value', p.Results.psdWindowSeconds);
psdWindowField.Layout.Row = 2;
psdWindowField.Layout.Column = 4;

psdOverlapLabel = uilabel(gridLayout, 'Text', 'PSD overlap fraction');
psdOverlapLabel.Layout.Row = 3;
psdOverlapLabel.Layout.Column = 1;

psdOverlapField = uieditfield(gridLayout, 'numeric', ...
    'Limits', [0 0.99], ...
    'Value', p.Results.psdOverlapFraction);
psdOverlapField.Layout.Row = 3;
psdOverlapField.Layout.Column = 2;

centerCheckBox = uicheckbox(gridLayout, ...
    'Text', 'Median-center for frequency analysis', ...
    'Value', logical(p.Results.centerForFrequencyAnalysis));
centerCheckBox.Layout.Row = 3;
centerCheckBox.Layout.Column = [3 4];

summaryLabel = uilabel(gridLayout, ...
    'Text', 'No file loaded.', ...
    'WordWrap', 'on', ...
    'HorizontalAlignment', 'left');
summaryLabel.Layout.Row = 4;
summaryLabel.Layout.Column = [1 4];

previewAxes = uiaxes(gridLayout);
previewAxes.Layout.Row = 5;
previewAxes.Layout.Column = [1 4];
grid(previewAxes, 'on');
xlabel(previewAxes, 'Time (s)');
ylabel(previewAxes, 'Motion envelope');
title(previewAxes, 'Load a magnitude MAT file', 'Interpreter', 'none');

figureHandle.UserData = struct();
figureHandle.UserData.motionData = [];
figureHandle.UserData.currentMatPath = "";
figureHandle.UserData.currentFolder = initialFolder;
figureHandle.UserData.filePathField = filePathField;
figureHandle.UserData.maxFrequencyField = maxFrequencyField;
figureHandle.UserData.psdWindowField = psdWindowField;
figureHandle.UserData.psdOverlapField = psdOverlapField;
figureHandle.UserData.centerCheckBox = centerCheckBox;
figureHandle.UserData.summaryLabel = summaryLabel;
figureHandle.UserData.previewAxes = previewAxes;

%% Load initial file if requested
if ~isempty(initialMatPath)
    LF_loadMatFile(figureHandle, initialMatPath);
end
end

function LF_openMatFile(figureHandle)
currentFolder = figureHandle.UserData.currentFolder;
if isempty(currentFolder) || ~isfolder(currentFolder)
    [fileName, folderPath] = uigetfile('*.mat', 'Select magnitude MAT file');
else
    [fileName, folderPath] = uigetfile(fullfile(currentFolder, '*.mat'), 'Select magnitude MAT file');
end

if isequal(fileName, 0)
    return;
end

matPath = fullfile(folderPath, fileName);
LF_loadMatFile(figureHandle, matPath);
end

function LF_loadMatFile(figureHandle, matPath)
loadedFile = load(matPath, 'motionData');
if ~isfield(loadedFile, 'motionData')
    uialert(figureHandle, ...
        'Selected MAT file does not contain a `motionData` structure.', ...
        'Missing motionData');
    return;
end

motionData = loadedFile.motionData;
if ~isstruct(motionData) || ~isfield(motionData, 'timeSec') || ~isfield(motionData, 'motionEnvelope')
    uialert(figureHandle, ...
        'Selected MAT file does not have the expected magnitude structure.', ...
        'Invalid motionData');
    return;
end

figureHandle.UserData.motionData = motionData;
figureHandle.UserData.currentMatPath = string(matPath);
figureHandle.UserData.currentFolder = fileparts(matPath);
figureHandle.UserData.filePathField.Value = matPath;
LF_updatePreview(figureHandle);
end

function LF_updatePreview(figureHandle)
motionData = figureHandle.UserData.motionData;
if isempty(motionData)
    return;
end

timeSec = motionData.timeSec(:);
motionEnvelope = motionData.motionEnvelope(:);
previewAxes = figureHandle.UserData.previewAxes;
summaryLabel = figureHandle.UserData.summaryLabel;

plot(previewAxes, timeSec, motionEnvelope, 'k', 'LineWidth', 1.0);
grid(previewAxes, 'on');
xlabel(previewAxes, 'Time (s)');
ylabel(previewAxes, 'Motion envelope');
title(previewAxes, char(figureHandle.UserData.currentMatPath), 'Interpreter', 'none');

durationSec = timeSec(end) - timeSec(1);
nSamples = numel(motionEnvelope);
sampleRateText = 'sample rate unavailable';

if isfield(motionData, 'meta') && isstruct(motionData.meta) ...
        && isfield(motionData.meta, 'sampleRateHz') ...
        && ~isempty(motionData.meta.sampleRateHz) ...
        && isfinite(motionData.meta.sampleRateHz)
    sampleRateText = sprintf('%.2f Hz', motionData.meta.sampleRateHz);
end

summaryLabel.Text = sprintf('duration %.2f s | %s | n = %d', ...
    durationSec, sampleRateText, nSamples);
end

function LF_runAnalysis(figureHandle)
currentMatPath = char(string(figureHandle.UserData.currentMatPath));
if isempty(currentMatPath)
    uialert(figureHandle, ...
        'Choose a magnitude MAT file before running the analysis.', ...
        'No file selected');
    return;
end

maxFrequencyHz = figureHandle.UserData.maxFrequencyField.Value;
psdWindowSeconds = figureHandle.UserData.psdWindowField.Value;
psdOverlapFraction = figureHandle.UserData.psdOverlapField.Value;
centerForFrequencyAnalysis = figureHandle.UserData.centerCheckBox.Value;

if ~(isfinite(maxFrequencyHz) && maxFrequencyHz > 0)
    uialert(figureHandle, 'Max frequency must be positive.', 'Invalid max frequency');
    return;
end

if ~(isfinite(psdWindowSeconds) && psdWindowSeconds > 0)
    uialert(figureHandle, 'PSD window must be positive.', 'Invalid PSD window');
    return;
end

if ~(isfinite(psdOverlapFraction) && psdOverlapFraction >= 0 && psdOverlapFraction < 1)
    uialert(figureHandle, 'PSD overlap fraction must be in [0, 1).', 'Invalid PSD overlap');
    return;
end

drawnow;

try
    analyzeFrequencyStructure(currentMatPath, ...
        'MaxFrequencyHz', maxFrequencyHz, ...
        'PsdWindowSeconds', psdWindowSeconds, ...
        'PsdOverlapFraction', psdOverlapFraction, ...
        'CenterForFrequencyAnalysis', centerForFrequencyAnalysis);
catch analysisError
    uialert(figureHandle, analysisError.message, 'Analysis failed');
end
end

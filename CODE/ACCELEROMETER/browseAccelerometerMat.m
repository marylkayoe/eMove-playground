function figureHandle = browseAccelerometerMat(varargin)
%BROWSEACCELEROMETERMAT Browse one accelerometer MAT file in raw or centered form.
%
% Purpose
%   Open a small MATLAB GUI for browsing one converted accelerometer MAT
%   file. The GUI can display the XYZ traces either in raw form or after
%   simple column-wise mean centering.
%
% Name-value options
%   initialMatPath - Optional path to an accelerometer MAT file to load at
%                    startup.
%
% Output
%   figureHandle   - Handle to the created GUI figure.
%
% Important assumptions
%   The MAT file contains an `accData` structure with fields `acc` and
%   `timeSec`, following the output of the Waseda accelerometer import
%   workflow.

%% Parse inputs
p = inputParser;
p.addParameter('initialMatPath', "", @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

initialMatPath = char(string(p.Results.initialMatPath));

%% Build GUI
figureHandle = uifigure('Name', 'Accelerometer Browser', ...
    'Color', 'w', ...
    'Position', [100 100 1100 700]);

gridLayout = uigridlayout(figureHandle, [3, 3]);
gridLayout.RowHeight = {'fit', 'fit', '1x'};
gridLayout.ColumnWidth = {'fit', 'fit', '1x'};
gridLayout.RowSpacing = 8;
gridLayout.ColumnSpacing = 8;
gridLayout.Padding = [10 10 10 10];

openButton = uibutton(gridLayout, ...
    'Text', 'Open MAT file', ...
    'ButtonPushedFcn', @(src, event) LF_openMatFile(figureHandle));
openButton.Layout.Row = 1;
openButton.Layout.Column = 1;

modeDropDown = uidropdown(gridLayout, ...
    'Items', {'Raw', 'Centered'}, ...
    'Value', 'Raw', ...
    'ValueChangedFcn', @(src, event) LF_updateDisplay(figureHandle));
modeDropDown.Layout.Row = 1;
modeDropDown.Layout.Column = 2;

summaryLabel = uilabel(gridLayout, ...
    'Text', 'No file loaded.', ...
    'WordWrap', 'on', ...
    'HorizontalAlignment', 'left');
summaryLabel.Layout.Row = 2;
summaryLabel.Layout.Column = [1 3];

axesHandle = uiaxes(gridLayout);
axesHandle.Layout.Row = 3;
axesHandle.Layout.Column = [1 3];
grid(axesHandle, 'on');
xlabel(axesHandle, 'Time (s)');
ylabel(axesHandle, 'Acceleration (g)');
title(axesHandle, 'Load an accelerometer MAT file', 'Interpreter', 'none');

figureHandle.UserData = struct();
figureHandle.UserData.accData = [];
figureHandle.UserData.currentMatPath = "";
figureHandle.UserData.modeDropDown = modeDropDown;
figureHandle.UserData.summaryLabel = summaryLabel;
figureHandle.UserData.axesHandle = axesHandle;

%% Load initial file if requested
if ~isempty(initialMatPath)
    LF_loadMatFile(figureHandle, initialMatPath);
end
end

function LF_openMatFile(figureHandle)
%LF_OPENMATFILE Open one accelerometer MAT file chosen by the user.

[fileName, folderPath] = uigetfile('*.mat', 'Select accelerometer MAT file');
if isequal(fileName, 0)
    return;
end

matPath = fullfile(folderPath, fileName);
LF_loadMatFile(figureHandle, matPath);
end

function LF_loadMatFile(figureHandle, matPath)
%LF_LOADMATFILE Load one MAT file into the browser state.

loadedFile = load(matPath, 'accData');
if ~isfield(loadedFile, 'accData')
    uialert(figureHandle, ...
        'Selected MAT file does not contain an `accData` structure.', ...
        'Missing accData');
    return;
end

accData = loadedFile.accData;
if ~isstruct(accData) || ~isfield(accData, 'acc') || ~isfield(accData, 'timeSec')
    uialert(figureHandle, ...
        'Selected MAT file does not have the expected accelerometer structure.', ...
        'Invalid accData');
    return;
end

figureHandle.UserData.accData = accData;
figureHandle.UserData.currentMatPath = string(matPath);
LF_updateDisplay(figureHandle);
end

function LF_updateDisplay(figureHandle)
%LF_UPDATEDISPLAY Update the accelerometer plot and metadata text.

accData = figureHandle.UserData.accData;
if isempty(accData)
    return;
end

axesHandle = figureHandle.UserData.axesHandle;
summaryLabel = figureHandle.UserData.summaryLabel;
displayMode = figureHandle.UserData.modeDropDown.Value;

acc = accData.acc;
timeSec = accData.timeSec;

if strcmp(displayMode, 'Centered')
    [accToPlot, meanAcc] = centerAccByMean(acc);
    modeText = sprintf('centered | mean = [%.4f %.4f %.4f]', meanAcc(1), meanAcc(2), meanAcc(3));
else
    accToPlot = acc;
    modeText = 'raw';
end

recordingLabel = 'Accelerometer recording';
sampleRateText = 'sample rate unavailable';
chunkText = 'single file';

if isfield(accData, 'meta') && isstruct(accData.meta)
    meta = accData.meta;

    if isfield(meta, 'outputMatPath') && strlength(string(meta.outputMatPath)) > 0
        [~, recordingLabel] = fileparts(char(string(meta.outputMatPath)));
    elseif isfield(meta, 'sourceCsvPath') && strlength(string(meta.sourceCsvPath)) > 0
        [~, nameOnly, extOnly] = fileparts(char(string(meta.sourceCsvPath)));
        recordingLabel = [nameOnly, extOnly];
    elseif isfield(meta, 'sourceCsvPaths') && ~isempty(meta.sourceCsvPaths)
        [~, nameOnly, extOnly] = fileparts(char(string(meta.sourceCsvPaths(1))));
        recordingLabel = [nameOnly, extOnly];
    end

    if isfield(meta, 'sampleRateHz') && ~isempty(meta.sampleRateHz) && ~isnan(meta.sampleRateHz)
        sampleRateText = sprintf('%.2f Hz', meta.sampleRateHz);
    end

    if isfield(meta, 'concatenatedChunks') && logical(meta.concatenatedChunks)
        chunkText = 'concatenated chunks';
    end
end

durationSec = timeSec(end) - timeSec(1);
nSamples = size(acc, 1);

plot(axesHandle, timeSec, accToPlot(:, 1), 'DisplayName', 'X');
hold(axesHandle, 'on');
plot(axesHandle, timeSec, accToPlot(:, 2), 'DisplayName', 'Y');
plot(axesHandle, timeSec, accToPlot(:, 3), 'DisplayName', 'Z');
hold(axesHandle, 'off');
grid(axesHandle, 'on');
xlabel(axesHandle, 'Time (s)');
ylabel(axesHandle, 'Acceleration (g)');
legend(axesHandle, 'Location', 'eastoutside');
title(axesHandle, recordingLabel, 'Interpreter', 'none');

summaryLabel.Text = sprintf('%s | duration %.2f s | %s | n = %d | %s', ...
    modeText, durationSec, sampleRateText, nSamples, chunkText);
end

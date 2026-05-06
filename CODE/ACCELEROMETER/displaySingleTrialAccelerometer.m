function figureHandle = displaySingleTrialAccelerometer(accData, varargin)
%DISPLAYSINGLETRIALACCELEROMETER Display one accelerometer recording.
%
% Purpose
%   Plot one accelerometer recording as a simple interactive time-series
%   figure with a short metadata summary above the panel.
%
% Inputs
%   accData    - Structure returned by `importWasedaAccelerometerCsv` or
%                loaded from a converted MAT file. Required fields are:
%                `acc`     : nSamples x 3 acceleration matrix [X Y Z] in g
%                `timeSec` : nSamples x 1 time vector in seconds
%
% Name-value options
%   figureName - Figure name shown in the MATLAB window title.
%                Default is 'Accelerometer Trial'.
%
% Output
%   figureHandle - Handle to the created MATLAB figure.
%
% Important assumptions
%   `accData.acc` contains three accelerometer columns ordered as X, Y, Z.
%   `accData.timeSec` is already in seconds and aligned with the rows of
%   `accData.acc`.

%% Parse inputs
p = inputParser;
p.addRequired('accData', @isstruct);
p.addParameter('figureName', 'Accelerometer Trial', @(x) ischar(x) || isstring(x));
p.parse(accData, varargin{:});

figureName = char(string(p.Results.figureName));

%% Check required fields and dimensions
if ~isfield(accData, 'acc')
    error('displaySingleTrialAccelerometer:MissingAcc', ...
        'accData must contain the field `acc`.');
end
if ~isfield(accData, 'timeSec')
    error('displaySingleTrialAccelerometer:MissingTimeSec', ...
        'accData must contain the field `timeSec`.');
end

acc = accData.acc;
timeSec = accData.timeSec;

if size(acc, 2) ~= 3
    error('displaySingleTrialAccelerometer:BadAccShape', ...
        'accData.acc must be an nSamples x 3 matrix.');
end
if size(timeSec, 1) ~= size(acc, 1)
    error('displaySingleTrialAccelerometer:LengthMismatch', ...
        'accData.timeSec must have one row per sample in accData.acc.');
end

%% Collect metadata for the title block
nSamples = size(acc, 1);
durationSec = timeSec(end) - timeSec(1);
sampleRateHz = NaN;
concatenatedChunks = false;
recordingLabel = 'Accelerometer recording';

if isfield(accData, 'meta') && isstruct(accData.meta)
    meta = accData.meta;

    if isfield(meta, 'sampleRateHz') && ~isempty(meta.sampleRateHz)
        sampleRateHz = meta.sampleRateHz;
    end
    if isfield(meta, 'concatenatedChunks') && ~isempty(meta.concatenatedChunks)
        concatenatedChunks = logical(meta.concatenatedChunks);
    end

    if isfield(meta, 'outputMatPath') && strlength(string(meta.outputMatPath)) > 0
        [~, recordingLabel] = fileparts(char(string(meta.outputMatPath)));
    elseif isfield(meta, 'sourceCsvPath') && strlength(string(meta.sourceCsvPath)) > 0
        [~, nameOnly, extOnly] = fileparts(char(string(meta.sourceCsvPath)));
        recordingLabel = [nameOnly, extOnly];
    elseif isfield(meta, 'sourceCsvPaths') && ~isempty(meta.sourceCsvPaths)
        [~, nameOnly, extOnly] = fileparts(char(string(meta.sourceCsvPaths(1))));
        recordingLabel = [nameOnly, extOnly];
    end
end

if isnan(sampleRateHz)
    sampleRateText = 'sample rate unavailable';
else
    sampleRateText = sprintf('%.2f Hz', sampleRateHz);
end

if concatenatedChunks
    chunkText = 'concatenated chunks';
else
    chunkText = 'single file';
end

titleLine1 = recordingLabel;
titleLine2 = sprintf('duration %.2f s | %s | n = %d | %s', ...
    durationSec, sampleRateText, nSamples, chunkText);

%% Plot accelerometer traces
figureHandle = figure('Name', figureName, 'Color', 'w');
tiledLayoutHandle = tiledlayout(1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axesHandle = nexttile(tiledLayoutHandle);

plot(axesHandle, timeSec, acc(:, 1), 'DisplayName', 'X');
hold(axesHandle, 'on');
plot(axesHandle, timeSec, acc(:, 2), 'DisplayName', 'Y');
plot(axesHandle, timeSec, acc(:, 3), 'DisplayName', 'Z');
hold(axesHandle, 'off');

xlabel(axesHandle, 'Time (s)');
ylabel(axesHandle, 'Acceleration (g)');
grid(axesHandle, 'on');
legend(axesHandle, 'Location', 'eastoutside');
sgtitle(tiledLayoutHandle, {titleLine1, titleLine2}, 'Interpreter', 'none');

%% plot quaternion data (in accData.qData) if available in the same axes, with a secondary y-axis on the right for the Euler angles
% use sensor fusion toolbox to convert quaternions to Euler angles and plot them in a second panel below the accelerometer data
if isfield(accData, 'quat') && ~isempty(accData.quat)
    qData = accData.quat;
    if size(qData, 2) == 4 && size(qData, 1) == size(acc, 1)

        quatObj = quaternion(qData(:, 1), qData(:, 2), qData(:, 3), qData(:, 4));
        eul = eulerd(quatObj, 'ZYX', 'frame'); % returns [yaw, pitch, roll] in degrees
        roll = eul(:, 3);
        pitch = eul(:, 2);
        yaw = eul(:, 1);
            
        yyaxis(axesHandle, 'right');
        ylabel(axesHandle, 'Angle (degrees)');
        plot(axesHandle, timeSec,roll, '-', 'DisplayName', 'Roll');
        hold(axesHandle, 'on');
        plot(axesHandle, timeSec, pitch, '-','DisplayName', 'Pitch');
        plot(axesHandle, timeSec, yaw,'-', 'DisplayName', 'Yaw');
        hold(axesHandle, 'off');   
        xlabel(axesHandle, 'Time (s)');
        ylabel(axesHandle, 'Angle (degrees)');
        grid(axesHandle, 'on');
        legend(axesHandle, 'Location', 'eastoutside');
   
        qNorm = sqrt(sum(qData.^2, 2));

figure;
plot(timeSec, qNorm);
xlabel('Time (s)');
ylabel('Quaternion norm');
title('Quaternion norm');

gravityWorld = repmat([0 0 1], size(qData, 1), 1); % assuming acceleration is in g

gravitySensor = rotateframe(quatObj, gravityWorld);

figure;
plot(timeSec, acc(:, 1), 'DisplayName', 'Acc X');
hold on;
plot(timeSec, acc(:, 2), 'DisplayName', 'Acc Y');
plot(timeSec, acc(:, 3), 'DisplayName', 'Acc Z');

plot(timeSec, gravitySensor(:, 1),  'DisplayName', 'Gravity X');
plot(timeSec, gravitySensor(:, 2), 'DisplayName', 'Gravity Y');
plot(timeSec, gravitySensor(:, 3), 'DisplayName', 'Gravity Z');

xlabel('Time (s)');
ylabel('Acceleration / gravity component (g)');
legend('Location', 'best');
title('Raw acceleration vs quaternion-estimated gravity');


accLinear = acc - gravitySensor;

accLinearMagnitude = sqrt(sum(accLinear.^2, 2));

figure;

plot(timeSec, accLinearMagnitude);

xlabel('Time (s)');

ylabel('Linear acceleration magnitude (g)');

title('Quaternion gravity-corrected acceleration magnitude');

    else
        warning('displaySingleTrialAccelerometer:BadQDataShape', ...
            'accData.qData must be an nSamples x 4 matrix of quaternions if present. Skipping quaternion plot.');
    end   



end

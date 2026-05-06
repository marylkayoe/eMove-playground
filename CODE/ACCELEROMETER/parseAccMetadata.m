function meta = parseAccMetadata(csvPath, acc, timeSec, headerNames, timeText, deviceName, chipTimeText)
%PARSEACCMETADATA Build metadata for one imported Waseda accelerometer CSV.
%
% Purpose
%   Assemble the metadata structure associated with one imported WTAcc CSV
%   file.
%
% Inputs
%   csvPath        - Source CSV path.
%   acc            - nSamples x 3 acceleration matrix [X Y Z] in g.
%   timeSec        - nSamples x 1 time vector in seconds, relative to the
%                    first sample in the file.
%   headerNames    - 1 x nColumns string array of original CSV header names.
%   timeText       - nSamples x 1 string array from the raw `Time` column.
%   deviceName     - nSamples x 1 string array from the raw `Device name`
%                    column.
%   chipTimeText   - nSamples x 1 string array from the raw `Chip Time()`
%                    column.
%
% Output
%   meta           - Structure describing source path, dimensions, units,
%                    timing, and original CSV column names.
%
% Important assumptions
%   `timeSec` is already expressed relative to the first sample in the file.

timeDiffSec = diff(timeSec);
positiveTimeDiffSec = timeDiffSec(timeDiffSec > 0);
if isempty(positiveTimeDiffSec)
    sampleRateHz = NaN;
else
    sampleRateHz = 1 / median(positiveTimeDiffSec);
end

meta = struct();
meta.sourceCsvPath = string(csvPath);
meta.nSamples = size(acc, 1);
meta.accelerationColumns = ["Acceleration X(g)", "Acceleration Y(g)", "Acceleration Z(g)"];
meta.accelerationUnits = "g";
meta.accelerationMatrixShape = sprintf('%d x %d', size(acc, 1), size(acc, 2));
meta.axisOrder = ["X", "Y", "Z"];
meta.timeUnits = "seconds";
meta.timeReference = "relative to first sample in file";
meta.timeColumn = "Time";
meta.timeStartText = timeText(1);
meta.timeEndText = timeText(end);
meta.sampleRateHz = sampleRateHz;
meta.deviceNameUnique = unique(deviceName);
meta.chipTimeMissingFraction = mean(chipTimeText == "");
meta.chipTimeStart = chipTimeText(1);
meta.chipTimeEnd = chipTimeText(end);
meta.originalColumnNames = headerNames;
end

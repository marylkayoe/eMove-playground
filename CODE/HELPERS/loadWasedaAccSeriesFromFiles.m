function series = loadWasedaAccSeriesFromFiles(recording, sensorKey, filePaths)
%LOADWASEDAACCSERIESFROMFILES Concatenate WTAcc CSV chunks into one series.
timesSec = [];
ax = [];
ay = [];
az = [];
fileBoundariesSec = [];
referenceAbsSec = NaN;
chipMissing = 0;
rowCount = 0;

for iFile = 1:numel(filePaths)
    [timeText, chipText, xValues, yValues, zValues] = localReadWtAccCsv(filePaths{iFile});
    timeSecAbs = parseWasedaClockTimeToSeconds(timeText);
    if isnan(referenceAbsSec)
        referenceAbsSec = timeSecAbs(1);
    end
    beforeMidnight = timeSecAbs < referenceAbsSec;
    timeSecAbs(beforeMidnight) = timeSecAbs(beforeMidnight) + 24 * 3600;
    relSec = timeSecAbs - referenceAbsSec;
    if iFile > 1 && ~isempty(relSec)
        fileBoundariesSec(end + 1, 1) = relSec(1); %#ok<AGROW>
    end
    timesSec = [timesSec; relSec(:)]; %#ok<AGROW>
    ax = [ax; xValues(:)]; %#ok<AGROW>
    ay = [ay; yValues(:)]; %#ok<AGROW>
    az = [az; zValues(:)]; %#ok<AGROW>
    chipMissing = chipMissing + sum(strlength(strtrim(chipText)) == 0);
    rowCount = rowCount + numel(xValues);
end

series = struct();
series.recording = recording;
series.sensor_key = sensorKey;
series.sensor_label = localSensorLabel(sensorKey);
series.files = {filePaths{:}}';
series.times_sec = timesSec;
series.ax = ax;
series.ay = ay;
series.az = az;
series.file_boundaries_sec = fileBoundariesSec;
series.reference_abs_sec = referenceAbsSec;
series.sample_rate_hz = estimateSampleRateHzFromTimes(timesSec);
if rowCount > 0
    series.chip_time_missing_frac = chipMissing / rowCount;
else
    series.chip_time_missing_frac = NaN;
end
end

function [timeText, chipText, xValues, yValues, zValues] = localReadWtAccCsv(csvPath)
fid = fopen(csvPath, 'r', 'n', 'UTF-8');
if fid < 0
    error('Could not open WTAcc CSV: %s', csvPath);
end
cleanup = onCleanup(@() fclose(fid));
headerLine = fgetl(fid); %#ok<NASGU>
data = textscan(fid, '%s%s%s%f%f%f%*[^\n]', ...
    'Delimiter', ',', ...
    'TextType', 'string', ...
    'CollectOutput', false, ...
    'ReturnOnError', false);

timeText = strtrim(data{1});
chipText = strtrim(data{3});
xValues = data{4};
yValues = data{5};
zValues = data{6};
end

function label = localSensorLabel(sensorKey)
switch sensorKey
    case 'chest'
        label = 'Chest';
    case 'forearm_left'
        label = 'Forearm left';
    otherwise
        label = sensorKey;
end
end

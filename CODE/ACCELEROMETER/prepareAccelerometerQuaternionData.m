function imuPrepared = prepareAccelerometerQuaternionData(accData, varargin)
%PREPAREACCELEROMETERQUATERNIONDATA Prepare accelerometer and quaternion data.
%
% imuPrepared = prepareAccelerometerQuaternionData(accData)
%
% This function performs only the preparation stage before gravity removal.
% It does not remove gravity, bandpass-filter motion signals, compute
% envelopes, or classify behavioural periods.
%
% Required input structure:
%   accData.acc                  nSamples x 3 acceleration data [x y z]
%   accData.quat                 nSamples x 4 quaternion data
%   accData.timeSec              nSamples x 1 raw/exported time vector
%   accData.meta.sampleRateHz    sampling frequency in Hz
%
% Important:
%   The exported timeSec field may be quantized or unreliable. This function
%   reconstructs the analysis time vector from sample index and sample rate:
%
%       timeSec = (0:nSamples-1)' / sampleRateHz
%
%   The original accData.timeSec is preserved as rawTimeSec for QC.
%
% Optional name-value inputs:
%   'AccelerationUnit'             'auto', 'g', or 'm/s^2' / 'mps2'
%   'QuaternionOrder'              'wxyz' or 'xyzw'
%   'QuaternionNormTolerance'      default 0.005
%   'AccelerationMagnitudeMaxG'    default 4
%   'AccelerationJumpMaxGPerSample' default 0.5
%   'AccelerationJumpMadFactor'    default 10
%   'QuaternionJumpMaxDeg'         default 60
%   'PaddingSeconds'               default 0.25
%   'MaxInterpolationSeconds'      default 0.50
%   'DoInterpolation'              default true
%   'MakeQcPlots'                  default true
%
% Output:
%   imuPrepared.timeSec
%   imuPrepared.timeStepSec
%   imuPrepared.samplingFrequency
%
%   imuPrepared.raw.acc
%   imuPrepared.raw.quat
%   imuPrepared.raw.quatOriginalOrder
%   imuPrepared.raw.timeSec
%
%   imuPrepared.prepared.acc
%   imuPrepared.prepared.quat
%
%   imuPrepared.qc
%   imuPrepared.meta
%
% Notes:
%   - Acceleration is converted to g if needed.
%   - Quaternion rows are normalized to unit length.
%   - Quaternion sign flips are corrected because q and -q represent the
%     same orientation.
%   - Very short bad periods can be linearly interpolated.
%   - Long bad periods remain NaN and should be excluded downstream.
%
% Downstream gravity removal should use:
%   imuPrepared.prepared.acc
%   imuPrepared.prepared.quat
%   imuPrepared.timeSec
%   imuPrepared.samplingFrequency

%% Parse input options

inputParserObject = inputParser;

addRequired(inputParserObject, 'accData', @isstruct);

addParameter(inputParserObject, 'AccelerationUnit', 'auto', ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'QuaternionOrder', 'wxyz', ...
    @(value) ischar(value) || isstring(value));

addParameter(inputParserObject, 'QuaternionNormTolerance', 0.005, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'AccelerationMagnitudeMaxG', 4, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'AccelerationJumpMaxGPerSample', 0.5, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'AccelerationJumpMadFactor', 10, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'QuaternionJumpMaxDeg', 40, ...
    @(value) isnumeric(value) && isscalar(value) && value > 0);

addParameter(inputParserObject, 'PaddingSeconds', 0.25, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'MaxInterpolationSeconds', 0.50, ...
    @(value) isnumeric(value) && isscalar(value) && value >= 0);

addParameter(inputParserObject, 'DoInterpolation', true, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MakeQcPlots', true, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, accData, varargin{:});

options = inputParserObject.Results;

accelerationUnit = lower(string(options.AccelerationUnit));
quaternionOrder = lower(string(options.QuaternionOrder));

doInterpolation = logical(options.DoInterpolation);
makeQcPlots = logical(options.MakeQcPlots);

%% Validate input structure and extract raw arrays

validateInputStructure(accData);

accRaw = double(accData.acc);
quatRaw = double(accData.quat);
rawTimeSec = accData.timeSec(:);

nSamples = size(accRaw, 1);

if size(accRaw, 2) ~= 3
    error('accData.acc must be nSamples x 3.');
end

if size(quatRaw, 2) ~= 4
    error('accData.quat must be nSamples x 4.');
end

if size(quatRaw, 1) ~= nSamples
    error('accData.quat must have the same number of rows as accData.acc.');
end

if numel(rawTimeSec) ~= nSamples
    error('accData.timeSec must have the same number of samples as accData.acc.');
end

samplingFrequency = accData.meta.sampleRateHz;

if ~isscalar(samplingFrequency) || ~isnumeric(samplingFrequency) || samplingFrequency <= 0
    error('accData.meta.sampleRateHz must be a positive numeric scalar.');
end

%% Reconstruct the analysis time base

% The exported time vector may be quantized or otherwise unreliable.
% Use the sample rate as the authority for within-file signal processing.

timeStepSec = 1 ./ samplingFrequency;
timeSec = (0:nSamples - 1)' ./ samplingFrequency;

timeWasReconstructed = true;

rawTimeStep = diff(rawTimeSec);
rawTimeUniqueFraction = numel(unique(rawTimeSec)) ./ numel(rawTimeSec);
nRepeatedRawTimeSteps = sum(rawTimeStep == 0);
nNonIncreasingRawTimeSteps = sum(rawTimeStep <= 0);

%% Prepare acceleration data

% Convert acceleration to g if needed.
% The raw magnitude is used only to infer units and identify impossible
% values. This stage should not classify normal movement as bad data.

accMagnitudeRawOriginal = sqrt(sum(accRaw.^2, 2));
medianRawMagnitudeOriginal = median(accMagnitudeRawOriginal, 'omitnan');

convertedAccelerationToG = false;

if accelerationUnit == "auto"

    if medianRawMagnitudeOriginal > 5
        accRawG = accRaw ./ 9.80665;
        convertedAccelerationToG = true;
        detectedAccelerationUnit = "m/s^2";
    else
        accRawG = accRaw;
        detectedAccelerationUnit = "g";
    end

elseif accelerationUnit == "g"

    accRawG = accRaw;
    detectedAccelerationUnit = "g";

elseif accelerationUnit == "m/s^2" || accelerationUnit == "mps2" || accelerationUnit == "m/s2"

    accRawG = accRaw ./ 9.80665;
    convertedAccelerationToG = true;
    detectedAccelerationUnit = "m/s^2";

else

    error('AccelerationUnit must be ''auto'', ''g'', or ''m/s^2''.');

end

%% Acceleration QC masks

accMagnitudeRawG = sqrt(sum(accRawG.^2, 2));

badAccNaN = any(isnan(accRawG), 2);
badAccInf = any(isinf(accRawG), 2);

% This catches only very large, likely impossible acceleration magnitudes.
badAccMagnitude = accMagnitudeRawG > options.AccelerationMagnitudeMaxG;

% One-sample jumps are useful for finding sensor glitches.
% The hard threshold is used for bad-data masking.
accJump = [zeros(1, 3); diff(accRawG)];
accJumpMagnitude = sqrt(sum(accJump.^2, 2));

badAccJump = accJumpMagnitude > options.AccelerationJumpMaxGPerSample;

% The MAD threshold is stored only as descriptive QC. It is not used to
% define bad samples, because quiet recordings can make this threshold much
% too low and cause real movement to be labelled as artefact.
accJumpMedian = median(accJumpMagnitude, 'omitnan');
accJumpMad = mad(accJumpMagnitude, 1);

if accJumpMad == 0 || isnan(accJumpMad)
    accJumpRobustThreshold = Inf;
else
    accJumpRobustThreshold = accJumpMedian + ...
        options.AccelerationJumpMadFactor .* accJumpMad;
end

badAcc = badAccNaN | badAccInf | badAccMagnitude | badAccJump;

%% Prepare quaternion data

% The internal convention used here is [w x y z].
% If the input is [x y z w], convert it once at the beginning and keep the
% prepared quaternion data in [w x y z] order.

if quaternionOrder == "xyzw"

    quatRawWxyz = [quatRaw(:, 4), quatRaw(:, 1), quatRaw(:, 2), quatRaw(:, 3)];

elseif quaternionOrder == "wxyz"

    quatRawWxyz = quatRaw;

else

    error('QuaternionOrder must be ''wxyz'' or ''xyzw''.');

end

%% Quaternion norm QC and normalization

quatNormRaw = sqrt(sum(quatRawWxyz.^2, 2));

badQuatNaN = any(isnan(quatRawWxyz), 2);
badQuatInf = any(isinf(quatRawWxyz), 2);

% Very bad norms cannot be safely normalized.
badQuatNormVeryBad = quatNormRaw < 0.5 | isnan(quatNormRaw) | isinf(quatNormRaw);

% Mild norm deviations are still useful to flag, even though normalization
% usually repairs them.
badQuatNormDeviation = abs(quatNormRaw - 1) > options.QuaternionNormTolerance;

quatUnit = quatRawWxyz;
goodQuatNorm = ~badQuatNormVeryBad;

quatUnit(goodQuatNorm, :) = quatRawWxyz(goodQuatNorm, :) ./ quatNormRaw(goodQuatNorm);
quatUnit(~goodQuatNorm, :) = NaN;

%% Correct quaternion sign flips

% q and -q represent the same orientation. Some systems can switch signs
% between samples. That creates artificial jumps in component plots and in
% interpolation unless corrected.

quatSignCorrected = fixQuaternionSignFlips(quatUnit);

%% Quaternion orientation-step QC

% Estimate the angle between consecutive orientation samples.
% Large steps can reflect sensor-fusion jumps, packet problems, or very
% rapid real motion. Only severe jumps are treated as bad by default.

angleStepDeg = computeQuaternionAngleStepDeg(quatSignCorrected);

badQuatJump = angleStepDeg > options.QuaternionJumpMaxDeg;

badQuatNorm = badQuatNaN | badQuatInf | badQuatNormVeryBad | badQuatNormDeviation;
badQuat = badQuatNorm | badQuatJump;

%% Combine bad-sample masks and pad short artefacts

badSamples = badAcc | badQuat;

paddingSamples = round(options.PaddingSeconds .* samplingFrequency);
badSamplesPadded = padLogicalMask(badSamples, paddingSamples);

maxInterpolationSamples = round(options.MaxInterpolationSeconds .* samplingFrequency);

if doInterpolation
    badSamplesForInterpolation = findShortBadRuns(badSamplesPadded, maxInterpolationSamples);
else
    badSamplesForInterpolation = false(size(badSamplesPadded));
end

badSamplesLong = badSamplesPadded & ~badSamplesForInterpolation;

%% Interpolate short bad periods

% Only short bad periods are interpolated. Long bad periods are preserved as
% NaNs so downstream analysis can exclude them explicitly.

accPrepared = accRawG;
quatPrepared = quatSignCorrected;

accPrepared(badSamplesForInterpolation, :) = NaN;
quatPrepared(badSamplesForInterpolation, :) = NaN;

if doInterpolation

    accPrepared = interpolateColumns(accPrepared, timeSec);
    quatPrepared = interpolateColumns(quatPrepared, timeSec);

    quatPrepared = normalizeQuaternionRows(quatPrepared);
    quatPrepared = fixQuaternionSignFlips(quatPrepared);

end

accPrepared(badSamplesLong, :) = NaN;
quatPrepared(badSamplesLong, :) = NaN;

quatPrepared = normalizeQuaternionRows(quatPrepared);

%% Package output structure

imuPrepared = struct();

imuPrepared.timeSec = timeSec;
imuPrepared.timeStepSec = timeStepSec;
imuPrepared.samplingFrequency = samplingFrequency;

imuPrepared.raw.acc = accRawG;
imuPrepared.raw.quat = quatRawWxyz;
imuPrepared.raw.quatOriginalOrder = quatRaw;
imuPrepared.raw.timeSec = rawTimeSec;
imuPrepared.raw.accelerationUnitOriginal = detectedAccelerationUnit;

imuPrepared.prepared.acc = accPrepared;
imuPrepared.prepared.quat = quatPrepared;

imuPrepared.meta = accData.meta;
imuPrepared.meta.convertedAccelerationToG = convertedAccelerationToG;
imuPrepared.meta.quaternionOrderInput = char(quaternionOrder);
imuPrepared.meta.quaternionOrderPrepared = 'wxyz';
imuPrepared.meta.timeWasReconstructed = timeWasReconstructed;

%% Store QC information

imuPrepared.qc.rawTimeStep = rawTimeStep;
imuPrepared.qc.rawTimeUniqueFraction = rawTimeUniqueFraction;
imuPrepared.qc.nRepeatedRawTimeSteps = nRepeatedRawTimeSteps;
imuPrepared.qc.nNonIncreasingRawTimeSteps = nNonIncreasingRawTimeSteps;
imuPrepared.qc.reconstructedTimeStepSec = timeStepSec;

imuPrepared.qc.accMagnitudeRawG = accMagnitudeRawG;
imuPrepared.qc.accMagnitudeRawOriginal = accMagnitudeRawOriginal;
imuPrepared.qc.medianRawMagnitudeOriginal = medianRawMagnitudeOriginal;

imuPrepared.qc.accJumpMagnitude = accJumpMagnitude;
imuPrepared.qc.accJumpHardThreshold = options.AccelerationJumpMaxGPerSample;
imuPrepared.qc.accJumpRobustThreshold = accJumpRobustThreshold;

imuPrepared.qc.badAccNaN = badAccNaN;
imuPrepared.qc.badAccInf = badAccInf;
imuPrepared.qc.badAccMagnitude = badAccMagnitude;
imuPrepared.qc.badAccJump = badAccJump;
imuPrepared.qc.badAcc = badAcc;

imuPrepared.qc.quatNormRaw = quatNormRaw;

imuPrepared.qc.badQuatNaN = badQuatNaN;
imuPrepared.qc.badQuatInf = badQuatInf;
imuPrepared.qc.badQuatNormVeryBad = badQuatNormVeryBad;
imuPrepared.qc.badQuatNormDeviation = badQuatNormDeviation;
imuPrepared.qc.badQuatNorm = badQuatNorm;

imuPrepared.qc.angleStepDeg = angleStepDeg;
imuPrepared.qc.badQuatJump = badQuatJump;
imuPrepared.qc.badQuat = badQuat;

imuPrepared.qc.badSamples = badSamples;
imuPrepared.qc.badSamplesPadded = badSamplesPadded;
imuPrepared.qc.badSamplesInterpolated = badSamplesForInterpolation;
imuPrepared.qc.badSamplesLong = badSamplesLong;

imuPrepared.qc.summary.nSamples = nSamples;
imuPrepared.qc.summary.nBadAcc = sum(badAcc);
imuPrepared.qc.summary.nBadQuat = sum(badQuat);
imuPrepared.qc.summary.nBadQuatNorm = sum(badQuatNorm);
imuPrepared.qc.summary.nBadQuatJump = sum(badQuatJump);
imuPrepared.qc.summary.nBadSamplesPadded = sum(badSamplesPadded);
imuPrepared.qc.summary.nInterpolatedSamples = sum(badSamplesForInterpolation);
imuPrepared.qc.summary.nLongBadSamples = sum(badSamplesLong);
imuPrepared.qc.summary.fractionBadSamplesPadded = mean(badSamplesPadded);
%% Store prepared data in the same shape as the input structure

% This is useful when downstream plotting functions expect the original
% accData-style structure with fields:
%   acc, quat, timeSec, meta
%
% These fields contain the prepared data, not the original raw data.
% Acceleration is in g. Quaternion order is [w x y z]. Time is reconstructed
% from sample index and sampleRateHz.

imuPrepared.preparedAsInput = struct();

imuPrepared.preparedAsInput.acc = accPrepared;
imuPrepared.preparedAsInput.quat = quatPrepared;
imuPrepared.preparedAsInput.timeSec = timeSec;
imuPrepared.preparedAsInput.meta = imuPrepared.meta;

imuPrepared.preparedAsInput.meta.dataStage = 'prepared';
imuPrepared.preparedAsInput.meta.accelerationUnit = 'g';
imuPrepared.preparedAsInput.meta.quaternionOrder = 'wxyz';
imuPrepared.preparedAsInput.meta.timeWasReconstructed = timeWasReconstructed;


%% Optional QC plots

if makeQcPlots
    makePreparationQcPlots(imuPrepared);
end

end

function validateInputStructure(accData)
%VALIDATEINPUTSTRUCTURE Check that the required fields exist.

requiredFields = {'acc', 'quat', 'timeSec', 'meta'};

for fieldIndex = 1:numel(requiredFields)

    fieldName = requiredFields{fieldIndex};

    if ~isfield(accData, fieldName)
        error('accData.%s is missing.', fieldName);
    end

end

if ~isfield(accData.meta, 'sampleRateHz')
    error('accData.meta.sampleRateHz is missing.');
end

end

function quatSignCorrected = fixQuaternionSignFlips(quatData)
%FIXQUATERNIONSIGNFLIPS Make quaternion sign representation continuous.
%
% q and -q describe the same 3D orientation. This function flips the sign of
% a row if it is more opposite than similar to the previous valid row.

quatSignCorrected = quatData;

for timeIndex = 2:size(quatSignCorrected, 1)

    previousQuat = quatSignCorrected(timeIndex - 1, :);
    currentQuat = quatSignCorrected(timeIndex, :);

    if any(isnan(previousQuat)) || any(isnan(currentQuat))
        continue
    end

    dotProduct = sum(previousQuat .* currentQuat);

    if dotProduct < 0
        quatSignCorrected(timeIndex, :) = -currentQuat;
    end

end

end

function angleStepDeg = computeQuaternionAngleStepDeg(quatData)
%COMPUTEQUATERNIONANGLESTEPDEG Estimate orientation change between samples.
%
% The angle is computed from the dot product between consecutive unit
% quaternions. The absolute value is used because q and -q represent the
% same orientation.

nSamples = size(quatData, 1);

angleStepDeg = NaN(nSamples, 1);
angleStepDeg(1) = 0;

for timeIndex = 2:nSamples

    previousQuat = quatData(timeIndex - 1, :);
    currentQuat = quatData(timeIndex, :);

    if any(isnan(previousQuat)) || any(isnan(currentQuat))
        continue
    end

    dotProduct = sum(previousQuat .* currentQuat);
    dotProduct = max(min(dotProduct, 1), -1);

    angleStepRad = 2 .* acos(abs(dotProduct));
    angleStepDeg(timeIndex) = rad2deg(angleStepRad);

end

end

function normalizedQuat = normalizeQuaternionRows(quatData)
%NORMALIZEQUATERNIONROWS Normalize each quaternion row to unit length.

quatNorm = sqrt(sum(quatData.^2, 2));

normalizedQuat = quatData;
goodRows = quatNorm > 0 & ~isnan(quatNorm) & ~isinf(quatNorm);

normalizedQuat(goodRows, :) = quatData(goodRows, :) ./ quatNorm(goodRows);
normalizedQuat(~goodRows, :) = NaN;

end

function paddedMask = padLogicalMask(mask, paddingSamples)
%PADLOGICALMASK Expand true regions by paddingSamples on each side.

mask = logical(mask(:));

if paddingSamples <= 0
    paddedMask = mask;
    return
end

windowLength = 2 .* paddingSamples + 1;
paddedMask = movmax(double(mask), windowLength) > 0;

end

function shortBadMask = findShortBadRuns(badMask, maxRunLength)
%FINDSHORTBADRUNS Return true only for bad runs short enough to interpolate.

badMask = logical(badMask(:));
shortBadMask = false(size(badMask));

if maxRunLength <= 0
    return
end

badIndex = find(badMask);

if isempty(badIndex)
    return
end

runStartPositions = [1; find(diff(badIndex) > 1) + 1];
runEndPositions = [runStartPositions(2:end) - 1; numel(badIndex)];

for runIndex = 1:numel(runStartPositions)

    runStart = badIndex(runStartPositions(runIndex));
    runEnd = badIndex(runEndPositions(runIndex));
    runLength = runEnd - runStart + 1;

    if runLength <= maxRunLength
        shortBadMask(runStart:runEnd) = true;
    end

end

end

function dataInterpolated = interpolateColumns(data, timeSec)
%INTERPOLATECOLUMNS Linearly interpolate NaNs column by column.

dataInterpolated = data;

for columnIndex = 1:size(data, 2)

    columnData = dataInterpolated(:, columnIndex);

    if all(isnan(columnData))
        continue
    end

    columnData = fillmissing(columnData, 'linear', ...
        'SamplePoints', timeSec, ...
        'EndValues', 'nearest');

    dataInterpolated(:, columnIndex) = columnData;

end

end

function makePreparationQcPlots(imuPrepared)
%MAKEPREPARATIONQCPLOTS Plot basic QC diagnostics.

timeSec = imuPrepared.timeSec;

figure('Name', 'IMU preparation QC');

%% Raw acceleration magnitude

subplot(4, 1, 1);

plot(timeSec, imuPrepared.qc.accMagnitudeRawG, 'DisplayName', 'Magnitude');
hold on;

plot(timeSec(imuPrepared.qc.badAcc), ...
    imuPrepared.qc.accMagnitudeRawG(imuPrepared.qc.badAcc), '.', ...
    'DisplayName', 'Bad acc');

ylabel('Raw acc mag (g)');
title('Raw acceleration magnitude');
legend('Location', 'best');

%% Acceleration jump magnitude

subplot(4, 1, 2);

plot(timeSec, imuPrepared.qc.accJumpMagnitude, ...
    'DisplayName', 'Jump magnitude');
hold on;

yline(imuPrepared.qc.accJumpHardThreshold, '--', ...
    'DisplayName', 'Hard bad-data threshold');

yline(imuPrepared.qc.accJumpRobustThreshold, ':', ...
    'DisplayName', 'Robust descriptive threshold');

ylabel('Acc jump (g/sample)');
title('Acceleration jump magnitude');
legend('Location', 'best');

%% Quaternion norm

subplot(4, 1, 3);

plot(timeSec, imuPrepared.qc.quatNormRaw, ...
    'DisplayName', 'Norm');
hold on;

plot(timeSec(imuPrepared.qc.badQuatNorm), ...
    imuPrepared.qc.quatNormRaw(imuPrepared.qc.badQuatNorm), '.', ...
    'DisplayName', 'Bad quat norm');

ylabel('Quaternion norm');
title('Quaternion norm');
legend('Location', 'best');

%% Quaternion orientation step

subplot(4, 1, 4);

plot(timeSec, imuPrepared.qc.angleStepDeg, ...
    'DisplayName', 'Angle step');
hold on;

plot(timeSec(imuPrepared.qc.badQuatJump), ...
    imuPrepared.qc.angleStepDeg(imuPrepared.qc.badQuatJump), '.', ...
    'DisplayName', 'Bad orientation jump');

xlabel('Time (s)');
ylabel('Angle step (deg)');
title('Quaternion orientation step');
legend('Location', 'best');

end
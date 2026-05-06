function imuCorrected = removeGravityFromPreparedImu(imuPrepared, varargin)
%REMOVEGRAVITYFROMPREPAREDIMU Remove gravity using prepared quaternion data.
%
% imuCorrected = removeGravityFromPreparedImu(imuPrepared)
%
% Input:
%   imuPrepared.prepared.acc      nSamples x 3 acceleration in g
%   imuPrepared.prepared.quat     nSamples x 4 quaternion [w x y z]
%   imuPrepared.timeSec
%   imuPrepared.samplingFrequency
%
% Output:
%   imuCorrected.acc.linear       acceleration after gravity subtraction
%   imuCorrected.acc.gravity      estimated gravity vector in sensor frame
%   imuCorrected.acc.raw          prepared acceleration before subtraction
%   imuCorrected.magnitude.raw
%   imuCorrected.magnitude.gravity
%   imuCorrected.magnitude.linear
%
% Notes:
%   - Assumes acceleration is in g.
%   - Assumes prepared quaternions are [w x y z].
%   - Direction convention can differ between systems. UseConjugate lets
%     you test the alternative rotation direction.

%% Parse options

inputParserObject = inputParser;

addRequired(inputParserObject, 'imuPrepared', @isstruct);

addParameter(inputParserObject, 'UseConjugate', false, ...
    @(value) islogical(value) || isnumeric(value));

addParameter(inputParserObject, 'MakeQcPlots', true, ...
    @(value) islogical(value) || isnumeric(value));

parse(inputParserObject, imuPrepared, varargin{:});

useConjugate = logical(inputParserObject.Results.UseConjugate);
makeQcPlots = logical(inputParserObject.Results.MakeQcPlots);

%% Extract prepared data

accPrepared = imuPrepared.prepared.acc;
quatPrepared = imuPrepared.prepared.quat;
timeSec = imuPrepared.timeSec;

if size(accPrepared, 2) ~= 3
    error('imuPrepared.prepared.acc must be nSamples x 3.');
end

if size(quatPrepared, 2) ~= 4
    error('imuPrepared.prepared.quat must be nSamples x 4.');
end

if size(accPrepared, 1) ~= size(quatPrepared, 1)
    error('Acceleration and quaternion data must have the same number of rows.');
end

%% Build quaternion object

quatObject = quaternion( ...
    quatPrepared(:, 1), ...
    quatPrepared(:, 2), ...
    quatPrepared(:, 3), ...
    quatPrepared(:, 4));

if useConjugate
    quatObject = conj(quatObject);
end

%% Estimate gravity in sensor coordinates

% Gravity is [0 0 1] because acceleration is stored in g.
% The quaternion rotates this world-frame gravity vector into the sensor
% coordinate frame.

gravityWorld = repmat([0 0 1], size(accPrepared, 1), 1);
gravitySensor = rotateframe(quatObject, gravityWorld);

%% Remove gravity

accLinear = accPrepared - gravitySensor;

%% Compute magnitudes

rawMagnitude = sqrt(sum(accPrepared.^2, 2));
gravityMagnitude = sqrt(sum(gravitySensor.^2, 2));
linearMagnitude = sqrt(sum(accLinear.^2, 2));

%% Package output

imuCorrected = struct();

imuCorrected.timeSec = timeSec;
imuCorrected.samplingFrequency = imuPrepared.samplingFrequency;

imuCorrected.acc.raw = accPrepared;
imuCorrected.acc.gravity = gravitySensor;
imuCorrected.acc.linear = accLinear;

imuCorrected.quat = quatPrepared;

imuCorrected.magnitude.raw = rawMagnitude;
imuCorrected.magnitude.gravity = gravityMagnitude;
imuCorrected.magnitude.linear = linearMagnitude;

imuCorrected.meta = imuPrepared.meta;
imuCorrected.meta.gravityRemoved = true;
imuCorrected.meta.gravityUnit = 'g';
imuCorrected.meta.gravityRotationUsedConjugate = useConjugate;

imuCorrected.qc.preparation = imuPrepared.qc;

%% Optional same-shape output

imuCorrected.linearAsInput = struct();
imuCorrected.linearAsInput.acc = accLinear;
imuCorrected.linearAsInput.quat = quatPrepared;
imuCorrected.linearAsInput.timeSec = timeSec;
imuCorrected.linearAsInput.meta = imuCorrected.meta;

imuCorrected.linearAsInput.meta.dataStage = 'gravity-corrected linear acceleration';
imuCorrected.linearAsInput.meta.accelerationUnit = 'g';
imuCorrected.linearAsInput.meta.quaternionOrder = 'wxyz';

%% Optional QC plots

if makeQcPlots
    makeGravityRemovalQcPlots(imuCorrected);
end

end

function makeGravityRemovalQcPlots(imuCorrected)
%MAKEGRAVITYREMOVALQCPLOTS Plot basic checks after gravity removal.

timeSec = imuCorrected.timeSec;

figure('Name', 'Gravity removal QC');

%% Prepared raw acceleration and estimated gravity

subplot(3, 1, 1);

plot(timeSec, imuCorrected.acc.raw(:, 1), 'DisplayName', 'Acc X');
hold on;
plot(timeSec, imuCorrected.acc.raw(:, 2), 'DisplayName', 'Acc Y');
plot(timeSec, imuCorrected.acc.raw(:, 3), 'DisplayName', 'Acc Z');

plot(timeSec, imuCorrected.acc.gravity(:, 1), '--', 'DisplayName', 'Gravity X');
plot(timeSec, imuCorrected.acc.gravity(:, 2), '--', 'DisplayName', 'Gravity Y');
plot(timeSec, imuCorrected.acc.gravity(:, 3), '--', 'DisplayName', 'Gravity Z');

ylabel('Acceleration (g)');
title('Prepared acceleration vs quaternion-estimated gravity');
legend('Location', 'best');

%% Magnitudes

subplot(3, 1, 2);

plot(timeSec, imuCorrected.magnitude.raw, 'DisplayName', 'Raw magnitude');
hold on;
plot(timeSec, imuCorrected.magnitude.gravity, 'DisplayName', 'Estimated gravity magnitude');
plot(timeSec, imuCorrected.magnitude.linear, 'DisplayName', 'Linear magnitude');

ylabel('Magnitude (g)');
title('Magnitude check');
legend('Location', 'best');

%% Linear acceleration components

subplot(3, 1, 3);

plot(timeSec, imuCorrected.acc.linear(:, 1), 'DisplayName', 'Linear X');
hold on;
plot(timeSec, imuCorrected.acc.linear(:, 2), 'DisplayName', 'Linear Y');
plot(timeSec, imuCorrected.acc.linear(:, 3), 'DisplayName', 'Linear Z');

xlabel('Time (s)');
ylabel('Linear acc (g)');
title('Gravity-corrected acceleration');
legend('Location', 'best');

end
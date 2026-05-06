function [centeredAcc, meanAcc] = centerAccByMean(acc, meanAcc)
%CENTERACCBYMEAN Center XYZ acceleration by subtracting the column mean.
%
% Purpose
%   Center an accelerometer matrix by subtracting one constant 1 x 3 mean
%   vector from every sample.
%
% Inputs
%   acc     - nSamples x 3 acceleration matrix [X Y Z].
%   meanAcc - Optional 1 x 3 mean vector to subtract. If omitted or empty,
%             the function uses the column mean of `acc`.
%
% Outputs
%   centeredAcc - nSamples x 3 acceleration matrix after mean subtraction.
%   meanAcc     - 1 x 3 mean vector that was subtracted.
%
% Important assumptions
%   This simple method performs column-wise centering only. It does not
%   estimate or model gravity separately from other constant offsets.

%% Check inputs
if nargin < 2 || isempty(meanAcc)
    meanAcc = mean(acc, 1, 'omitnan');
end

if ~ismatrix(acc) || size(acc, 2) ~= 3
    error('centerAccByMean:BadAccShape', ...
        'acc must be an nSamples x 3 matrix.');
end

if ~isnumeric(acc)
    error('centerAccByMean:BadAccType', ...
        'acc must be numeric.');
end

if ~isnumeric(meanAcc) || numel(meanAcc) ~= 3
    error('centerAccByMean:BadMeanAcc', ...
        'meanAcc must contain three numeric values.');
end

meanAcc = reshape(meanAcc, 1, 3);

%% Subtract column mean
centeredAcc = acc - meanAcc;
end

function sampleRateHz = estimateSampleRateHzFromTimes(timesSec)
%ESTIMATESAMPLERATEHZFROMTIMES Estimate sampling rate from median positive dt.
dts = diff(timesSec);
dts = dts(dts > 0);
if isempty(dts)
    sampleRateHz = NaN;
else
    sampleRateHz = 1 / median(dts);
end
end

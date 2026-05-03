function secondsAbs = parseWasedaClockTimeToSeconds(clockValues)
%PARSEWASEDACLOCKTIMETOSECONDS Parse HH:MM:SS.sss text to seconds from midnight.
clockValues = string(clockValues);
secondsAbs = NaN(size(clockValues));
for iValue = 1:numel(clockValues)
    token = strtrim(clockValues(iValue));
    if strlength(token) == 0
        continue;
    end
    parsed = sscanf(token, '%d:%d:%f', 3);
    if numel(parsed) ~= 3
        error('Could not parse Waseda clock time: %s', token);
    end
    secondsAbs(iValue) = parsed(1) * 3600 + parsed(2) * 60 + parsed(3);
end
end

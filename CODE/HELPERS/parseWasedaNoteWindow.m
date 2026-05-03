function [startSec, endSec] = parseWasedaNoteWindow(noteWindow, referenceAbsSec)
%PARSEWASEDANOTEWINDOW Convert HH:MM-HH:MM note window into relative seconds.
parts = split(string(noteWindow), '-');
if numel(parts) ~= 2
    error('Invalid Waseda note window: %s', noteWindow);
end
startAbs = localParseHhMm(parts(1));
endAbs = localParseHhMm(parts(2));
if startAbs < referenceAbsSec
    startAbs = startAbs + 24 * 3600;
end
if endAbs < referenceAbsSec
    endAbs = endAbs + 24 * 3600;
end
startSec = startAbs - referenceAbsSec;
endSec = endAbs - referenceAbsSec;
end

function secondsAbs = localParseHhMm(label)
parts = sscanf(strtrim(label), '%d:%d', 2);
if numel(parts) ~= 2
    error('Invalid HH:MM label: %s', label);
end
secondsAbs = parts(1) * 3600 + parts(2) * 60;
end

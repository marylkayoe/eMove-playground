function label = formatWasedaAbsoluteClockLabel(absSec, includeSeconds)
%FORMATWASEDAABSOLUTECLOCKLABEL Format absolute seconds-of-day as HH:MM or HH:MM:SS.
if nargin < 2
    includeSeconds = false;
end
absSec = mod(absSec, 24 * 3600);
hours = floor(absSec / 3600);
minutes = floor(mod(absSec, 3600) / 60);
seconds = floor(mod(absSec, 60));
if includeSeconds
    label = sprintf('%02d:%02d:%02d', hours, minutes, seconds);
else
    label = sprintf('%02d:%02d', hours, minutes);
end
end

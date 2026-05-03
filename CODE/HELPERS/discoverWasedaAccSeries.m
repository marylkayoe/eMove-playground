function series = discoverWasedaAccSeries(rawRoot, recording, sensorKey)
%DISCOVERWASEDAACCSERIES Find and load one sensor stream for one recording.
if ~isfield(recording.file_patterns, sensorKey)
    error('Sensor %s is not defined for recording %s.', sensorKey, recording.recording_id);
end
pattern = recording.file_patterns.(sensorKey);
listing = dir(fullfile(rawRoot, recording.relative_dir, pattern));
if isempty(listing)
    error('No files found for %s sensor %s.', recording.recording_id, sensorKey);
end
names = fullfile({listing.folder}, {listing.name});
names = sort(names);
series = loadWasedaAccSeriesFromFiles(recording, sensorKey, names);
end

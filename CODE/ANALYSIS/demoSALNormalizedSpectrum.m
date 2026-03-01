% demoSALNormalizedSpectrum.m
% Visualize normalized spectrum curve used in SAL and compare smooth vs jerky motion.

close all;

fs = 120; % Hz
T = 10;   % seconds (longer signal -> denser spectrum)
t = (0:1/fs:T-1/fs)';

% Build two speed signals
smoothSpeed = 0.5 + 0.35*sin(2*pi*0.8*t) + 0.12*sin(2*pi*1.6*t);
jerkySpeed  = 0.5 + 0.35*sin(2*pi*0.8*t) + 0.12*sin(2*pi*1.6*t) + 0.30*sin(2*pi*12*t) + 0.20*sin(2*pi*20*t);

% Detrend (as in SAL)
smoothSpeed = smoothSpeed - mean(smoothSpeed);
jerkySpeed  = jerkySpeed - mean(jerkySpeed);

% Compute normalized spectrum curves
[maxFreq, fN_s, aN_s, sal_s] = localNormSpectrumAndSAL(smoothSpeed, fs, 10, 4096);
[~,       fN_j, aN_j, sal_j] = localNormSpectrumAndSAL(jerkySpeed,  fs, 10, 4096);
[segLen_s, fMid_s, cumLen_s] = localArcLengthSegments(fN_s, aN_s);
[segLen_j, fMid_j, cumLen_j] = localArcLengthSegments(fN_j, aN_j);

figure('Color','w');

subplot(2,2,1);
plot(t, smoothSpeed, 'b', 'LineWidth', 1.2); hold on;
plot(t, jerkySpeed,  'r', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Speed (a.u.)');
legend('Smooth speed','Jerky speed','Location','northeast');
title('Speed signals'); grid on;

subplot(2,2,2);
plot(fN_s, aN_s, 'b', 'LineWidth', 1.8); hold on;
plot(fN_j, aN_j, 'r', 'LineWidth', 1.8);
xlabel('Normalized frequency'); ylabel('Normalized amplitude');
legend('Smooth','Jerky','Location','northeast');

% Show SAL values (more negative = smoother)
title(sprintf('Normalized spectrum (maxFreq=%g Hz)\nSAL smooth=%.3f, SAL jerky=%.3f', maxFreq, sal_s, sal_j));
grid on;

subplot(2,2,3);
plot(fN_s, aN_s, 'b', 'LineWidth', 1.8); hold on;
plot(fN_s, aN_s, 'bo', 'MarkerSize', 4, 'MarkerFaceColor', 'b');
xlabel('Normalized frequency'); ylabel('Normalized amplitude');

% Visualize arc length segments for smooth
localPlotArcSegments(fN_s, aN_s);

title('Arc length segments (smooth)'); grid on;
xlim([0 0.4]);

subplot(2,2,4);
plot(fN_j, aN_j, 'r', 'LineWidth', 1.8); hold on;
plot(fN_j, aN_j, 'ro', 'MarkerSize', 4, 'MarkerFaceColor', 'r');
xlabel('Normalized frequency'); ylabel('Normalized amplitude');
localPlotArcSegments(fN_j, aN_j);

title('Arc length segments (jerky)'); grid on;
xlim([0 0.4]);

% Cumulative arc length (shows where length accumulates)
figure('Color','w');
subplot(1,2,1);
plot(fMid_s, cumLen_s, 'b', 'LineWidth', 2); hold on;
plot(fMid_j, cumLen_j, 'r', 'LineWidth', 2);
xlabel('Normalized frequency'); ylabel('Cumulative arc length');
legend('Smooth','Jerky','Location','northwest');
title('Cumulative arc length vs frequency'); grid on;
xlim([0 0.4]);

subplot(1,2,2);
bar([sum(segLen_s), sum(segLen_j)]);
set(gca, 'XTickLabel', {'Smooth','Jerky'});
ylabel('Total arc length');
title('Total arc length (jerky should be larger)');
grid on;

function [maxFreq, fNorm, aNorm, sal] = localNormSpectrumAndSAL(speedSignal, fs, maxFreq, nfft)
    N = numel(speedSignal);
    if nargin < 4 || isempty(nfft)
        nfft = N;
    end
    Y = abs(fft(speedSignal, nfft));
    freqs = (0:nfft-1)' * (fs / nfft);
    halfIdx = 1:floor(nfft/2);
    freqs = freqs(halfIdx);
    Y = Y(halfIdx);

    nyq = fs/2;
    maxFreq = min(maxFreq, nyq);
    mask = freqs <= maxFreq;
    freqs = freqs(mask);
    Y = Y(mask);

    fNorm = freqs / maxFreq;
    aNorm = Y / max(Y);

    df = diff(fNorm);
    da = diff(aNorm);
    arcLen = sum(sqrt(df.^2 + da.^2));
    sal = -arcLen; % more negative = smoother
end

function [segLen, fMid, cumLen] = localArcLengthSegments(fNorm, aNorm)
    df = diff(fNorm);
    da = diff(aNorm);
    segLen = sqrt(df.^2 + da.^2);
    fMid = (fNorm(1:end-1) + fNorm(2:end)) / 2;
    cumLen = cumsum(segLen);
end

function localPlotArcSegments(fNorm, aNorm)
    df = diff(fNorm);
    da = diff(aNorm);
    segLen = sqrt(df.^2 + da.^2);
    nSeg = numel(segLen);
    cmap = parula(max(nSeg, 2));

    for i = 1:nSeg
        c = cmap(i, :);
        plot([fNorm(i), fNorm(i+1)], [aNorm(i), aNorm(i+1)], '-', 'Color', c, 'LineWidth', 1.0);
    end

    % Highlight a few segments with length labels
    nHighlight = min(5, nSeg);
    idx = round(linspace(1, nSeg, nHighlight));
    for k = 1:numel(idx)
        i = idx(k);
        x1 = fNorm(i); x2 = fNorm(i+1);
        y1 = aNorm(i); y2 = aNorm(i+1);
        plot([x1, x2], [y1, y2], 'k-', 'LineWidth', 2.0);
        xm = (x1 + x2) / 2;
        ym = (y1 + y2) / 2;
        text(xm, ym, sprintf('%.3f', segLen(i)), 'FontSize', 8, 'Color', [0 0 0], ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
    end
end

function [histImg, visibilityScore, conditions] = ip_histogram_analysis(frame)
%IP_HISTOGRAM_ANALYSIS
%  IMAGE PROCESSING MODULE 5 — Visibility & Road Condition Analysis
%
%  Pipeline:
%    RGB frame → HSV → Histogram Analysis → CLAHE Enhancement
%    → Visibility Score → Weather condition estimate
%
%  MATLAB Functions Used:
%    rgb2hsv()        - colour space conversion
%    imhist()         - compute intensity histogram
%    adapthisteq()    - CLAHE (Contrast Limited Adaptive Histogram Equalization)
%    mean(), std()    - statistical measures on histogram
%
%  MATHEMATICS:
%    Histogram H(k) = number of pixels with intensity k
%    Normalised: p(k) = H(k) / (M×N)   (probability)
%
%    Visibility score from entropy:
%      E = -Σ p(k) · log2(p(k))   (Shannon entropy)
%    High entropy = good visibility, Low entropy = fog/dark/rain
%
%    CLAHE divides image into tiles, equalises each tile:
%      T(k) = (L-1)/MN · Σ_{j=0}^{k} H(j)   (CDF-based mapping)

    histImg        = frame;
    visibilityScore = 1.0;
    conditions     = 'CLEAR';

    %% Step 1: Convert to HSV, work on Value channel
    hsvImg   = rgb2hsv(frame);
    valChannel = hsvImg(:,:,3);   % brightness/value

    %% Step 2: Compute histogram of value channel
    [counts, ~] = imhist(valChannel, 64);
    totalPx = sum(counts);
    prob    = counts / totalPx;
    prob(prob==0) = [];   % remove zeros for entropy calc

    %% Step 3: Shannon Entropy → visibility metric
    entropy = -sum(prob .* log2(prob));
    maxEntropy = log2(64);   % theoretical max for 64 bins
    normEntropy = entropy / maxEntropy;

    %% Step 4: Mean brightness
    meanBright = mean(valChannel(:));

    %% Step 5: Determine visibility score & conditions
    if meanBright < 0.25
        visibilityScore = meanBright * 2;
        conditions = 'NIGHT / LOW LIGHT';
    elseif normEntropy < 0.6
        visibilityScore = normEntropy;
        conditions = 'FOG / RAIN';
    elseif meanBright > 0.85
        visibilityScore = 0.7;
        conditions = 'GLARE / OVEREXPOSED';
    else
        visibilityScore = 0.7 + normEntropy * 0.3;
        conditions = 'CLEAR';
    end
    visibilityScore = max(0, min(1, visibilityScore));

    %% Step 6: Apply CLAHE to enhance visibility
    grayImg = rgb2gray(frame);
    enhanced = adapthisteq(grayImg, 'ClipLimit', 0.02, 'NumTiles', [8 8]);

    % Merge enhanced back to RGB
    enhFactor = double(enhanced) ./ max(double(grayImg), 1);
    for ch = 1:3
        histImg(:,:,ch) = uint8(min(255, double(frame(:,:,ch)) .* enhFactor));
    end

    fprintf('   IP[Hist]: entropy=%.3f, brightness=%.3f → %s (vis=%.2f)\n', ...
            normEntropy, meanBright, conditions, visibilityScore);
end

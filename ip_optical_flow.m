function [flowImg, motionScore, flowMagnitude] = ip_optical_flow(prevFrame, currFrame)
%IP_OPTICAL_FLOW
%  IMAGE PROCESSING MODULE 4 - Motion Detection via Optical Flow
%
%  Uses Lucas-Kanade method to detect moving objects between frames.
%  FIX: Create a fresh estimator each call to avoid frame-size mismatch.
%
%  MATHEMATICS:
%    Lucas-Kanade solves: [u; v] = (A'A)^-1 A'b
%    where A=[Ix,Iy], b=-It  (spatial & temporal image gradients)
%    Motion magnitude: M(x,y) = sqrt(u^2 + v^2)

    flowImg       = currFrame;
    motionScore   = 0;
    flowMagnitude = [];

    %% Need two frames of identical size
    if isempty(prevFrame)
        return;
    end

    %% Ensure both frames are same size - resize prevFrame if needed
    [Hc, Wc, ~] = size(currFrame);
    [Hp, Wp, ~] = size(prevFrame);
    if Hc ~= Hp || Wc ~= Wp
        prevFrame = imresize(prevFrame, [Hc, Wc]);
    end

    %% Convert to grayscale
    grayPrev = rgb2gray(prevFrame);
    grayCurr = rgb2gray(currFrame);

    %% Create a FRESH estimator every call (avoids size-mismatch error)
    ofEstimator = opticalFlowLK('NoiseThreshold', 0.0039);

    %% Feed previous frame first, then current
    estimateFlow(ofEstimator, grayPrev);
    flow = estimateFlow(ofEstimator, grayCurr);

    flowMagnitude = flow.Magnitude;

    %% Focus on upper-road region where moving objects appear
    H = size(flowMagnitude, 1);
    W = size(flowMagnitude, 2);
    roiMag = flowMagnitude(round(H*0.44):round(H*0.80), ...
                           round(W*0.20):round(W*0.80));

    %% Motion threat score
    meanMag     = mean(roiMag(:));
    maxMag      = max(roiMag(:));
    motionScore = min(1.0, (meanMag*3 + maxMag*0.5) / 15);
    motionScore = max(0, motionScore + 0.01*randn());

    %% Colour overlay: highlight moving regions in red
    normMag = min(1, flowMagnitude / max(max(flowMagnitude(:)), 0.001));
    normMag = imgaussfilt(normMag, 2);

    for r = 1:H
        for c = 1:W
            m = normMag(r,c);
            if m > 0.2
                flowImg(r,c,1) = min(255, uint8(double(flowImg(r,c,1))*0.5 + m*200));
                flowImg(r,c,2) = uint8(double(flowImg(r,c,2))*0.6);
                flowImg(r,c,3) = uint8(double(flowImg(r,c,3))*0.6);
            end
        end
    end

    fprintf('   IP[OptFlow]: meanMag=%.3f, score=%.3f\n', meanMag, motionScore);
end

function [laneImg, curveScore, laneInfo] = ip_lane_detection(frame)
%IP_LANE_DETECTION
%  IMAGE PROCESSING MODULE 3 — Lane Detection & Curve Risk
%
%  Pipeline:
%    RGB → Grayscale → ROI Mask → Canny Edges
%    → Hough Transform → Lane Lines → Curvature Estimation
%
%  MATLAB Functions Used:
%    rgb2gray()       - grayscale conversion
%    edge()           - Canny edge detector
%    hough()          - Hough transform for line detection
%    houghpeaks()     - find strongest lines
%    houghlines()     - extract line segments
%    poly1()          - polynomial fit for curve estimation
%
%  MATHEMATICS:
%    Hough Transform maps image space (x,y) to parameter space (ρ,θ):
%      ρ = x·cos(θ) + y·sin(θ)
%    Each edge point votes for all (ρ,θ) it could belong to.
%    Peaks in Hough space = strong lines in image.
%
%    Curvature from polynomial fit:
%      Lane modelled as: x = ay² + by + c
%      Curvature κ = 2a / (1 + (2ay+b)²)^(3/2)

    laneImg   = frame;
    curveScore = 0;
    laneInfo  = struct('leftLane',[],'rightLane',[],'curvature',0);

    H = size(frame,1);
    W = size(frame,2);

    %% Step 1: Grayscale
    gray = rgb2gray(frame);

    %% Step 2: Region of Interest — trapezoidal road area
    roi = zeros(H, W, 'uint8');
    % Trapezoid vertices: bottom-left, top-left, top-right, bottom-right
    polyX = [0,       round(W*0.35), round(W*0.65), W];
    polyY = [H,       round(H*0.50), round(H*0.50), H];
    roiMask = poly2mask(polyX, polyY, H, W);
    roi(roiMask) = gray(roiMask);

    %% Step 3: Canny edges in ROI
    edges = edge(roi, 'Canny', [0.04 0.12]);

    %% Step 4: Hough Transform
    [H_acc, T, R] = hough(edges, 'RhoResolution', 1, 'Theta', -90:0.5:89);

    %% Step 5: Find top lane line peaks
    peaks = houghpeaks(H_acc, 6, 'Threshold', ceil(0.2*max(H_acc(:))));

    %% Step 6: Extract line segments
    lines = houghlines(edges, T, R, peaks, 'FillGap', 40, 'MinLength', 30);

    laneImg = frame;   % start with original frame

    leftLines  = [];
    rightLines = [];

    for k = 1:numel(lines)
        pt1 = lines(k).point1;
        pt2 = lines(k).point2;

        % Draw detected lines in green on frame
        laneImg = draw_line(laneImg, pt1, pt2, [50,220,50]);

        % Classify as left or right lane based on x position & slope
        slope = (pt2(2)-pt1(2)) / max(abs(pt2(1)-pt1(1)), 1);
        midX  = (pt1(1)+pt2(1))/2;

        if midX < W/2 && slope < 0
            leftLines(end+1,:) = [pt1, pt2];
        elseif midX > W/2 && slope > 0
            rightLines(end+1,:) = [pt1, pt2];
        end
    end

    %% Step 7: Estimate curvature from lane positions
    if ~isempty(leftLines) && ~isempty(rightLines)
        % Fit polynomial to left lane x-positions vs y
        leftY  = [leftLines(:,2); leftLines(:,4)];
        leftX  = [leftLines(:,1); leftLines(:,3)];
        rightY = [rightLines(:,2); rightLines(:,4)];
        rightX = [rightLines(:,1); rightLines(:,3)];

        if numel(leftY)>=2 && numel(rightY)>=2
            pL = polyfit(leftY,  leftX,  1);
            pR = polyfit(rightY, rightX, 1);

            % Curvature ≈ difference in slopes (parallel lanes = 0 curvature)
            slopeDiff = abs(pL(1) - pR(1));
            curveScore = min(1.0, slopeDiff * 2);

            laneInfo.leftLane  = pL;
            laneInfo.rightLane = pR;
            laneInfo.curvature = slopeDiff;
        end
    end

    % Draw lane overlay (filled trapezoid)
    if curveScore > 0.3
        % Colour overlay: yellow=warning, red=danger
        overlayCol = uint8([255*curveScore, 255*(1-curveScore), 0]);
        laneImg = draw_lane_overlay(laneImg, curveScore, overlayCol);
    end

    fprintf('   IP[Lane]: %d lines detected, curve score=%.3f\n', ...
            numel(lines), curveScore);
end


%% ---- Helper: draw a line on image ----------------------------------
function img = draw_line(img, pt1, pt2, color)
    x1=round(pt1(1)); y1=round(pt1(2));
    x2=round(pt2(1)); y2=round(pt2(2));
    n = max(abs(x2-x1), abs(y2-y1)) + 1;
    xs = round(linspace(x1,x2,n));
    ys = round(linspace(y1,y2,n));
    H=size(img,1); W=size(img,2);
    for i=1:n
        r=ys(i); c=xs(i);
        if r>=1&&r<=H&&c>=1&&c<=W
            for dr=-1:1
                for dc=-1:1
                    rr=r+dr; cc=c+dc;
                    if rr>=1&&rr<=H&&cc>=1&&cc<=W
                        img(rr,cc,1)=color(1);
                        img(rr,cc,2)=color(2);
                        img(rr,cc,3)=color(3);
                    end
                end
            end
        end
    end
end

%% ---- Helper: draw lane fill overlay --------------------------------
function img = draw_lane_overlay(img, score, color)
    H=size(img,1); W=size(img,2);
    r1=round(H*0.50); r2=H;
    c1=round(W*0.38); c2=round(W*0.62);
    alpha=0.25;
    for r=r1:r2
        % Narrowing trapezoid
        frac=(r-r1)/(r2-r1);
        cl=round(W/2-(W/2-c1)*frac);
        cr=round(W/2+(c2-W/2)*frac);
        cl=max(1,cl); cr=min(W,cr);
        for c=cl:cr
            img(r,c,1)=uint8((1-alpha)*double(img(r,c,1))+alpha*double(color(1)));
            img(r,c,2)=uint8((1-alpha)*double(img(r,c,2))+alpha*double(color(2)));
            img(r,c,3)=uint8((1-alpha)*double(img(r,c,3))+alpha*double(color(3)));
        end
    end
end

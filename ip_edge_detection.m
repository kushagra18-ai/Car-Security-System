function [edgeImg, potholeScore, potholeRegions] = ip_edge_detection(frame)
%IP_EDGE_DETECTION
%  IMAGE PROCESSING MODULE 1 — Road Surface Anomaly Detection
%
%  Pipeline:
%    RGB frame → Grayscale → Gaussian Blur → Canny Edge Detection
%    → Region Analysis → Pothole Score
%
%  MATLAB Functions Used:
%    rgb2gray()     - colour space conversion
%    imgaussfilt()  - Gaussian smoothing (reduces noise)
%    edge()         - Canny edge detector
%    bwlabel()      - connected component labelling
%    regionprops()  - measure region properties
%
%  MATHEMATICS:
%    Canny uses gradient magnitude: |∇I| = √(Gx² + Gy²)
%    where Gx, Gy are Sobel convolutions of the image.
%    Edges above high threshold kept, below low threshold removed,
%    in-between kept only if connected to strong edge (hysteresis).

    %% Step 1: Convert to grayscale
    grayImg = rgb2gray(frame);

    %% Step 2: Gaussian blur to remove noise
    %  G(x,y) = (1/2πσ²) * exp(-(x²+y²)/2σ²)
    blurred = imgaussfilt(grayImg, 1.5);

    %% Step 3: Canny edge detection
    %  Detects boundaries of objects and road anomalies
    edgeImg = edge(blurred, 'Canny', [0.05 0.15]);

    %% Step 4: Focus on road region (lower 55% of image)
    H = size(edgeImg, 1);
    roadMask = false(size(edgeImg));
    roadMask(round(H*0.45):end, :) = true;
    roadEdges = edgeImg & roadMask;

    %% Step 5: Find connected regions (potential potholes)
    [labelMatrix, numRegions] = bwlabel(roadEdges);
    potholeRegions = regionprops(labelMatrix, 'Area', 'Centroid', 'BoundingBox');

    %% Step 6: Classify regions as potholes
    %  Potholes = roughly circular, area 50-2000 px²
    potholeScore = 0;
    for i = 1:numRegions
        area = potholeRegions(i).Area;
        bbox = potholeRegions(i).BoundingBox;
        % Circularity: aspect ratio close to 1 = circular = pothole
        aspectRatio = bbox(3) / max(bbox(4), 1);
        if area > 40 && area < 2000 && aspectRatio > 0.3 && aspectRatio < 3.5
            % Normalised contribution to pothole score
            contribution = min(0.3, area / 2000);
            potholeScore = min(1.0, potholeScore + contribution);
        end
    end

    fprintf('   IP[Edge]: %d edge regions, pothole score=%.3f\n', ...
            numRegions, potholeScore);
end

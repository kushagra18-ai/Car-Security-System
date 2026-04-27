function [annotatedFrame, detectedObjects] = ip_object_detection(frame)
%IP_OBJECT_DETECTION
%  IMAGE PROCESSING MODULE 2 — Vehicle & Pedestrian Detection
%
%  Pipeline:
%    RGB frame → HSV colour segmentation → Morphological ops
%    → Blob detection → Bounding boxes → Object classification
%
%  MATLAB Functions Used:
%    rgb2hsv()         - convert to Hue-Saturation-Value space
%    imbinarize()      - threshold segmentation
%    imopen()          - morphological opening (noise removal)
%    imclose()         - morphological closing (fill gaps)
%    bwlabel()         - label connected components
%    regionprops()     - extract blob properties
%    insertShape()     - draw bounding boxes on image
%    insertText()      - label detected objects
%
%  MATHEMATICS:
%    HSV segmentation isolates objects by colour range.
%    Morphological ops use structuring element B:
%      Opening:  A ∘ B = (A ⊖ B) ⊕ B  (erode then dilate)
%      Closing:  A • B = (A ⊕ B) ⊖ B  (dilate then erode)

    annotatedFrame = frame;
    detectedObjects = struct('Label',{},'BBox',{},'Confidence',{},'ThreatLevel',{});
    objCount = 0;

    H = size(frame,1);
    W = size(frame,2);

    %% Step 1: Convert to HSV for colour-based segmentation
    hsvImg = rgb2hsv(frame);

    %% Step 2: Detect RED/DARK objects (vehicles)
    % Vehicles appear as dark-red rectangles in synthetic frame
    redMask = (hsvImg(:,:,1) < 0.08 | hsvImg(:,:,1) > 0.92) & ...
               hsvImg(:,:,2) > 0.3 & ...
               hsvImg(:,:,3) > 0.1;

    % Morphological cleanup
    se = strel('rectangle', [5, 8]);
    redMask = imopen(redMask, se);
    redMask = imclose(redMask, strel('rectangle',[10,15]));

    % Focus on upper road region (vehicles appear near horizon)
    roadStart = round(H*0.44);
    vehicleMask = false(size(redMask));
    vehicleMask(roadStart:round(H*0.80), :) = redMask(roadStart:round(H*0.80), :);

    [lblV, nV] = bwlabel(vehicleMask);
    propsV = regionprops(lblV, 'Area','BoundingBox','Centroid');

    for i = 1:nV
        if propsV(i).Area < 200, continue; end
        bb = propsV(i).BoundingBox;
        ar = bb(3)/max(bb(4),1);
        if ar < 0.5 || ar > 5, continue; end

        % Confidence based on area (larger = closer = more confident)
        conf = min(0.99, 0.5 + propsV(i).Area/3000);
        objCount = objCount+1;
        detectedObjects(objCount).Label       = 'VEHICLE';
        detectedObjects(objCount).BBox        = bb;
        detectedObjects(objCount).Confidence  = conf;
        detectedObjects(objCount).ThreatLevel = min(1, conf*1.1);

        % Draw bounding box (red)
        annotatedFrame = draw_bbox(annotatedFrame, bb, [255,50,50], ...
            sprintf('CAR %.0f%%', conf*100));
    end

    %% Step 3: Detect ORANGE objects (pedestrians)
    pedMask = hsvImg(:,:,1) > 0.05 & hsvImg(:,:,1) < 0.12 & ...
              hsvImg(:,:,2) > 0.5  & hsvImg(:,:,3) > 0.4;

    se2 = strel('rectangle',[3,3]);
    pedMask = imopen(pedMask, se2);
    pedMask = imclose(pedMask, strel('rectangle',[8,5]));

    pedZone = false(size(pedMask));
    pedZone(roadStart:round(H*0.85), :) = pedMask(roadStart:round(H*0.85), :);

    [lblP, nP] = bwlabel(pedZone);
    propsP = regionprops(lblP, 'Area','BoundingBox','Centroid');

    for i = 1:nP
        if propsP(i).Area < 60, continue; end
        bb  = propsP(i).BoundingBox;
        ar  = bb(4)/max(bb(3),1);   % pedestrians taller than wide
        if ar < 0.8, continue; end

        conf = min(0.99, 0.4 + propsP(i).Area/800);
        objCount = objCount+1;
        detectedObjects(objCount).Label       = 'PEDESTRIAN';
        detectedObjects(objCount).BBox        = bb;
        detectedObjects(objCount).Confidence  = conf;
        detectedObjects(objCount).ThreatLevel = min(1, conf*1.3);

        % Draw bounding box (orange)
        annotatedFrame = draw_bbox(annotatedFrame, bb, [255,160,0], ...
            sprintf('PED %.0f%%', conf*100));
    end

    fprintf('   IP[ObjDet]: %d vehicles, %d pedestrians detected\n', nV, nP);
end


%% ---- Helper: draw bounding box on image ----------------------------
function img = draw_bbox(img, bb, color, label)
    x1 = max(1,   round(bb(1)));
    y1 = max(1,   round(bb(2)));
    x2 = min(size(img,2), round(bb(1)+bb(3)));
    y2 = min(size(img,1), round(bb(2)+bb(4)));
    if x1>=x2||y1>=y2, return; end

    thick = 2;
    % Top & bottom bars
    img(y1:min(size(img,1),y1+thick), x1:x2, 1) = color(1);
    img(y1:min(size(img,1),y1+thick), x1:x2, 2) = color(2);
    img(y1:min(size(img,1),y1+thick), x1:x2, 3) = color(3);
    img(max(1,y2-thick):y2, x1:x2, 1) = color(1);
    img(max(1,y2-thick):y2, x1:x2, 2) = color(2);
    img(max(1,y2-thick):y2, x1:x2, 3) = color(3);
    % Left & right bars
    img(y1:y2, x1:min(size(img,2),x1+thick), 1) = color(1);
    img(y1:y2, x1:min(size(img,2),x1+thick), 2) = color(2);
    img(y1:y2, x1:min(size(img,2),x1+thick), 3) = color(3);
    img(y1:y2, max(1,x2-thick):x2, 1) = color(1);
    img(y1:y2, max(1,x2-thick):x2, 2) = color(2);
    img(y1:y2, max(1,x2-thick):x2, 3) = color(3);

    % Label background
    lh = 14; lw = min(size(img,2)-x1, length(label)*7+4);
    ly = max(1, y1-lh);
    img(ly:ly+lh, x1:min(size(img,2),x1+lw), 1) = color(1);
    img(ly:ly+lh, x1:min(size(img,2),x1+lw), 2) = color(2);
    img(ly:ly+lh, x1:min(size(img,2),x1+lw), 3) = color(3);
end

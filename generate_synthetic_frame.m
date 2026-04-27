function frame = generate_synthetic_frame(egoPos, poses, simTime)
%GENERATE_SYNTHETIC_FRAME
%  Creates a synthetic RGB camera frame (640x360) from scenario data.
%  This simulates what a front-facing car camera would see.
%  Used as input to all image processing pipelines.
%
%  The frame contains:
%    - Sky gradient (top half)
%    - Road surface with lane markings (bottom half)
%    - Other vehicles as coloured rectangles (perspective projected)
%    - Pedestrians as smaller shapes
%    - Pothole texture patches on road surface

    W = 640; H = 360;
    frame = zeros(H, W, 3, 'uint8');

    %% ---- Sky (top half) -------------------------------------------
    for row = 1:round(H*0.45)
        brightness = uint8(60 + 80*(row/(H*0.45)));
        frame(row, :, 1) = brightness * 0.6;
        frame(row, :, 2) = brightness * 0.75;
        frame(row, :, 3) = brightness;
    end

    %% ---- Road surface (bottom half) --------------------------------
    horizonRow = round(H * 0.45);
    for row = horizonRow:H
        brightness = uint8(55 + 30*((row-horizonRow)/(H-horizonRow)));
        frame(row, :, 1) = brightness;
        frame(row, :, 2) = brightness;
        frame(row, :, 3) = brightness;
    end

    %% ---- Lane markings (perspective) -------------------------------
    % Left lane edge
    for t = 0:0.01:1
        col = round(W*0.5 - (W*0.4)*(1-t));
        row = round(horizonRow + (H-horizonRow)*t);
        if col>=1&&col<=W&&row>=1&&row<=H
            frame(max(1,row-1):min(H,row+1), max(1,col-1):min(W,col+1), :) = 220;
        end
    end
    % Right lane edge
    for t = 0:0.01:1
        col = round(W*0.5 + (W*0.4)*(1-t));
        row = round(horizonRow + (H-horizonRow)*t);
        if col>=1&&col<=W&&row>=1&&row<=H
            frame(max(1,row-1):min(H,row+1), max(1,col-1):min(W,col+1), :) = 220;
        end
    end
    % Centre dashed line
    for seg = 0:4
        for t = 0.05:0.005:0.15
            tval = seg*0.2 + t;
            if tval>1, break; end
            col = round(W*0.5);
            row = round(horizonRow + (H-horizonRow)*tval);
            if row>=1&&row<=H
                frame(max(1,row-1):min(H,row+1), max(1,col-2):min(W,col+2), 1) = 230;
                frame(max(1,row-1):min(H,row+1), max(1,col-2):min(W,col+2), 2) = 210;
                frame(max(1,row-1):min(H,row+1), max(1,col-2):min(W,col+2), 3) = 50;
            end
        end
    end

    %% ---- Pothole patches on road ----------------------------------
    potholeX = [40, 130, 220];
    for i = 1:numel(potholeX)
        dist = abs(egoPos(1) - potholeX(i));
        if dist < 30
            % Project pothole onto image
            scale  = max(0.1, 1 - dist/30);
            pcol   = round(W*0.5 + 20*randn());
            prow   = round(H*0.75 + (H*0.2)*scale);
            pradius= round(15*scale);
            if prow>=1&&prow<=H&&pcol>=1&&pcol<=W
                r1=max(1,prow-pradius); r2=min(H,prow+pradius);
                c1=max(1,pcol-pradius); c2=min(W,pcol+pradius);
                frame(r1:r2, c1:c2, 1) = 35;
                frame(r1:r2, c1:c2, 2) = 30;
                frame(r1:r2, c1:c2, 3) = 30;
            end
        end
    end

    %% ---- Other vehicles (perspective projection) ------------------
    for k = 1:numel(poses)
        p = poses(k);
        if p.ClassID ~= 1, continue; end
        fwdDist = p.Position(1);
        if fwdDist <= 1 || fwdDist > 80, continue; end

        % Perspective: closer = lower and larger
        scale  = 60 / fwdDist;
        pcol   = round(W/2 - p.Position(2) * scale * 3);
        prow   = round(horizonRow + scale * 8);
        bw     = round(60 * scale);
        bh     = round(35 * scale);

        r1=max(1,prow); r2=min(H,prow+bh);
        c1=max(1,pcol-bw/2); c2=min(W,pcol+bw/2);
        if r1<r2 && c1<c2
            % Car body
            frame(r1:r2, round(c1):round(c2), 1) = 180;
            frame(r1:r2, round(c1):round(c2), 2) = 50;
            frame(r1:r2, round(c1):round(c2), 3) = 50;
            % Windshield
            wr1=r1+2; wr2=r1+round(bh*0.4);
            wc1=round(c1+bw*0.2); wc2=round(c2-bw*0.2);
            if wr1<wr2&&wc1<wc2
                frame(wr1:wr2,wc1:wc2,1)=150;
                frame(wr1:wr2,wc1:wc2,2)=200;
                frame(wr1:wr2,wc1:wc2,3)=220;
            end
        end
    end

    %% ---- Pedestrians ----------------------------------------------
    for k = 1:numel(poses)
        p = poses(k);
        if p.ClassID ~= 4, continue; end
        fwdDist = p.Position(1);
        if fwdDist <= 1 || fwdDist > 40, continue; end

        scale = 40 / fwdDist;
        pcol  = round(W/2 - p.Position(2)*scale*3);
        prow  = round(horizonRow + scale*6);
        bw    = round(18*scale);
        bh    = round(40*scale);

        r1=max(1,prow); r2=min(H,prow+bh);
        c1=max(1,pcol-round(bw/2)); c2=min(W,pcol+round(bw/2));
        if r1<r2&&c1<c2
            frame(r1:r2,c1:c2,1)=255;
            frame(r1:r2,c1:c2,2)=160;
            frame(r1:r2,c1:c2,3)=50;
        end
    end

    %% ---- Night effect (after t=25s) --------------------------------
    if simTime > 25
        darkFactor = max(0.3, 1 - (simTime-25)/10);
        frame = uint8(double(frame) * darkFactor);
        % Headlight cone
        frame(horizonRow:H, round(W*0.35):round(W*0.65), :) = ...
            min(255, uint8(double(frame(horizonRow:H, round(W*0.35):round(W*0.65), :)) * 2.5));
    end
end

function run_moving_simulation(scenario, egoVehicle, cfg)
%RUN_MOVING_SIMULATION  Main loop with full image processing pipeline
%                        and audio warning system.

    %% ---- Dashboard ------------------------------------------------
    fig = figure('Name','AI Road Security - Image Processing Pipeline', ...
                 'NumberTitle','off','Color',[0.04 0.04 0.06], ...
                 'Position',[20 20 1300 780]);

    axBEV = subplot(3,4,[1 2 5 6]);
    set(axBEV,'Color',[0.04 0.06 0.04],'XColor','w','YColor','w');

    axCAM = subplot(3,4,3);
    set(axCAM,'XTick',[],'YTick',[]);
    title(axCAM,'RAW CAMERA FRAME','Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');

    axEDGE = subplot(3,4,4);
    set(axEDGE,'XTick',[],'YTick',[]);
    title(axEDGE,'CANNY EDGES','Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');

    axOBJ = subplot(3,4,7);
    set(axOBJ,'XTick',[],'YTick',[]);
    title(axOBJ,'OBJECT DETECTION','Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');

    axLANE = subplot(3,4,8);
    set(axLANE,'XTick',[],'YTick',[]);
    title(axLANE,'LANE DETECTION','Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');

    axTL = subplot(3,4,[9 10]);
    set(axTL,'Color',[0.04 0.04 0.06],'XColor','w','YColor','w');
    title(axTL,'THREAT SCORE TIMELINE','Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');
    xlabel(axTL,'Time (s)'); ylabel(axTL,'Score');
    hold(axTL,'on'); ylim(axTL,[0 1]);

    axBAR = subplot(3,4,[11 12]);
    set(axBAR,'Color',[0.04 0.04 0.06],'XColor','w','YColor','w');

    %% ---- State Variables ------------------------------------------
    simTime       = 0;
    frameCount    = 0;
    tHistory      = [];
    sHistory      = [];
    prevFrame     = [];
    prevEgoPos    = egoVehicle.Position;
    prevEgoTime   = 0;
    egoSpeed      = 16.7;
    alertLog      = {};
    prevScore     = 0;        % for sound transition detection

    %% Start timer for sound system
    tic;

    %% ================================================================
    %  MAIN SIMULATION LOOP
    %% ================================================================
    while advance(scenario)

        simTime    = simTime + scenario.SampleTime;
        frameCount = frameCount + 1;

        %% Ego speed estimate
        egoPos = egoVehicle.Position;
        dt = simTime - prevEgoTime;
        if dt > 0.001
            dpos     = egoPos - prevEgoPos;
            egoSpeed = norm(dpos(1:2)) / dt;
        end
        prevEgoPos  = egoPos;
        prevEgoTime = simTime;

        %% Get actor poses
        poses = targetPoses(egoVehicle);

        %% Step 1: Synthetic camera frame
        frame = generate_synthetic_frame(egoPos, poses, simTime);

        %% Step 2: Canny Edge Detection -> Pothole
        [edgeImg, potholeScore, ~] = ip_edge_detection(frame);

        %% Step 3: HSV Object Detection -> Cars & Peds
        [objFrame, detObjects] = ip_object_detection(frame);
        collisionScore = 0;
        pedScore       = 0;
        for d = 1:numel(detObjects)
            if strcmp(detObjects(d).Label,'VEHICLE')
                collisionScore = max(collisionScore, detObjects(d).ThreatLevel);
            elseif strcmp(detObjects(d).Label,'PEDESTRIAN')
                pedScore = max(pedScore, detObjects(d).ThreatLevel);
            end
        end

        %% Step 4: Hough Lane Detection -> Curve Risk
        [laneFrame, curveScore, ~] = ip_lane_detection(frame);

        %% Step 5: Optical Flow -> Motion
        [~, motionScore, ~] = ip_optical_flow(prevFrame, frame);
        prevFrame = frame;

        %% Step 6: Histogram Analysis -> Visibility
        [~, visScore, conditions] = ip_histogram_analysis(frame);
        visMultiplier = 1 + (1 - visScore) * 0.4;

        %% Step 7: Fuse scores -> Overall Threat
        weights   = [0.20, 0.30, 0.20, 0.15, 0.15];
        rawScores = [potholeScore, collisionScore, pedScore, curveScore, motionScore];
        rawFused  = sum(weights .* rawScores) * visMultiplier;
        overall   = 1 / (1 + exp(-6*(rawFused - 0.5)));
        overall   = max(0, min(1, overall));

        tHistory(end+1) = overall;
        sHistory(end+1) = simTime;

        %% ============================================================
        %  STEP 8: PLAY WARNING SOUND based on threat level
        %% ============================================================
        play_warning_sound(overall, prevScore);
        prevScore = overall;

        %% Log alerts
        if potholeScore   > 0.5
            alertLog{end+1} = sprintf('[%.1fs] POTHOLE DETECTED (score=%.2f)', simTime, potholeScore);
        end
        if collisionScore > 0.6
            alertLog{end+1} = sprintf('[%.1fs] VEHICLE THREAT (score=%.2f)', simTime, collisionScore);
        end
        if pedScore       > 0.5
            alertLog{end+1} = sprintf('[%.1fs] PEDESTRIAN DETECTED (score=%.2f)', simTime, pedScore);
        end
        if curveScore     > 0.5
            alertLog{end+1} = sprintf('[%.1fs] CURVE RISK (score=%.2f)', simTime, curveScore);
        end

        %% Update Dashboard every 3 frames
        if mod(frameCount, 3) == 0

            %% BEV
            cla(axBEV);
            try
                plot(scenario,'Parent',axBEV);
                set(axBEV,'Color',[0.04 0.06 0.04],'XColor','w','YColor','w');
            catch
                draw_bev(axBEV, egoPos, poses, cfg);
            end
            tCol = threat_color(overall);
            title(axBEV, sprintf('BEV | t=%.1fs | Speed=%.0f km/h | THREAT: %.2f [%s]', ...
                simTime, egoSpeed*3.6, overall, threat_label(overall)), ...
                'Color', tCol, 'FontWeight','bold','FontSize',9);

            %% Sound status indicator on BEV
            soundStr = get_sound_label(overall);
            text(axBEV, 5, -5, soundStr, 'Color', tCol, ...
                'FontSize', 9, 'FontWeight','bold');

            %% Raw Camera
            imshow(frame,'Parent',axCAM);
            title(axCAM, sprintf('CAMERA [%s]', conditions), ...
                'Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');

            %% Edge Detection
            edgeRGB = repmat(uint8(edgeImg)*255,[1,1,3]);
            imshow(edgeRGB,'Parent',axEDGE);
            title(axEDGE, sprintf('CANNY EDGES | Pothole=%.2f', potholeScore), ...
                'Color', threat_color(potholeScore),'FontSize',8,'FontWeight','bold');

            %% Object Detection
            imshow(objFrame,'Parent',axOBJ);
            title(axOBJ, sprintf('OBJECTS | Car=%.2f Ped=%.2f', collisionScore, pedScore), ...
                'Color', threat_color(max(collisionScore,pedScore)),'FontSize',8,'FontWeight','bold');

            %% Lane Detection
            imshow(laneFrame,'Parent',axLANE);
            title(axLANE, sprintf('LANES | Curve=%.2f', curveScore), ...
                'Color', threat_color(curveScore),'FontSize',8,'FontWeight','bold');

            %% Threat Timeline
            cla(axTL);
            plot(axTL, sHistory, tHistory, 'Color',[0 0.85 1],'LineWidth',1.5);
            yline(axTL, 0.7,'r--','LineWidth',1.2);
            yline(axTL, 0.4,'y--','LineWidth',1.0);
            ylim(axTL,[0 1]);
            set(axTL,'Color',[0.04 0.04 0.06],'XColor','w','YColor','w');
            title(axTL, sprintf('OVERALL THREAT: %.3f [%s]  |  %s', ...
                overall, threat_label(overall), soundStr), ...
                'Color', threat_color(overall),'FontWeight','bold','FontSize',9);

            %% Threat Breakdown Bars
            cla(axBAR);
            scoreVals = [potholeScore, collisionScore, pedScore, curveScore, motionScore];
            barClrs   = [0.9 0.4 0; 1 0.1 0.1; 1 0.6 0; 0.2 0.8 1; 0.7 0.2 0.9];
            b = barh(axBAR, scoreVals);
            b.FaceColor = 'flat';
            for bi = 1:5
                b.CData(bi,:) = barClrs(bi,:);
            end
            set(axBAR,'YTickLabel',{'POTHOLE','COLLISION','PEDESTRIAN','CURVE','MOTION'}, ...
                'XLim',[0 1],'Color',[0.04 0.04 0.06],'XColor','w','YColor','w','FontSize',8);
            xline(axBAR, 0.7,'r--','LineWidth',1.5);
            xline(axBAR, 0.4,'y--','LineWidth',1.0);
            title(axBAR, sprintf('IP THREAT SCORES | Vis: %.0f%% [%s]', visScore*100, conditions), ...
                'Color',[0 0.9 1],'FontSize',8,'FontWeight','bold');
        end

        drawnow limitrate;
    end

    %% ---- Final Alert Log ------------------------------------------
    fprintf('\n======== IMAGE PROCESSING ALERT LOG ========\n');
    for i = 1:numel(alertLog)
        fprintf('  %s\n', alertLog{i});
    end
    fprintf('=============================================\n');

    %% ---- Final Threat Plot ----------------------------------------
    figure('Name','Full Threat Timeline','Color',[0.04 0.04 0.06]);
    plot(sHistory, tHistory, 'c-', 'LineWidth', 2);
    hold on;
    yline(0.7,'r--','DANGER','LineWidth',1.5,'LabelHorizontalAlignment','left');
    yline(0.4,'y--','WARNING','LineWidth',1.2,'LabelHorizontalAlignment','left');
    xlabel('Time (s)','Color','w');
    ylabel('Threat Score','Color','w');
    title('Full Simulation Threat Score','Color','w','FontSize',12);
    set(gca,'Color',[0.08 0.08 0.08],'XColor','w','YColor','w');
    ylim([0 1]); grid on; hold off;
end


%% ====================================================================
%  LOCAL HELPERS
%% ====================================================================
function col = threat_color(s)
    if s >= 0.7,     col = [1 0.1 0.1];
    elseif s >= 0.4, col = [1 0.6 0];
    else,            col = [0.1 1 0.4];
    end
end

function l = threat_label(s)
    if s >= 0.7,     l = 'DANGER';
    elseif s >= 0.4, l = 'WARNING';
    else,            l = 'SAFE';
    end
end

function l = get_sound_label(s)
    if s >= 0.7,     l = '[SOUND: ALARM - BEEP BEEP BEEP]';
    elseif s >= 0.4, l = '[SOUND: WARNING - DOUBLE BEEP]';
    else,            l = '[SOUND: SILENT]';
    end
end

function draw_bev(ax, egoPos, poses, cfg)
    hold(ax,'on');
    fill(ax,[-5 305 305 -5],[-8 -8 8 8],[0.12 0.12 0.12],'EdgeColor','none');
    for x = 0:20:300
        plot(ax,[x x+10],[0 0],'y--','LineWidth',1);
    end
    for i = 1:numel(cfg.pothole.zones)
        plot(ax, cfg.pothole.zones(i), 0, 'mx','MarkerSize',14,'LineWidth',2.5);
        text(ax, cfg.pothole.zones(i), 3,'POTHOLE', ...
            'Color','m','FontSize',7,'HorizontalAlignment','center');
    end
    rectangle('Parent',ax,'Position',[egoPos(1)-2.25, egoPos(2)-1, 4.5, 2], ...
        'FaceColor',[0 0.7 0.3],'EdgeColor',[0 1 0.5],'LineWidth',2,'Curvature',0.2);
    text(ax, egoPos(1), egoPos(2)+2.2,'EGO', ...
        'Color',[0 1 0.5],'FontSize',7,'HorizontalAlignment','center','FontWeight','bold');
    for k = 1:numel(poses)
        p  = poses(k);
        wx = egoPos(1) + p.Position(1);
        wy = egoPos(2) + p.Position(2);
        if p.ClassID == 4
            plot(ax, wx, wy,'o','MarkerFaceColor',[1 0.5 0], ...
                'MarkerEdgeColor','w','MarkerSize',10);
            text(ax,wx,wy+2,'PED','Color',[1 0.6 0],'FontSize',7,'HorizontalAlignment','center');
        else
            rectangle('Parent',ax,'Position',[wx-2.25,wy-1,4.5,2], ...
                'FaceColor',[0.8 0.1 0.1],'EdgeColor','w','LineWidth',1,'Curvature',0.1);
            text(ax,wx,wy+2,'CAR','Color',[1 0.3 0.3],'FontSize',7,'HorizontalAlignment','center');
        end
    end
    set(ax,'Color',[0.04 0.06 0.04],'XColor','w','YColor','w');
    axis(ax,'equal');
    hold(ax,'off');
end

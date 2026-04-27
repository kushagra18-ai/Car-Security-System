function cfg = init_threat_detectors()
%INIT_THREAT_DETECTORS
%  Defines all software-based threat detector configurations.
%  No physical sensors — pure mathematical models.
%  UPDATED: Increased all detection ranges for real-world accuracy.

    %% Pothole Detector
    %  CHANGED: radius 8m -> 25m (gives ~1.5 sec warning at 60 km/h)
    cfg.pothole.zones     = [40, 130, 220];
    cfg.pothole.radius    = 25;               % was 8
    cfg.pothole.severity  = [0.6, 0.8, 0.5];

    %% Collision Detector
    %  CHANGED: maxRange 60m -> 120m
    %  CHANGED: alertTTC  3.0s -> 5.0s  (warn earlier)
    %  CHANGED: dangerTTC 1.5s -> 2.5s  (more reaction time)
    cfg.collision.maxRange  = 120;            % was 60
    cfg.collision.alertTTC  = 5.0;            % was 3.0
    cfg.collision.dangerTTC = 2.5;            % was 1.5

    %% Pedestrian Detector
    %  CHANGED: alertDist  20m -> 35m
    %  CHANGED: dangerDist  8m -> 15m
    cfg.pedestrian.alertDist  = 35;           % was 20
    cfg.pedestrian.dangerDist = 15;           % was 8

    %% Curve Risk Detector
    %  CHANGED: influence zone 20m -> 35m (detect curves earlier)
    cfg.curve.dangerThreshold = 50;
    cfg.curve.influenceZone   = 35;           % was 20 (hardcoded)

    %% Tailgating Detector
    %  CHANGED: safeTimeGap 2.0s -> 3.0s (stricter following distance)
    cfg.tailgate.safeTimeGap = 3.0;           % was 2.0

    fprintf('   -> Threat detectors initialised with EXTENDED ranges:\n');
    fprintf('      Pothole   : radius = 25 m  (was 8 m)\n');
    fprintf('      Collision : range  = 120 m (was 60 m), TTC alert = 5.0s\n');
    fprintf('      Pedestrian: alert  = 35 m  (was 20 m)\n');
    fprintf('      Tailgate  : gap    = 3.0s  (was 2.0s)\n');
end

%% =========================================================
%  AI-DRIVEN VEHICLE SECURITY SYSTEM
%  Image Processing Based Threat Detection
%  Moving car — software-only, no physical sensors
%
%  IMAGE PROCESSING MODULES:
%    1. Canny Edge Detection     → Pothole detection
%    2. HSV Object Detection     → Cars & pedestrians
%    3. Hough Transform          → Lane detection & curve risk
%    4. Lucas-Kanade Optical Flow→ Motion & collision detection
%    5. Histogram + CLAHE        → Visibility analysis
%
%  SUBMITTED BY:
%    Jessica Goel      2401190033
%    Aditi Gupta       2401190047
%    Kushagra Rastogi  2401190048
%  SUBMITTED TO: Prof. Juhi Gupta
%  COURSE: Applied Mathematical Computation (24B35EC212)
% ==========================================================

clc; clear; close all;

fprintf('==============================================\n');
fprintf('   AI-DRIVEN VEHICLE SECURITY SYSTEM\n');
fprintf('   Image Processing Based Threat Detection\n');
fprintf('   JIIT | Applied Mathematical Computation\n');
fprintf('==============================================\n\n');

fprintf('[1/4] Building virtual road environment...\n');
[scenario, egoVehicle] = build_road_scenario();

fprintf('[2/4] Initialising image processing threat detectors...\n');
detectorConfig = init_threat_detectors();

fprintf('[3/4] Running image processing simulation...\n');
fprintf('      IP Pipeline: Edge → Object → Lane → OptFlow → Histogram\n\n');
run_moving_simulation(scenario, egoVehicle, detectorConfig);

fprintf('[4/4] Simulation complete.\n');
display_report();

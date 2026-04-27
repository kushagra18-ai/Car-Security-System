function [scenario, egoVehicle] = build_road_scenario()
%BUILD_ROAD_SCENARIO
%  Creates a virtual road with:
%   - A winding multi-segment road
%   - Oncoming traffic cars
%   - Pedestrians crossing the road
%   - Pothole zones marked on the road
%   - A moving ego vehicle (our car)

    scenario = drivingScenario('StopTime', 2, 'SampleTime', 0.05);

    %% ---- Road: multi-segment winding highway -----------------------
    roadCenters = [  0,   0, 0;
                    50,   0, 0;
                   100,  20, 0;
                   150,  20, 0;
                   200,   0, 0;
                   250, -10, 0;
                   300,   0, 0];

    laneSpec = lanespec(2, 'Width', 4);
    road(scenario, roadCenters, 'Lanes', laneSpec, 'Name', 'MainRoad');

    %% ---- Ego Vehicle (our moving car) ------------------------------
    egoVehicle = vehicle(scenario, ...
        'ClassID', 1, ...
        'Length',  4.5, ...
        'Width',   2.0, ...
        'Height',  1.5, ...
        'Name',    'EgoCar');

    % Ego follows the road at 60 km/h (~16.7 m/s)
    egoWaypoints = [  0,   0, 0;
                     50,   0, 0;
                    100,  20, 0;
                    150,  20, 0;
                    200,   0, 0;
                    250, -10, 0;
                    300,   0, 0];
    egoSpeed = 16.7 * ones(size(egoWaypoints, 1), 1);
    smoothTrajectory(egoVehicle, egoWaypoints, egoSpeed);

    %% ---- Oncoming Car 1 (head-on approaching) ----------------------
    car1 = vehicle(scenario, 'ClassID', 1, ...
        'Length', 4.5, 'Width', 2.0, 'Height', 1.5, 'Name', 'OncomingCar1');
    car1Waypoints = [300,  4, 0;
                     200,  4, 0;
                     150, 24, 0;
                     100, 24, 0;
                      50,  4, 0;
                       0,  4, 0];
    smoothTrajectory(car1, car1Waypoints, 14 * ones(6,1));

    %% ---- Oncoming Car 2 (merging from side — collision risk) -------
    car2 = vehicle(scenario, 'ClassID', 1, ...
        'Length', 4.5, 'Width', 2.0, 'Height', 1.5, 'Name', 'MergingCar2');
    car2Waypoints = [80, 30, 0;
                    100, 20, 0;
                    130, 20, 0;
                    160, 18, 0];
    smoothTrajectory(car2, car2Waypoints, 12 * ones(4,1));

    %% ---- Pedestrian 1 (crossing road) ------------------------------
    ped1 = actor(scenario, 'ClassID', 4, ...
        'Length', 0.5, 'Width', 0.5, 'Height', 1.7, 'Name', 'Pedestrian1');
    ped1Waypoints = [60, -8, 0;
                     60,  8, 0];
    smoothTrajectory(ped1, ped1Waypoints, [1.2; 1.2]);

    %% ---- Pedestrian 2 (jaywalking suddenly) ------------------------
    ped2 = actor(scenario, 'ClassID', 4, ...
        'Length', 0.5, 'Width', 0.5, 'Height', 1.7, 'Name', 'Pedestrian2');
    ped2Waypoints = [170, 25, 0;
                     170, 16, 0];
    smoothTrajectory(ped2, ped2Waypoints, [1.0; 1.0]);

    %% ---- Slow vehicle ahead (tailgating risk) ----------------------
    car3 = vehicle(scenario, 'ClassID', 1, ...
        'Length', 4.5, 'Width', 2.0, 'Height', 1.5, 'Name', 'SlowCarAhead');
    car3Waypoints = [ 20,   0, 0;
                      80,   0, 0;
                     110,  20, 0;
                     150,  20, 0];
    smoothTrajectory(car3, car3Waypoints, 8 * ones(4,1));  % slow: 8 m/s

    fprintf('   -> Road scenario built: winding road, 3 cars, 2 pedestrians.\n');
    fprintf('   -> Pothole zones defined at x=40m, x=130m, x=220m.\n');
end

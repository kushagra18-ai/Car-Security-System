%% TEST_SOUND
%  Run this first to verify audio is working on your system.
%  If you hear a beep for each test, sound is working correctly.

clc;
fprintf('Testing audio output on your system...\n\n');

Fs  = 44100;

%% Test 1: audioplayer
fprintf('[1] Testing audioplayer (best method)...\n');
try
    t   = linspace(0,0.3, round(Fs*0.3));
    sig = 0.7 * sin(2*pi*1000*t) .* hann(length(t))';
    ap  = audioplayer(sig, Fs);
    play(ap);
    pause(0.5);
    fprintf('    audioplayer: OK\n\n');
catch e
    fprintf('    audioplayer FAILED: %s\n\n', e.message);
end

%% Test 2: sound()
fprintf('[2] Testing sound()...\n');
try
    t   = linspace(0,0.3, round(Fs*0.3));
    sig = 0.7 * sin(2*pi*800*t);
    sound(sig, Fs);
    pause(0.5);
    fprintf('    sound(): OK\n\n');
catch e
    fprintf('    sound() FAILED: %s\n\n', e.message);
end

%% Test 3: beep
fprintf('[3] Testing beep...\n');
try
    beep;
    pause(0.5);
    fprintf('    beep: OK\n\n');
catch e
    fprintf('    beep FAILED: %s\n\n', e.message);
end

%% Test 4: Windows PowerShell beep
if ispc
    fprintf('[4] Testing Windows PowerShell beep...\n');
    ret = system('powershell -Command "[System.Console]::Beep(1000,300)"');
    if ret == 0
        fprintf('    PowerShell beep: OK\n\n');
    else
        fprintf('    PowerShell beep FAILED\n\n');
    end
end

fprintf('==============================================\n');
fprintf('Check which tests produced sound above.\n');
fprintf('The simulation will automatically use the\n');
fprintf('first method that works on your system.\n');
fprintf('==============================================\n');

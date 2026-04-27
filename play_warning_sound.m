function play_warning_sound(threatLevel, prevThreatLevel)
%PLAY_WARNING_SOUND
%  Plays audio alerts using multiple methods to ensure sound works.
%  Tries: audioplayer -> sound -> beep (fallback chain)

    persistent lastSoundTime lastLevel;
    if isempty(lastSoundTime), lastSoundTime = -999; end
    if isempty(lastLevel),     lastLevel     = 'SAFE'; end

    currLevel = get_level(threatLevel);
    prevLevel = get_level(prevThreatLevel);

    %% Decide whether to play
    tNow = toc;
    timeSinceLast = tNow - lastSoundTime;

    shouldPlay = false;
    if ~strcmp(currLevel, prevLevel)
        shouldPlay = true;   % level changed
    elseif strcmp(currLevel,'DANGER')  && timeSinceLast > 1.5
        shouldPlay = true;   % repeat danger alarm every 1.5s
    elseif strcmp(currLevel,'WARNING') && timeSinceLast > 3.0
        shouldPlay = true;   % repeat warning every 3s
    end

    if ~shouldPlay, return; end
    lastSoundTime = tNow;
    lastLevel     = currLevel;

    Fs = 44100;   % high sample rate for better quality

    switch currLevel

        case 'DANGER'
            %% Fast triple beep — 1200 Hz
            t     = linspace(0, 0.15, round(Fs*0.15));
            tone  = 0.8 * sin(2*pi*1200*t);
            % Apply envelope to avoid clicks
            env   = hann(length(tone))';
            tone  = tone .* env;
            gap   = zeros(1, round(Fs*0.05));
            sig   = [tone, gap, tone, gap, tone];
            fprintf('   [ALARM] DANGER - triple beep firing\n');

        case 'WARNING'
            %% Double beep — 800 Hz
            t     = linspace(0, 0.18, round(Fs*0.18));
            tone  = 0.6 * sin(2*pi*800*t);
            env   = hann(length(tone))';
            tone  = tone .* env;
            gap   = zeros(1, round(Fs*0.08));
            sig   = [tone, gap, tone];
            fprintf('   [SOUND] WARNING - double beep firing\n');

        case 'SAFE'
            if strcmp(prevLevel,'DANGER') || strcmp(prevLevel,'WARNING')
                %% Descending all-clear tone
                t    = linspace(0, 0.3, round(Fs*0.3));
                freq = linspace(700, 350, length(t));
                sig  = 0.4 * sin(2*pi*freq.*t);
                env  = hann(length(sig))';
                sig  = sig .* env;
                fprintf('   [SOUND] All clear tone\n');
            else
                return;
            end
    end

    %% METHOD 1: audioplayer (best quality, works on most systems)
    try
        ap = audioplayer(sig, Fs);
        play(ap);
        pause(0.05);   % small pause so sound starts
        return;
    catch
        fprintf('   audioplayer failed, trying sound()...\n');
    end

    %% METHOD 2: sound() function
    try
        sound(sig, Fs);
        return;
    catch
        fprintf('   sound() failed, trying beep...\n');
    end

    %% METHOD 3: beep (always works, no toolbox needed)
    try
        switch currLevel
            case 'DANGER'
                beep; pause(0.15);
                beep; pause(0.15);
                beep;
            case 'WARNING'
                beep; pause(0.2);
                beep;
            case 'SAFE'
                beep;
        end
        return;
    catch
        fprintf('   beep failed too.\n');
    end

    %% METHOD 4: Windows system sound via command (Windows only)
    if ispc
        switch currLevel
            case 'DANGER'
                cmd = '[System.Console]::Beep(1200,150); [System.Console]::Beep(1200,150); [System.Console]::Beep(1200,150)';
            case 'WARNING'
                cmd = '[System.Console]::Beep(800,200); [System.Console]::Beep(800,200)';
            case 'SAFE'
                cmd = '[System.Console]::Beep(600,300)';
        end
        system(sprintf('powershell -Command "%s"', cmd));
        fprintf('   [SOUND] Used Windows PowerShell beep\n');
    end
end

function level = get_level(score)
    if score >= 0.7,     level = 'DANGER';
    elseif score >= 0.4, level = 'WARNING';
    else,                level = 'SAFE';
    end
end

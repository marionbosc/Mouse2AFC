% A modified version from the code found in:
% http://www.mbfys.ru.nl/~robvdw/DGCN22/PRACTICUM_2011/LABS_2011/ALTERNATIVE_LABS/Lesson_2.html#18
function DrawDots()

BLACK_COLOR=0;
WHITE_COLOR=[255,255,255];

tic;
file_size = 512*1024; % 512 kb mem-mapped file
m = createMMFile('c:\Bpoduser\', 'mmap_matlab_randomdot.dat', file_size);

disp('Mapping file took: ' + string(toc));
tic;
% Setup PTB with some default values
%PsychDefaultSetup(2);

% Set the screen number to the external secondary monitor if there is one
% connected
screenNumber = max(Screen('Screens'));

% Skip sync tests for demo purposes only
Screen('Preference', 'SkipSyncTests', 1);

% Open the screen
[windowPtr, windowRect] = PsychImaging('OpenWindow', screenNumber, ...
    BLACK_COLOR, [], 32, 2, [], [],  kPsychNeed32BPCFloat);

disp('Setting up screen: ' + string(toc));
tic;

disp(windowRect)
%[width, height]=Screen(?WindowSize?, windowPointerOrScreenNumber [, realFBSize=0]);

%photoDiodeBox = [windowRect(3)-2, 0, windowRect(3), 20];
photoDiodeBox = [0 0 windowRect(3)/15 windowRect(4)/15]

ifi = Screen('GetFlipInterval', windowPtr);
frameRate = 1/ifi;

% Create all the directions that we have
directions = 0:45:360-45;

% 1 0 stop running  - load data - 2 keep running
currentCommand = 0;
alreadyLoaded = 0;
alreadyStopped = 0;

DONT_SYNC=1;

next_frame_time=0;
alreadyCleared=true;
%next_frame_time2 = GetSecs(); % Any initial value
disp('Post setup took: ' + string(toc));

while true
    currentCommand = typecast(m.Data(1:4), 'uint32');
    if currentCommand == 2 && alreadyLoaded % keep running
        % The code order is messy but since I'm no expert in MATLAB so
        % I'm trying my best here to get the best performance. We place
        % the most probable branch of the if-condition first, and the next
        % step is basically the last step of the code below outside of the
        % if conditions. What we've done below is that we've prepared every
        % thing in the background for flipping and we only need to flip now
        % in the right second.
        % tic
        %disp('Next frame remaining time: ' + string(next_frame_time2 - GetSecs()));
        vbl = Screen('Flip', windowPtr, next_frame_time);
        %next_frame_time2 = GetSecs() + ifi;
        % disp('Flipping took: ' + string(toc));
        alreadyCleared=false;
    elseif currentCommand == 1 || (currentCommand == 2 && ~alreadyLoaded)
        if ~alreadyLoaded
            if ~alreadyCleared
                disp('Clearing late load');
                % Clear first any previously drawn buffer by drawing a rect
                Screen(windowPtr, 'FillRect', 0);
                Screen('Flip', windowPtr, 0, 0, DONT_SYNC);
                alreadyCleared = true;
            end
            % tic;
            [~, dotsParams] = loadSerializedData(m, 5);
            alreadyLoaded = true;
            alreadyStopped = false;

            circleArea = (pi*((dotsParams.apertureSizeWidth/2).^2));
            % Calculate the size of a dot in pixel
            dotSizePx = angle2pix(dotsParams.screenWidthCm, ...
                windowRect(3),dotsParams.screenDistCm, ...
                dotsParams.dotSizeInDegs);
            %if dotSizePx > 20
            %   disp('Reducing point size to max supported 20 from: ' + ...
            %        string(dotSizePx));
            %   dotSizePx = 20;
            %end
            scaledDrawRatio = dotsParams.drawRatio / dotSizePx;
            nDots = round(circleArea * scaledDrawRatio);

            % First we'll calculate the left, right top and bottom of the
            % aperture (in degrees)
            l = dotsParams.centerX-dotsParams.apertureSizeWidth/2;
            r = dotsParams.centerX+dotsParams.apertureSizeWidth/2;
            b = dotsParams.centerY-dotsParams.apertureSizeHeight/2;
            t = dotsParams.centerY+dotsParams.apertureSizeHeight/2;

            % Calculate ratio of incoherent for each direction so can use it later
            % to know how many dots should be per each direction. The ratio is
            % equal to the total incoherence divide by the number of directions
            % minus one. A coherence of zero has equal opportunity in all
            % directions, and thus the main direction ratio is the normal coherence
            % plus the its share of random incoherence.
            directionIncoherence = (1 - dotsParams.coherence)/length(directions);
            directionsRatios(1:length(directions)) = directionIncoherence;
            directionsRatios(directions == dotsParams.mainDirection) = ...
             directionsRatios(directions == dotsParams.mainDirection) + ...
             dotsParams.coherence;
            % Round the number of dots that we have such that we get whole number
            % for each direction
            directionNDots = round(directionsRatios * nDots);
            % Re-evaluate the number of dots
            nDots = sum(directionNDots)
            % Convert lifetime to number of frames
            lifetime = ceil(dotsParams.dotLifetimeSecs * frameRate);
            % Each dot will have a integer value 'life' which is how many frames the
            % dot has been going.  The starting 'life' of each dot will be a random
            % number between 0 and dotsParams.lifetime-1 so that they don't all 'die' on the
            % same frame:
            dotsLife = ceil(rand(1, nDots)* lifetime);
            % The distance traveled by a dot (in degrees) is the speed (degrees/second)
            % divided by the frame rate (frames/second). The units cancel, leaving
            % degrees/frame which makes sense. Basic trigonometry (sines and cosines)
            % allows us to determine how much the changes in the x and y position.
            dx = dotsParams.dotSpeed*sin(directions*pi/180)/frameRate;
            dy = -dotsParams.dotSpeed*cos(directions*pi/180)/frameRate;
            % Create all the dots in random starting positions
            x = (rand(1,nDots)-.5)*...
                dotsParams.apertureSizeWidth + dotsParams.centerX;
            y = (rand(1,nDots)-.5)*...
                dotsParams.apertureSizeHeight + dotsParams.centerY;

            vbl = 0; % Draw the frame asap once we are told
            % disp('Setting up took: ' + string(toc));
            Screen(windowPtr, 'FillRect', WHITE_COLOR, photoDiodeBox);
        else
            pause(0.01);
            continue;
        end
    elseif currentCommand == 0 % stop running
        if ~alreadyStopped
            alreadyStopped = true;
            alreadyLoaded = false;
            % Clear first any previously drawn buffer by drawing a rect
            Screen(windowPtr, 'FillRect', 0);
            % The screen might have something pre-drawn on it with 'DrawFInished'
            % passed. Flip to clear it.
            Screen('Flip', windowPtr, 0, 0, DONT_SYNC);
            alreadyCleared = true;
        else
            pause(0.01);
        end
        continue
    else
        disp('Unexpected command received:' + string(currentCommand));
        continue;
    end

    % tic;
    goodDots = ...
        (x-dotsParams.centerX).^2/(dotsParams.apertureSizeWidth/2)^2 + ...
        (y-dotsParams.centerY).^2/(dotsParams.apertureSizeHeight/2)^2 < 1;

    %convert from degrees to screen pixels
    pixpos.x = angle2pix(dotsParams.screenWidthCm, windowRect(3), ...
                         dotsParams.screenDistCm, x) + ...
               windowRect(3)/2;
    pixpos.y = angle2pix(dotsParams.screenWidthCm, windowRect(3), ...
                         dotsParams.screenDistCm, y) + ...
               windowRect(4)/2;

    % disp('Pre-drawing took: ' + string(toc));
    % tic;
    Screen('DrawDots', windowPtr, ...
        [pixpos.x(goodDots);pixpos.y(goodDots)], dotSizePx, ...
        WHITE_COLOR, [0,0], 1);
    %Screen('DrawingFinished', window);
    %disp('Drawing took: ' + string(toc));
    % tic;

    firstIdx = 1;
    lastIdx = 0;
    for directionIdx = 1:length(directions)
        lastIdx = lastIdx + directionNDots(directionIdx);
        %update the dot position
        x(firstIdx:lastIdx) = x(firstIdx:lastIdx) + dx(directionIdx);
        y(firstIdx:lastIdx) = y(firstIdx:lastIdx) + dy(directionIdx);
        firstIdx = lastIdx + 1;
    end

    %move the dots that are outside the aperture back one aperture
    %width.
    x(x<l) = x(x<l) + dotsParams.apertureSizeWidth;
    x(x>r) = x(x>r) - dotsParams.apertureSizeWidth;
    y(y<b) = y(y<b) + dotsParams.apertureSizeHeight;
    y(y>t) = y(y>t) - dotsParams.apertureSizeHeight;

    %increment the 'life' of each dot
    dotsLife = dotsLife + 1;

    %find the 'dead' dots
    deadDots = mod(dotsLife,lifetime) == 0;

    %replace the positions of the dead dots to a random location
    x(deadDots) = (rand(1,sum(deadDots))-.5)* ...
                  dotsParams.apertureSizeWidth + dotsParams.centerX;
    y(deadDots) = (rand(1,sum(deadDots))-.5)*...
                  dotsParams.apertureSizeHeight + dotsParams.centerY;

    Screen(windowPtr, 'FillRect', WHITE_COLOR, photoDiodeBox);

    next_frame_time = vbl + ifi;
    %disp('Post draw took: ' + string(toc));
end
end

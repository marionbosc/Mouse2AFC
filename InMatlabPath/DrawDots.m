% A modified version from the code found in:
% http://www.mbfys.ru.nl/~robvdw/DGCN22/PRACTICUM_2011/LABS_2011/ALTERNATIVE_LABS/Lesson_2.html#18
function DrawDots(varargin)

tic;
file_size = 512*1024; % 512 kb mem-mapped file
m = createMMFile('c:\Bpoduser\', 'mmap_matlab_randomdot.dat', file_size);

disp('Mapping file took: ' + string(toc));

tic;
% Setup PTB with some default values
%PsychDefaultSetup(2);

if nargin == 0
   % Set the screen number to the external secondary monitor if there is one
   % connected
   screensNums = max(Screen('Screens'));
else
   screensNums = str2double(varargin);
end

% Skip sync tests for demo purposes only
Screen('Preference', 'SkipSyncTests', 1);

BLACK_COLOR=BlackIndex(screensNums(1));
WHITE_COLOR=WhiteIndex(screensNums(1));
GRAY_COLOR=round((WHITE_COLOR+BLACK_COLOR)/2);
INC_GRAY=WHITE_COLOR-GRAY_COLOR;

winsPtrs = [];
% Open the screens
for curScrenNum = screensNums
    curWinRect = [];%[0 0 600 600]; % []
    fprintf("Opening screen %d", curScrenNum);
    [curWinPtr, curWinRect] = PsychImaging('OpenWindow', curScrenNum, ...
        BLACK_COLOR, curWinRect, 32, 2, [], [],  kPsychNeed32BPCFloat);
    % Store a reference to the variables we need
    %winsRects = [winsRects curWinRect];
    winsPtrs = [winsPtrs curWinPtr];
    % Disable alpha blending just in case it was still enabled by a previous
    % run that crashed.
    Screen('BlendFunction', curWinPtr, GL_ONE, GL_ZERO);
end
% Again, for verbosity, the same windows rect is valid for all screens as all
% the screens should have the same resolution
winsRect = curWinRect;

disp('Setting up screen(s): ' + string(toc));
[minSmoothPointSize, maxSmoothPointSize, minAliasedPointSize,...
    maxAliasedPointSize] = Screen('DrawDots', winsPtrs(1));
fprintf('minSmoothPointSize: %d, maxSmoothPointSize: %d, ',...
        minSmoothPointSize, maxSmoothPointSize)
fprintf('minAliasedPointSize: %d, maxAliasedPointSize: %d\n',...
        minAliasedPointSize, maxAliasedPointSize)
tic;

%[width, height]=Screen(?WindowSize?, windowPointerOrScreenNumber [, realFBSize=0]);

% For the next parts, we assume that all the screens has the same dimension, so
% just use curWinRect and curWinPtr as they should hold the sane values.

% Query maximum useable priorityLevel on this system:
priorityLevel = MaxPriority(curScrenNum(1))

photoDiodeBox = [(curWinRect(3)-(curWinRect(3)/15)) 0 curWinRect(3) curWinRect(4)/15]

ifi = Screen('GetFlipInterval', curWinPtr);
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

stimType = 0;
lastStimType = 0;
alphaBlendUsedLast = false;
backGroundColor = BLACK_COLOR;

% Commands
% 0 = Stop running
% 1 = Load new Dots info
% 2 = Start running or keep running
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
        % Use the vbl from the first screen
        vbl = Screen('Flip', winsPtrs(1), next_frame_time);
        for curWinPtr = winsPtrs(2:end)
            Screen('Flip', curWinPtr, next_frame_time);
        end
        %next_frame_time2 = GetSecs() + ifi;
        % disp('Flipping took: ' + string(toc));
        alreadyCleared=false;
    elseif currentCommand == 1 || (currentCommand == 2 && ~alreadyLoaded)
        if ~alreadyLoaded
            [~, drawParams] = loadSerializedData(m, 5);
            stimType = drawParams.stimType;
            if ~alreadyCleared || stimType ~= lastStimType
                disp('Clearing late load or stimulus type changed');
                % Clear first any previously drawn buffer by drawing a rect
                if stimType == DrawStimType.RDK
                    backGroundColor = BLACK_COLOR;
                else
                    backGroundColor = GRAY_COLOR;
                end
                for curWinPtr = winsPtrs
                    Screen('FillRect', curWinPtr, backGroundColor);
                    Screen('FillRect', curWinPtr, BLACK_COLOR, photoDiodeBox);
                    Screen('Flip', curWinPtr, 0, 0, DONT_SYNC);
                end
                alreadyCleared = true;
            end
            % tic;
            alreadyLoaded = true;
            alreadyStopped = false;
            alphaBlendUsed = false;
            vbl = 0; % Draw the frame asap once we are told
            if stimType == DrawStimType.RDK
                circleArea = (pi*((drawParams.apertureSizeWidth/2).^2));
                % Calculate the size of a dot in pixel
                dotSizePx = angle2pix(drawParams.screenWidthCm, ...
                    winsRect(3),drawParams.screenDistCm, ...
                    drawParams.dotSizeInDegs);
                %if dotSizePx > 20
                %   disp('Reducing point size to max supported 20 from: ' + ...
                %        string(dotSizePx));
                %   dotSizePx = 20;
                %end
                dot_type = 1;
                if dotSizePx > maxSmoothPointSize
                    dot_type = 3;
                end
                scaledDrawRatio = drawParams.drawRatio / dotSizePx;
                nDots = round(circleArea * scaledDrawRatio);

                % First we'll calculate the left, right top and bottom of the
                % aperture (in degrees)
                l = drawParams.centerX-drawParams.apertureSizeWidth/2;
                r = drawParams.centerX+drawParams.apertureSizeWidth/2;
                b = drawParams.centerY-drawParams.apertureSizeHeight/2;
                t = drawParams.centerY+drawParams.apertureSizeHeight/2;

                % Calculate ratio of incoherent for each direction so can use it later
                % to know how many dots should be per each direction. The ratio is
                % equal to the total incoherence divide by the number of directions
                % minus one. A coherence of zero has equal opportunity in all
                % directions, and thus the main direction ratio is the normal coherence
                % plus the its share of random incoherence.
                directionIncoherence = (1 - drawParams.coherence)/length(directions);
                directionsRatios(1:length(directions)) = directionIncoherence;
                directionsRatios(directions == drawParams.mainDirection) = ...
                 directionsRatios(directions == drawParams.mainDirection) + ...
                 drawParams.coherence;
                % Round the number of dots that we have such that we get whole number
                % for each direction
                directionNDots = round(directionsRatios * nDots);
                % Re-evaluate the number of dots
                nDots = sum(directionNDots)
                % Convert lifetime to number of frames
                lifetime = ceil(drawParams.dotLifetimeSecs * frameRate);
                % Each dot will have a integer value 'life' which is how many frames the
                % dot has been going.  The starting 'life' of each dot will be a random
                % number between 0 and dotsParams.lifetime-1 so that they don't all 'die' on the
                % same frame:
                dotsLife = ceil(rand(1, nDots)* lifetime);
                % The distance traveled by a dot (in degrees) is the speed (degrees/second)
                % divided by the frame rate (frames/second). The units cancel, leaving
                % degrees/frame which makes sense. Basic trigonometry (sines and cosines)
                % allows us to determine how much the changes in the x and y position.
                dx = drawParams.dotSpeed*sin(directions*pi/180)/frameRate;
                dy = -drawParams.dotSpeed*cos(directions*pi/180)/frameRate;
                % Create all the dots in random starting positions
                x = (rand(1,nDots)-.5)*...
                    drawParams.apertureSizeWidth + drawParams.centerX;
                y = (rand(1,nDots)-.5)*...
                    drawParams.apertureSizeHeight + drawParams.centerY;
            elseif stimType == DrawStimType.StaticGratings
                 % Prepare the new texture for drawing
                 % Adapted from: https://peterscarfe.com/gabordemo.html
                 % and Psychtoolbox-3/Drift2 example
                 gratingOrientation = drawParams.gratingOrientation;
                 % Dimension of the region where will draw the grating in pixels
                 % TODO: Calculate in degrees
                 gratingDimPix = winsRect(3) * drawParams.gaborSizeFactor;
                 if mod(gratingDimPix,2) == 0 % Convert to odd number
                     gratingDimPix = gratingDimPix + 1;
                 end
                 % Frequency of gratings in cycles / pixel
                 freqCyclesPerPix = drawParams.numCycles / gratingDimPix;
                 % Also need frequency in radians:
                 freqCyclesPerPixRadians = freqCyclesPerPix*2*pi;
                 % First we compute pixels per cycle, rounded up to full pixels, as we
                 % need this to create a grating of proper size below:
                 pixelPerCycle = ceil(1/freqCyclesPerPix);
                 % From Psychtoolbox documentation
                 % Create one single static grating image:
                 %
                 % We only need a texture with a single row of pixels(i.e. 1 pixel in height) to
                 % define the whole grating! If the 'srcRect' in the 'Drawtexture' call
                 % below is "higher" than that (i.e. visibleSize >> 1), the GPU will
                 % automatically replicate pixel rows. This 1 pixel height saves memory
                 % and memory bandwith, ie. it is potentially faster on some GPUs.
                 %
                 % However it does need 2 * texsize + p columns, i.e. the visible size
                 % of the grating extended by the length of 1 period (repetition) of the
                 % sine-wave in pixels 'pixelPerCycle':
                 gratingLine = meshgrid(-gratingDimPix/2:gratingDimPix/2 + pixelPerCycle, 1);
                 % Compute actual cosine grating:
                 grating = GRAY_COLOR + INC_GRAY*cos(freqCyclesPerPixRadians*gratingLine);
                 % Store 1-D single row grating in texture:
                 % Assume all the screens are the same here, use the last one
                 gratingTex = Screen('MakeTexture', curWinPtr, grating);
                 % Create a single gaussian transparency mask and store it to a texture:
                 % The mask must have the same size as the visible size of the grating
                 % to fully cover it. Here we must define it in 2 dimensions and can't
                 % get easily away with one single row of pixels.
                 %
                 % We create a  two-layer texture: One unused luminance channel which we
                 % just fill with the same color as the background color of the screen
                 % 'gray'. The transparency (aka alpha) channel is filled with a
                 % gaussian (exp()) aperture mask:
                 if drawParams.gaussianFilterRatio > 0
                    if ~alphaBlendUsedLast
                        % Enable alpha blending for proper combination of
                        % the gaussian aperture with the drifting sine grating:
                        disp('Setting alpha blend...')
                        for curWinPtr = winsPtrs
                            Screen('BlendFunction', curWinPtr,...
                                GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                        end
                        alphaBlendUsedLast = true;
                    end
                    mask = ones(gratingDimPix, gratingDimPix, 2) * GRAY_COLOR;
                    [xMask,yMask] = meshgrid(-0.5*(gratingDimPix-1):0.5*(gratingDimPix-1),...
                                             -0.5*(gratingDimPix-1):0.5*(gratingDimPix-1));
                    % Try to get a gaussian linear factor by opposing exponential effect
                    drawParams.gaussianFilterRatio = drawParams.gaussianFilterRatio.^5;
                    mask(:,:,2) = round(WHITE_COLOR * (1 - exp(...
                           -((xMask*drawParams.gaussianFilterRatio).^2)...
                           -((yMask*drawParams.gaussianFilterRatio).^2))));
                    % Again for simplicity (and our use case) assume all the
                    % screens are identical and can use the same values
                    maskTex = Screen('MakeTexture', curWinPtr, mask);
                    alphaBlendUsed = true;
                 end
                 % Definition of the drawn rectangle on the screen:
                 % Compute it to  be the visible size of the grating, centered on the
                 % screen:
                 dstRect = [0 0 gratingDimPix gratingDimPix];
                 dstRect = CenterRect(dstRect, winsRect);
                 % Recompute p, this time without the ceil() operation from above.
                 % Otherwise we will get wrong drift speed due to rounding errors!
                 pixelPerCycle = 1/freqCyclesPerPix;
                 % Drifting speed
                 drawParams.driftCyclePerSecond = 1;
                 % Translate requested speed of the grating (in cycles per second) into
                 % a shift value in "pixels per frame", for given waitduration: This is
                 % the amount of pixels to shift our srcRect "aperture" in horizontal
                 % directionat each redraw:
                 shiftPerFrame = drawParams.cyclesPerSecondDrift * pixelPerCycle * ifi;
                 % Keeps track of what the next phase offset should be to
                 % simulate drigting
                 offsetIndex = round(drawParams.phase * pixelPerCycle * ifi);
            end
            % We don't use Priority() in order to not accidentally overload older
            % machines that can't handle a redraw every 40 ms. If your machine is
            % fast enough, uncomment this to get more accurate timing.
            %Priority(priorityLevel);
            % disp('Setting up took: ' + string(toc));
            if alphaBlendUsedLast && ~alphaBlendUsed
                disp('Disabling alpha blend...')
                for curWinPtr = winsPtrs
                    Screen('BlendFunction', curWinPtr, GL_ONE, GL_ZERO);
                end
                alphaBlendUsedLast = false;
            end
            lastStimType = stimType;
            for curWinPtr = winsPtrs
                Screen('FillRect', curWinPtr, WHITE_COLOR, photoDiodeBox);
            end
        else
            pause(0.005); % Wait for the run command
            continue;
        end
    elseif currentCommand == 0 % stop running
        if ~alreadyStopped
            alreadyStopped = true;
            alreadyLoaded = false;
            for curWinPtr = winsPtrs
                % Clear first any previously drawn buffer by drawing a rect
                Screen('FillRect', curWinPtr, backGroundColor);
                Screen('FillRect', curWinPtr, BLACK_COLOR, photoDiodeBox);
                % The screen might have something pre-drawn on it with
                % 'DrawFInished' passed. Flip to clear it.
                Screen('Flip', curWinPtr, 0, 0, DONT_SYNC);
            end
            % Re-evaluate refresh rate in case it got slower
            ifi = Screen('GetFlipInterval', curWinPtr);
            frameRate = 1/ifi;
            %Priority(0);
            alreadyCleared = true;
        else
            pause(0.01);
        end
        continue
    else
        disp('Unexpected command received:' + string(currentCommand));
        continue;
    end

    if stimType == DrawStimType.RDK
        % tic;
        goodDots = ...
            (x-drawParams.centerX).^2/(drawParams.apertureSizeWidth/2)^2 + ...
            (y-drawParams.centerY).^2/(drawParams.apertureSizeHeight/2)^2 < 1;

        %convert from degrees to screen pixels
        pixpos.x = angle2pix(drawParams.screenWidthCm, winsRect(3), ...
                             drawParams.screenDistCm, x) + winsRect(3)/2;
        pixpos.y = angle2pix(drawParams.screenWidthCm, winsRect(3), ...
                             drawParams.screenDistCm, y) + winsRect(4)/2;
        % disp('Pre-drawing took: ' + string(toc));
        % tic;
        xGoodDotsPix = pixpos.x(goodDots);
        yGoodDotsPix = pixpos.y(goodDots);
        for curWinPtr = winsPtrs
            Screen('DrawDots', curWinPtr, ...
                [xGoodDotsPix; yGoodDotsPix], dotSizePx, WHITE_COLOR, [0,0],...
                dot_type);
        end
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
        x(x<l) = x(x<l) + drawParams.apertureSizeWidth;
        x(x>r) = x(x>r) - drawParams.apertureSizeWidth;
        y(y<b) = y(y<b) + drawParams.apertureSizeHeight;
        y(y>t) = y(y>t) - drawParams.apertureSizeHeight;

        %increment the 'life' of each dot
        dotsLife = dotsLife + 1;

        %find the 'dead' dots
        deadDots = mod(dotsLife,lifetime) == 0;

        %replace the positions of the dead dots to a random location
        x(deadDots) = (rand(1,sum(deadDots))-.5)* ...
                      drawParams.apertureSizeWidth + drawParams.centerX;
        y(deadDots) = (rand(1,sum(deadDots))-.5)*...
                      drawParams.apertureSizeHeight + drawParams.centerY;
    else % Static and Moving Grating
        % Shift the grating by "shiftperframe" pixels per frame:
        % the mod'ulo operation makes sure that our "aperture" will snap
        % back to the beginning of the grating, once the border is reached.
        % Fractional values of 'xoffset' are fine here. The GPU will
        % perform proper interpolation of color values in the grating
        % texture image to draw a grating that corresponds as closely as
        % technical possible to that fractional 'xoffset'. GPU's use
        % bilinear interpolation whose accuracy depends on the GPU at hand.
        % Consumer ATI hardware usually resolves 1/64 of a pixel, whereas
        % consumer NVidia hardware usually resolves 1/256 of a pixel. You
        % can run the script "DriftTexturePrecisionTest" to test your
        % hardware...
        xOffset = mod(offsetIndex*shiftPerFrame, pixelPerCycle);
        offsetIndex = offsetIndex + 1;
        % Define shifted srcRect that cuts out the properly shifted
        % rectangular area from the texture: We cut out the range 0 to
        % visiblesize in the vertical direction although the texture is
        % only 1 pixel in height! This works because the hardware will
        % automatically replicate pixels in one dimension if we exceed the
        % real borders of the stored texture. This allows us to save
        % storage space here, as our 2-D grating is essentially only
        % defined in 1-D:
        srcRect = [xOffset 0 (xOffset+gratingDimPix) gratingDimPix];
        for curWinPtr = winsPtrs
            % Draw grating texture, rotated by "orientation":
            Screen('DrawTexture', curWinPtr, gratingTex, srcRect, dstRect,...
                gratingOrientation);
            if drawParams.gaussianFilterRatio > 0
                % Draw gaussian mask over grating:
                Screen('DrawTexture', curWinPtr, maskTex,...
                    [0 0 gratingDimPix gratingDimPix], dstRect,...
                    gratingOrientation);
            end
        end
    end
    for curWinPtr = winsPtrs
        Screen('FillRect', curWinPtr, WHITE_COLOR, photoDiodeBox);
    end
    next_frame_time = vbl + (0.5*ifi);
    %disp('Post draw took: ' + string(toc));
end
Priority(0);
end

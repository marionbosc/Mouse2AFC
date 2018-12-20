function FlipFrameCB (~, ~)
global BpodSystem
if ~BpodSystem.Data.Custom.rDots.keepRunning
    % Just clear the screen just in case
    disp('Finished run flipping');
    Screen(BpodSystem.Data.Custom.visual.window,'FillRect', 0);
    Screen('Flip', BpodSystem.Data.Custom.visual.window);
    return
end

if BpodSystem.Data.Custom.visual.nextFrameTime > GetSecs();
   vbl = Screen('Flip',BpodSystem.Data.Custom.visual.window,...
                BpodSystem.Data.Custom.visual.nextFrameTime, 2);
else
   vbl = Screen('Flip',BpodSystem.Data.Custom.visual.window, 0);
end
PreDrawDots();

BpodSystem.Data.Custom.visual.nextFrameTime = ...
                                    vbl + BpodSystem.Data.Custom.rDots.ifi;
now = GetSecs();
nextEventTime = BpodSystem.Data.Custom.visual.nextFrameTime - now
if nextEventTime < 0.01 % Give a bit of slack for the timer to be late yet
                        % don't let it execute now
   nextEventTime = 0.01;
end
t = timer();
t.StartDelay = nextEventTime;
t.TimerFcn = @FlipFrameCB;
start(t);
end

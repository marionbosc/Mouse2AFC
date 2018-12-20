function SoftCodeHandler(softCode)
%soft code 11-20 reserved for PulsePal sound delivery

global BpodSystem
global TaskParameters

if softCode > 10 && softCode < 21 %for auditory clicks
    if ~BpodSystem.EmulatorMode
        if softCode == 11 %noise on chan 1
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
            SendCustomPulseTrain(1,cumsum(randi(9,1,601))/10000,(rand(1,601)-.5)*20); % White(?) noise on channel 1+2
            SendCustomPulseTrain(2,cumsum(randi(9,1,601))/10000,(rand(1,601)-.5)*20);
            TriggerPulsePal(1,2);
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
        elseif softCode == 12 %beep on chan 2
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamFeedback);
            SendCustomPulseTrain(2,0:.001:.3,(ones(1,301)*3));  % Beep on channel 1+2
            SendCustomPulseTrain(1,0:.001:.1,(ones(1,101)));
            TriggerPulsePal(1,2);
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
        end
    end
elseif softCode == 3
    % Grating is already prepared before, no need to do nothing, just flip
    % the screen
    Screen('Flip', BpodSystem.Data.Custom.visual.window);
elseif softCode == 4
    % We want to show empty gray screen, so no need to do anything, just
    % flip the screen
    Screen('Flip', BpodSystem.Data.Custom.visual.window);
elseif softCode == 5
    disp('5 is fired');
    BpodSystem.Data.Custom.rDots.count = 1;
    BpodSystem.Data.Custom.rDots.keepRunning = true;
    BpodSystem.Data.Custom.visual.nextFrameTime = GetSecs();
    FlipFrameCB("", "");
elseif softCode == 6
    now = GetSecs;
    %diff = now - BpodSystem.Data.Custom.Grating.original;
    %expected = BpodSystem.Data.Custom.Grating.count * 10;
    disp('I should stop now. Diff is: ');% + string(diff) + ' - expected: ' + string(expected));
    BpodSystem.Data.Custom.rDots.keepRunning = false;
end
end

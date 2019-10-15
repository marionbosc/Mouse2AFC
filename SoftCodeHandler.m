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
    BpodSystem.Data.dotsMapped_file.Data(1:4) = typecast(uint32(2), 'uint8');
elseif softCode == 6
    BpodSystem.Data.dotsMapped_file.Data(1:4) = typecast(uint32(0), 'uint8');
elseif softCode == 30 && BpodSystem.Data.Custom.IsHomeCage
    disp('Reporting animal is using the system at this very moment.');
    BpodSystem.ProtocolSettings.HomeCage.ReportAnimalInsideFn();
end
end

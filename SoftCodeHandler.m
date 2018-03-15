function SoftCodeHandler(softCode)
%soft codes 1-10 reserved for odor delivery
%soft code 11-20 reserved for PulsePal sound delivery

global BpodSystem
global TaskParameters

% if softCode < 11 %for olfactory
%     if BpodSystem.Data.Custom.OlfactometerStartup %if there has been a non-auditory trial and thus olfactometer initialized
%         
%         firstbank = ['Bank' num2str(TaskParameters.GUI.OdorA_bank)];
%         secbank = ['Bank' num2str(TaskParameters.GUI.OdorB_bank)];
%         
%         if softCode < 9
%             if ~BpodSystem.EmulatorMode
%                 CommandValve = Valves2EthernetString(firstbank, softCode, secbank, softCode); % softCode := desired valve number
%                 TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValve);
%             end
%         elseif softCode == 9
%             nextTrial = numel(BpodSystem.Data.Custom.TrialNumber) + 2;
%             OdorA_flow = BpodSystem.Data.Custom.OdorFracA(nextTrial);
%             OdorB_flow = 100 - OdorA_flow;
%             if ~BpodSystem.EmulatorMode
%                 SetBankFlowRate(BpodSystem.Data.Custom.OlfIp, TaskParameters.GUI.OdorA_bank, OdorA_flow)
%                 SetBankFlowRate(BpodSystem.Data.Custom.OlfIp, TaskParameters.GUI.OdorB_bank, OdorB_flow)
%             end
%         end
%         
%     end %if olfactometer initialized
% end %if olfactory soft codes

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
            SendCustomPulseTrain(1,0:.001:.3,(ones(1,301)*3));
            TriggerPulsePal(1,2);
            ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);            
        end
    end
end

% if softCode > 20 && softCode < 31 %for auditory freq
%     if softCode == 21 
%         if BpodSystem.Data.Custom.PsychtoolboxStartup
%             PsychToolboxSoundServer('Play', 1);
%         end
%     end
%     if softCode == 22
%         if BpodSystem.Data.Custom.PsychtoolboxStartup
%             PsychToolboxSoundServer('Stop', 1);
%         end
%     end    
% end

% switch odorID
%     case 0
%         CommandValveMinOil = Valves2EthernetString(firstbank, 2, secbank, 2);
%         TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValveMinOil);
%     case 1
%         CommandValveScent = Valves2EthernetString(firstbank, 1, secbank, 1); % From RechiaOlfactometer plugin. Simultaneously sets banks 1 and 2 to valve 1
%         TCPWrite(BpodSystem.Data.Custom.OlfIp, 3336, CommandValveScent);
end


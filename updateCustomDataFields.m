function updateCustomDataFields(iTrial)
global BpodSystem
global TaskParameters

%% Standard values
BpodSystem.Data.Custom.ChoiceLeft(iTrial) = NaN;
BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = NaN;
BpodSystem.Data.Custom.Feedback(iTrial) = true;
BpodSystem.Data.Custom.FeedbackTime(iTrial) = NaN;
BpodSystem.Data.Custom.FixBroke(iTrial) = false;
BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = false;
BpodSystem.Data.Custom.MissedChoice(iTrial) = false;
BpodSystem.Data.Custom.FixDur(iTrial) = NaN;
BpodSystem.Data.Custom.MT(iTrial) = NaN;
BpodSystem.Data.Custom.ST(iTrial) = NaN;
BpodSystem.Data.Custom.Rewarded(iTrial) = false;
BpodSystem.Data.Custom.RewardAfterMinSampling(iTrial) = false;
BpodSystem.Data.Custom.TrialNumber(iTrial) = iTrial;

%% Checking states and rewriting standard
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
if any(strcmp('WaitForStimulus',statesThisTrial))
    BpodSystem.Data.Custom.FixDur(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.WaitForStimulus);
end
if any(strcmp('stimulus_delivery',statesThisTrial))
    if TaskParameters.GUI.RewardAfterMinSampling
        BpodSystem.Data.Custom.ST(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.stimulus_delivery); 
    else
        if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.AuditoryStimulusTime > TaskParameters.GUI.MinSampleAud
            BpodSystem.Data.Custom.ST(iTrial) = BpodSystem.Data.RawEvents.Trial{end}.States.CenterPortRewardDelivery(1,2) - BpodSystem.Data.RawEvents.Trial{end}.States.stimulus_delivery(1,1);
        else
            BpodSystem.Data.Custom.ST(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.stimulus_delivery);
        end
    end
end

if any(strcmp('WaitForChoice',statesThisTrial)) && ~any(strcmp('timeOut_missed_choice',statesThisTrial))
    BpodSystem.Data.Custom.MT(end) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.WaitForChoice);
end

if any(strcmp('WaitForRewardStart',statesThisTrial))  % CorrectChoice
    BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = 1; 
    if any(strcmp('WaitForReward',statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = BpodSystem.Data.RawEvents.Trial{end}.States.WaitForReward(end,end) - BpodSystem.Data.RawEvents.Trial{end}.States.WaitForRewardStart(1,1);
        if BpodSystem.Data.Custom.LeftRewarded(iTrial) == 1 % Correct choice = left
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1; % Left choosen
        else
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0;
        end
    end
elseif any(strcmp('WaitForPunishStart',statesThisTrial))  % WrongChoice
    BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = 0;
    if any(strcmp('WaitForPunish',statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = BpodSystem.Data.RawEvents.Trial{end}.States.WaitForPunish(end,end) - BpodSystem.Data.RawEvents.Trial{end}.States.WaitForPunishStart(1,1);
        if BpodSystem.Data.Custom.LeftRewarded(iTrial) == 1 % Correct choice = left
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0; % Left not choosen
        else
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1;
        end
    end
elseif any(strcmp('broke_fixation',statesThisTrial))
    BpodSystem.Data.Custom.FixBroke(iTrial) = true;
elseif any(strcmp('early_withdrawal',statesThisTrial))
    BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = true;
elseif any(strcmp('timeOut_missed_choice',statesThisTrial))
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
    BpodSystem.Data.Custom.MissedChoice(iTrial) = true;
end
if any(strcmp('timeOut_SkippedFeedback',statesThisTrial))
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
end
if any(strcmp('Reward',statesThisTrial))
    BpodSystem.Data.Custom.Rewarded(iTrial) = true;
end
if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.RewardAfterMinSampling
    BpodSystem.Data.Custom.RewardAfterMinSampling(iTrial) = true;
end
%% State-independent fields
BpodSystem.Data.Custom.StimDelay(iTrial) = TaskParameters.GUI.StimDelay;
BpodSystem.Data.Custom.FeedbackDelay(iTrial) = TaskParameters.GUI.FeedbackDelay;
BpodSystem.Data.Custom.MinSampleAud(iTrial) = TaskParameters.GUI.MinSampleAud;
BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,:) = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount(iTrial+1) =TaskParameters.GUI.CenterPortRewAmount;

%% Updating Delays
%stimulus delay
if TaskParameters.GUI.StimDelayAutoincrement
    if BpodSystem.Data.Custom.FixBroke(iTrial)
        TaskParameters.GUI.StimDelay = max(TaskParameters.GUI.StimDelayMin,...
            min(TaskParameters.GUI.StimDelayMax,BpodSystem.Data.Custom.StimDelay(iTrial)-TaskParameters.GUI.StimDelayDecr));
    else
        TaskParameters.GUI.StimDelay = min(TaskParameters.GUI.StimDelayMax,...
            max(TaskParameters.GUI.StimDelayMin,BpodSystem.Data.Custom.StimDelay(iTrial)+TaskParameters.GUI.StimDelayIncr));
    end
else
    if ~BpodSystem.Data.Custom.FixBroke(iTrial) 
        if TaskParameters.GUI.StimDelayMin < TaskParameters.GUI.StimDelayMax
            TaskParameters.GUI.StimDelay = TruncatedExponential(TaskParameters.GUI.StimDelayMin,...
                TaskParameters.GUI.StimDelayMax,TaskParameters.GUI.StimDelayTau);
        else
            TaskParameters.GUI.StimDelay = TaskParameters.GUI.StimDelayMin;
        end
    else
        TaskParameters.GUI.StimDelay = BpodSystem.Data.Custom.StimDelay(iTrial);
    end
end

%min sampling time auditory
if TaskParameters.GUI.MinSampleAudAutoincrement
    History = 50;
    Crit = 0.8;
    if sum(BpodSystem.Data.Custom.AuditoryTrial)<10
        ConsiderTrials = iTrial;
    else
        idxStart = find(cumsum(BpodSystem.Data.Custom.AuditoryTrial(iTrial:-1:1))>=History,1,'first');
        if isempty(idxStart)
            ConsiderTrials = 1:iTrial;
        else
            ConsiderTrials = iTrial-idxStart+1:iTrial;
        end
    end
    ConsiderTrials = ConsiderTrials((~isnan(BpodSystem.Data.Custom.ChoiceLeft(ConsiderTrials))...
        |BpodSystem.Data.Custom.EarlyWithdrawal(ConsiderTrials))&BpodSystem.Data.Custom.AuditoryTrial(ConsiderTrials)); %choice + early withdrawal + auditory trials
    if ~isempty(ConsiderTrials) && BpodSystem.Data.Custom.AuditoryTrial(iTrial)
        if mean(BpodSystem.Data.Custom.ST(ConsiderTrials)>TaskParameters.GUI.MinSampleAud) > Crit
            if ~BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
                TaskParameters.GUI.MinSampleAud = min(TaskParameters.GUI.MinSampleAudMax,...
                    max(TaskParameters.GUI.MinSampleAudMin,BpodSystem.Data.Custom.MinSampleAud(iTrial) + TaskParameters.GUI.MinSampleAudIncr));
            end
        elseif mean(BpodSystem.Data.Custom.ST(ConsiderTrials)>TaskParameters.GUI.MinSampleAud) < Crit/2
            if BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
                TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
                    min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial) - TaskParameters.GUI.MinSampleAudDecr));
            end
        else
            TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
                min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial)));
        end
    else
        TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
            min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial)));
    end
else
    TaskParameters.GUI.MinSampleAud = TaskParameters.GUI.MinSampleAudMin;
end

%feedback delay
switch TaskParameters.GUIMeta.FeedbackDelaySelection.String{TaskParameters.GUI.FeedbackDelaySelection}
    case 'AutoIncr'
        if ~BpodSystem.Data.Custom.Feedback(iTrial)
            TaskParameters.GUI.FeedbackDelay = max(TaskParameters.GUI.FeedbackDelayMin,...
                min(TaskParameters.GUI.FeedbackDelayMax,BpodSystem.Data.Custom.FeedbackDelay(iTrial)-TaskParameters.GUI.FeedbackDelayDecr));
        else
            TaskParameters.GUI.FeedbackDelay = min(TaskParameters.GUI.FeedbackDelayMax,...
                max(TaskParameters.GUI.FeedbackDelayMin,BpodSystem.Data.Custom.FeedbackDelay(iTrial)+TaskParameters.GUI.FeedbackDelayIncr));
        end
    case 'TruncExp'
        if iTrial > TaskParameters.GUI.StartEasyTrials
            TaskParameters.GUI.FeedbackDelay = TruncatedExponential(TaskParameters.GUI.FeedbackDelayMin,...
                TaskParameters.GUI.FeedbackDelayMax,TaskParameters.GUI.FeedbackDelayTau);
        else
            TaskParameters.GUI.FeedbackDelay = TruncatedExponential(TaskParameters.GUI.FeedbackDelayMin,...
                min(TaskParameters.GUI.FeedbackDelayMax,1),min(TaskParameters.GUI.FeedbackDelayTau,0.7));
        end
    case 'Fix'
        %     ATTEMPT TO GRAY OUT FIELDS
        %     if ~strcmp('edit',TaskParameters.GUIMeta.FeedbackDelay.Style)
        %         TaskParameters.GUIMeta.FeedbackDelay.Style = 'edit';
        %     end
        TaskParameters.GUI.FeedbackDelay = TaskParameters.GUI.FeedbackDelayMax;
end

%% Drawing future trials

% determine if catch trial
if iTrial > TaskParameters.GUI.StartEasyTrials
    BpodSystem.Data.Custom.CatchTrial(iTrial+1) = rand(1,1) < TaskParameters.GUI.PercentCatch;
else
    BpodSystem.Data.Custom.CatchTrial(iTrial+1) = false;
end

% Determine if Forced LED trial:
if TaskParameters.GUI.PortLEDtoCueReward
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = rand(1,1) < TaskParameters.GUI.PercentForcedLEDTrial;
else
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = false;
end

%create future trials
if iTrial > numel(BpodSystem.Data.Custom.DV) - 5
    
    lastidx = numel(BpodSystem.Data.Custom.DV);
    newAuditoryTrial = rand(1,5) < TaskParameters.GUI.PercentAuditory;
    BpodSystem.Data.Custom.AuditoryTrial = [BpodSystem.Data.Custom.AuditoryTrial,newAuditoryTrial];
    
    switch TaskParameters.GUIMeta.TrialSelection.String{TaskParameters.GUI.TrialSelection}
        case 'Flat' % Restore equals P(Omega) for all the Omega values of the GUI 
            TaskParameters.GUI.LeftBiasAud = 0.5;
            TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
        case 'BiasCorrecting' % Favors side with fewer rewards. Contrast drawn flat & independently.
            ndxAud = BpodSystem.Data.Custom.AuditoryTrial(1:iTrial);
            ndxRewd = BpodSystem.Data.Custom.Rewarded(1:iTrial) & ndxAud;
            ndxLeftRewd = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(1:iTrial) == 1;
            ndxLeftRewDone = BpodSystem.Data.Custom.LeftRewarded(1:iTrial)==1 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(1:iTrial));
            ndxRightRewd = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(1:iTrial) == 0;
            ndxRightRewDone = BpodSystem.Data.Custom.LeftRewarded(1:iTrial)==0 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(1:iTrial));
            if sum(ndxRewd)>10
                PerfL = sum(ndxAud & ndxLeftRewd)/sum(ndxAud & ndxLeftRewDone);
                PerfR = sum(ndxAud & ndxRightRewd)/sum(ndxAud & ndxRightRewDone);
                TaskParameters.GUI.LeftBiasAud = (PerfL-PerfR)/2 + 0.5;
            else
                TaskParameters.GUI.LeftBiasAud = 0.5;
            end 
            % auditory discrete omega values:
            % Adjust the GUI values of P(Omega) depending on the LeftBias
            TaskParameters.GUI.OmegaTable.OmegaProb(TaskParameters.GUI.OmegaTable.Omega<50) = TaskParameters.GUI.LeftBiasAud; % P(Right side trials)
            TaskParameters.GUI.OmegaTable.OmegaProb(TaskParameters.GUI.OmegaTable.Omega>50) = 1-TaskParameters.GUI.LeftBiasAud; % P(Left side trials)           
             
        case 'Manual' % Don't modify the LeftBias and leave the GUI values of P(Omega)
            TaskParameters.GUI.LeftBiasAud = 0.5;
    end
    
    % Adjustment of P(Omega) to make sure that sum(P(Omega))=1 
    if sum(TaskParameters.GUI.OmegaTable.OmegaProb) == 0
        TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
    end
    TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);
    
    % make future auditory trials
    % easy trial selection for Beta distribution
    if iTrial > TaskParameters.GUI.StartEasyTrials
        AuditoryAlpha = TaskParameters.GUI.AuditoryAlpha;
    else
        AuditoryAlpha = round(rand(1)); % AuditoryOmega = 0 or 1 to make it really easy
    end
    % L/R Bias trial selection for Beta distribution
    BetaRatio = (1 - min(0.9,max(0.1,TaskParameters.GUI.LeftBiasAud))) / min(0.9,max(0.1,TaskParameters.GUI.LeftBiasAud)); %use a = ratio*b to yield E[X] = LeftBiasAud using Beta(a,b) pdf
    %cut off between 0.1-0.9 to prevent extreme values (only one side) and div by zero
    BetaA =  (2*AuditoryAlpha*BetaRatio) / (1+BetaRatio); %make a,b symmetric around AuditoryAlpha to make B symmetric
    BetaB = (AuditoryAlpha-BetaA) + AuditoryAlpha;
    for a = 1:5
        if BpodSystem.Data.Custom.AuditoryTrial(lastidx+a)
            if rand(1,1) < TaskParameters.GUI.Percent50Fifty && iTrial > TaskParameters.GUI.StartEasyTrials % 50Fifty trials
                BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = 0.5;
            else
                if iTrial < TaskParameters.GUI.StartEasyTrials % easy trial 
                        EasyProb = zeros(numel(TaskParameters.GUI.OmegaTable.OmegaProb),1);
                        EasyProb(1) = 1; EasyProb(end)=1;
                        TaskParameters.GUI.OmegaTable.OmegaProb = EasyProb .* TaskParameters.GUI.OmegaTable.OmegaProb;
                        TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);    
                        BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = randsample(TaskParameters.GUI.OmegaTable.Omega,1,1,TaskParameters.GUI.OmegaTable.OmegaProb)/100;
                else
                    if TaskParameters.GUI.AuditoryTrialSelection == 1 % Beta distribution trial selection
                        BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = betarnd(max(0,BetaA),max(0,BetaB),1,1); %prevent negative parameters
                    else % Discrete value trial selection
                        BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = randsample(TaskParameters.GUI.OmegaTable.Omega,1,1,TaskParameters.GUI.OmegaTable.OmegaProb)/100;
                    end 
                end
            end
            BpodSystem.Data.Custom.LeftClickRate(lastidx+a) = round(BpodSystem.Data.Custom.AuditoryOmega(lastidx+a).*TaskParameters.GUI.SumRates);
            BpodSystem.Data.Custom.RightClickRate(lastidx+a) = round((1-BpodSystem.Data.Custom.AuditoryOmega(lastidx+a)).*TaskParameters.GUI.SumRates);
            BpodSystem.Data.Custom.LeftClickTrain{lastidx+a} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.LeftClickRate(lastidx+a), TaskParameters.GUI.AuditoryStimulusTime);
            BpodSystem.Data.Custom.RightClickTrain{lastidx+a} = GeneratePoissonClickTrain(BpodSystem.Data.Custom.RightClickRate(lastidx+a), TaskParameters.GUI.AuditoryStimulusTime);
            %correct left/right click train
            if ~isempty(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{lastidx+a})
                BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}(1),BpodSystem.Data.Custom.RightClickTrain{lastidx+a}(1));
                BpodSystem.Data.Custom.RightClickTrain{lastidx+a}(1) = min(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}(1),BpodSystem.Data.Custom.RightClickTrain{lastidx+a}(1));
            elseif  isempty(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) && ~isempty(BpodSystem.Data.Custom.RightClickTrain{lastidx+a})
                BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}(1) = BpodSystem.Data.Custom.RightClickTrain{lastidx+a}(1);
            elseif ~isempty(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) &&  isempty(BpodSystem.Data.Custom.RightClickTrain{lastidx+a})
                BpodSystem.Data.Custom.RightClickTrain{lastidx+a}(1) = BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}(1);
            else
                BpodSystem.Data.Custom.LeftClickTrain{lastidx+a} = round(1/BpodSystem.Data.Custom.LeftClickRate*10000)/10000;
                BpodSystem.Data.Custom.RightClickTrain{lastidx+a} = round(1/BpodSystem.Data.Custom.RightClickRate*10000)/10000;
            end
            if length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) > length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a})
                BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = 1;
            elseif length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) < length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a})
                BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = 0;
            else
                BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = rand<0.5;
            end
        else
            BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftClickRate(lastidx+a) = NaN;
            BpodSystem.Data.Custom.RightClickRate(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftClickTrain{lastidx+a} = [];
            BpodSystem.Data.Custom.RightClickTrain{lastidx+a} = [];
        end%if auditory
    end%for a=1:5
            
    % cross-modality difficulty for plotting
    for a = 1 : 5
        if BpodSystem.Data.Custom.AuditoryTrial(lastidx+a)
            BpodSystem.Data.Custom.DV(lastidx+a) = (length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) - length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a}))./(length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) + length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a}));
        end
    end
    
end%if trial > - 5

% send auditory stimuli to PulsePal for next trial
if BpodSystem.Data.Custom.AuditoryTrial(iTrial+1)
    if  ~BpodSystem.EmulatorMode
        SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{iTrial+1}))*5);
        SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}))*5);
    end
end


%%update hidden TaskParameter fields
TaskParameters.Figures.OutcomePlot.Position = BpodSystem.ProtocolFigures.SideOutcomePlotFig.Position;
TaskParameters.Figures.ParameterGUI.Position = BpodSystem.ProtocolFigures.ParameterGUI.Position;

%send bpod status to server
try
    script = 'receivebpodstatus.php';
    %create a common "outcome" vector
    outcome = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial); %1=correct, 0=wrong
    outcome(BpodSystem.Data.Custom.EarlyWithdrawal(1:iTrial))=2; %early withdrawal=2
    outcome(BpodSystem.Data.Custom.FixBroke(1:iTrial))=3;%jackpot=3
    SendTrialStatusToServer(script,BpodSystem.Data.Custom.Rig,outcome,BpodSystem.Data.Custom.Subject,BpodSystem.CurrentProtocolName);
catch
end

end

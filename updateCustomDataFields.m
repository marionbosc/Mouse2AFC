function updateCustomDataFields(iTrial)
% iTrial = The sequential number of the trial that just ran
global BpodSystem
global TaskParameters

%% Standard values
% Stores which lateral port the animal poked into (if any)
BpodSystem.Data.Custom.ChoiceLeft(iTrial) = NaN;
% Stores whether the animal poked into the correct port (if any)
BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = NaN;
% Signals whether confidence was used in this trial. Set to false if
% lateral ports choice timed-out (i.e, MissedChoice(i) is true), it also
% should be set to false (but not due to a bug) if the animal poked the
% a lateral port but didn't complete the feedback period (even with using
% grace).
BpodSystem.Data.Custom.Feedback(iTrial) = true;
% How long the animal spent waiting for the reward (whether in correct or
% in incorrect ports)
BpodSystem.Data.Custom.FeedbackTime(iTrial) = NaN;
% Signals whether the animal broke fixation during stimulus delay state
BpodSystem.Data.Custom.FixBroke(iTrial) = false;
% Signals whether the animal broke fixation during sampling but before
% min-sampling ends
BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = false;
% Signals whether the animal correctly finished min-sampling but failed
% to poke any of the lateral ports within ChoiceDeadLine period
BpodSystem.Data.Custom.MissedChoice(iTrial) = false;
% How long the animal remained fixated in center poke
BpodSystem.Data.Custom.FixDur(iTrial) = NaN;
% How long between sample end and making a choice (timeout-choice trials
% are excluded)
BpodSystem.Data.Custom.MT(iTrial) = NaN;
% How long the animal sampled. If RewardAfterMinSampling is enabled and
% animal completed min sampling, then it's equal to MinSampleAud time,
% otherwise it's how long the animal remained fixated in center-port until
% it either poked-out or the max allowed auditory sampling time was
% reached.
BpodSystem.Data.Custom.ST(iTrial) = NaN;
% Signals whether a reward was given to the animal (it also includes if the
% animal poked into the correct reward port but poked out afterwards and
% didn't receive a reward, due to 'RewardGrace' being counted as reward).
BpodSystem.Data.Custom.Rewarded(iTrial) = false;
% Signals whether a center-port reward was given after min-sampling ends.
BpodSystem.Data.Custom.RewardAfterMinSampling(iTrial) = false;
BpodSystem.Data.Custom.TrialNumber(iTrial) = iTrial;

%% Checking states and rewriting standard
% Extract the states that were used in the last trial
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
if any(strcmp('WaitForStimulus',statesThisTrial))
    BpodSystem.Data.Custom.FixDur(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.WaitForStimulus);
end
if any(strcmp('stimulus_delivery',statesThisTrial))
    if TaskParameters.GUI.RewardAfterMinSampling
        BpodSystem.Data.Custom.ST(iTrial) = diff(BpodSystem.Data.RawEvents.Trial{end}.States.stimulus_delivery);
    else
        % 'CenterPortRewardDelivery' state would exist even if no
        % 'RewardAfterMinSampling' is active, in such case it means that
        % min sampling is done and we are in the optional sampling stage.
        if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.AuditoryStimulusTime > TaskParameters.GUI.MinSampleAud
            BpodSystem.Data.Custom.ST(iTrial) = BpodSystem.Data.RawEvents.Trial{end}.States.CenterPortRewardDelivery(1,2) - BpodSystem.Data.RawEvents.Trial{end}.States.stimulus_delivery(1,1);
        else
            % This covers early_withdrawal.
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
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1; % Left chosen
        else
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0;
        end
    else
        orig_warn = warning;
        warning('on'); % Temporarily force displaying of warnings
        warning('''WaitForReward'' state should always appear if ''WaitForRewardStart'' was initiated');
        warning(orig_warn); % Restore the original warning values
    end
elseif any(strcmp('WaitForPunishStart',statesThisTrial))  % WrongChoice
    BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = 0;
    if any(strcmp('WaitForPunish',statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = BpodSystem.Data.RawEvents.Trial{end}.States.WaitForPunish(end,end) - BpodSystem.Data.RawEvents.Trial{end}.States.WaitForPunishStart(1,1);
        if BpodSystem.Data.Custom.LeftRewarded(iTrial) == 1 % Correct choice = left
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0; % Left not chosen
        else
            BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1;
        end
    end
elseif any(strcmp('broke_fixation',statesThisTrial))
    BpodSystem.Data.Custom.FixBroke(iTrial) = true;
elseif any(strcmp('early_withdrawal',statesThisTrial))
    BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = true;
elseif any(strcmp('missed_choice',statesThisTrial)) % should be timeOut_missed_choice?
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
    BpodSystem.Data.Custom.MissedChoice(iTrial) = true;
end
if any(strcmp('skipped_feedback',statesThisTrial)) % No such state, was timeOut_SkippedFeedback meant?
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
end
if any(strncmp('Reward',statesThisTrial,6)) % Will that include 'RewardGrace'? if yes, then should it?
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
        TaskParameters.GUI.StimDelay = random('unif',TaskParameters.GUI.StimDelayMin,TaskParameters.GUI.StimDelayMax);
    else
        TaskParameters.GUI.StimDelay = BpodSystem.Data.Custom.StimDelay(iTrial);
    end
end

%min sampling time auditory
if TaskParameters.GUI.MinSampleAudAutoincrement
    History = 50;
    Crit = 0.8;
    % If the sum of the Auditory trials are less than 10.
    % Since we have only AuditoryTrials can we just check for the value of iTrial?
    if sum(BpodSystem.Data.Custom.AuditoryTrial)<10
        ConsiderTrials = iTrial;
    else
        % Find the first auditory trial after 50.
        % Since all the trials are auditory, if iTrial is >= 50 then idxStart will always be 50
        idxStart = find(cumsum(BpodSystem.Data.Custom.AuditoryTrial(iTrial:-1:1))>=History,1,'first');
        if isempty(idxStart)
            ConsiderTrials = 1:iTrial; % Consider all the trials that we have so far
        else
            ConsiderTrials = iTrial-idxStart+1:iTrial; % Consider the last 50 trials
        end
    end
    % Keep only trials that are relevant, include only trials that are
    % auditory and trials that either a lateral port decision was made (i,e
    % min. sampling was completed successfully) or trials that the animal
    % made an early withdrawal during min. sampling (but after sampling
    % delay).
    % Do we exclude timeOut_missed_choice trials? if yes, then why?
    ConsiderTrials = ConsiderTrials((~isnan(BpodSystem.Data.Custom.ChoiceLeft(ConsiderTrials))...
        |BpodSystem.Data.Custom.EarlyWithdrawal(ConsiderTrials))&BpodSystem.Data.Custom.AuditoryTrial(ConsiderTrials)); %choice + early withdrawal + auditory trials
    % If the last trial was auditory and we don't have empty
    % consider-trials array after filtering.
    if ~isempty(ConsiderTrials) && BpodSystem.Data.Custom.AuditoryTrial(iTrial)
        % Divide the considered trials to 2 sets, those whose sampling time
        % are more than the current MinSampleAud and those that aren't, if
        % the ratio of those > MinSampleAud are bigger than 'Crit' and the
        % last trial wasn't an early withdrawal, then increment the
        % MinSampleAud.
        % If RewardAfterMinSampling is enabled, and since ST max possible
        % value when RewardAfterMinSampling is MinSampleAud, wouldn't
        % increasing the MinSampleAud be very difficult as ratio of
        % consider-trials will always be less than MinSampleAud?
        if mean(BpodSystem.Data.Custom.ST(ConsiderTrials)>TaskParameters.GUI.MinSampleAud) > Crit
            if ~BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
                TaskParameters.GUI.MinSampleAud = min(TaskParameters.GUI.MinSampleAudMax,...
                    max(TaskParameters.GUI.MinSampleAudMin,BpodSystem.Data.Custom.MinSampleAud(iTrial) + TaskParameters.GUI.MinSampleAudIncr));
            end
        % If the ratio of the trials that are less than current min
        % sampling are less than 'Crit'/2 and the last trial wasn't an early
        % withdrawal during min sampling then decrement MinSampleAud.
        elseif mean(BpodSystem.Data.Custom.ST(ConsiderTrials)>TaskParameters.GUI.MinSampleAud) < Crit/2
            if BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
                TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
                    min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial) - TaskParameters.GUI.MinSampleAudDecr));
            end
        % Otherwise keep the value as it is unless the user has updated the
        % GUI values.
        else
            TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
                min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial)));
        end
    % Keep the value as it is unless the user updated the GUI values.
    else
        TaskParameters.GUI.MinSampleAud = max(TaskParameters.GUI.MinSampleAudMin,...
            min(TaskParameters.GUI.MinSampleAudMax,BpodSystem.Data.Custom.MinSampleAud(iTrial)));
    end
else % Use non-incremental fixed value
    TaskParameters.GUI.MinSampleAud = TaskParameters.GUI.MinSampleAudMin;
end

%feedback delay
switch TaskParameters.GUI.FeedbackDelaySelection
    case FeedbackDelaySelection.AutoIncr
        % if no feedback was not completed then use the last value unless
        % then decrement the feedback.
        % Do we consider the case where 'broke_fixation' or
        % 'early_withdrawal' terminated early the trial?
        if ~BpodSystem.Data.Custom.Feedback(iTrial)
            TaskParameters.GUI.FeedbackDelay = max(TaskParameters.GUI.FeedbackDelayMin,...
                min(TaskParameters.GUI.FeedbackDelayMax,BpodSystem.Data.Custom.FeedbackDelay(iTrial)-TaskParameters.GUI.FeedbackDelayDecr));
        else
            % Increase the feedback if the feedback was successfully
            % completed in the last trial, or use the the GUI value that
            % the user updated if needed.
            % Do we also here consider the case where 'broke_fixation' or
            % 'early_withdrawal' terminated early the trial?
            TaskParameters.GUI.FeedbackDelay = min(TaskParameters.GUI.FeedbackDelayMax,...
                max(TaskParameters.GUI.FeedbackDelayMin,BpodSystem.Data.Custom.FeedbackDelay(iTrial)+TaskParameters.GUI.FeedbackDelayIncr));
        end
    case FeedbackDelaySelection.TruncExp
        TaskParameters.GUI.FeedbackDelay = TruncatedExponential(TaskParameters.GUI.FeedbackDelayMin,...
            TaskParameters.GUI.FeedbackDelayMax,TaskParameters.GUI.FeedbackDelayTau);
    case FeedbackDelaySelection.Fix
        %     ATTEMPT TO GRAY OUT FIELDS
        %     if ~strcmp('edit',TaskParameters.GUIMeta.FeedbackDelay.Style)
        %         TaskParameters.GUIMeta.FeedbackDelay.Style = 'edit';
        %     end
        TaskParameters.GUI.FeedbackDelay = TaskParameters.GUI.FeedbackDelayMax;
    otherwise
        assert(false, 'Unexpected FeedbackDelaySelection value');
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
% Check if its time to generate more future trials
if iTrial > numel(BpodSystem.Data.Custom.DV) - Const.PRE_GENERATE_TRIAL_CHECK

    lastidx = numel(BpodSystem.Data.Custom.DV);
    % Randomly choose which of the future trials will be auditory ones
    % Should it be here <= instead of < ?
    newAuditoryTrial = rand(1,Const.PRE_GENERATE_TRIAL_COUNT) < TaskParameters.GUI.PercentAuditory;
    % Append new bool array to the current AuditoryTrial array
    BpodSystem.Data.Custom.AuditoryTrial = [BpodSystem.Data.Custom.AuditoryTrial,newAuditoryTrial];

    switch TaskParameters.GUI.TrialSelection
        case TrialSelection.Flat % Restore equals P(Omega) for all the Omega values of the GUI
            TaskParameters.GUI.LeftBiasAud = 0.5;
            % Temporarily set all values to one. We will later divide them
            % into equal probability ratios whose  sum is 1.
            TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
        case TrialSelection.BiasCorrecting % Favors side with fewer rewards. Contrast drawn flat & independently.
            % Considers all trials, not just the last x trials
            ndxAud = BpodSystem.Data.Custom.AuditoryTrial(1:iTrial);
            ndxRewd = BpodSystem.Data.Custom.Rewarded(1:iTrial) & ndxAud;
            ndxLeftRewd = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(1:iTrial) == 1;
            ndxLeftRewDone = BpodSystem.Data.Custom.LeftRewarded(1:iTrial)==1 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(1:iTrial));
            ndxRightRewd = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(1:iTrial) == 0;
            ndxRightRewDone = BpodSystem.Data.Custom.LeftRewarded(1:iTrial)==0 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(1:iTrial));
            % Do bias correction only if we have enough trials
            if sum(ndxRewd) > Const.BIAS_CORRECT_MIN_RWD_TRIALS
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

        case TrialSelection.Manual % Don't modify the LeftBias and leave the GUI values of P(Omega)
            TaskParameters.GUI.LeftBiasAud = 0.5;
        otherwise
            assert(false, 'Unexpected TrialSelection value');
    end

    % Adjustment of P(Omega) to make sure that sum(P(Omega))=1
    if sum(TaskParameters.GUI.OmegaTable.OmegaProb) == 0 % Avoid having no probability and avoid dividing by zero
        TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
    end
    TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);

    % make future auditory trials
    % easy trial selection for Beta distribution
    if iTrial > TaskParameters.GUI.StartEasyTrials
        AuditoryAlpha = TaskParameters.GUI.AuditoryAlpha;
    else
        % Why divide by 4? to make it easier?
        AuditoryAlpha = TaskParameters.GUI.AuditoryAlpha/4;
    end
    % L/R Bias trial selection for Beta distribution
    BetaRatio = (1 - min(0.9,max(0.1,TaskParameters.GUI.LeftBiasAud))) / min(0.9,max(0.1,TaskParameters.GUI.LeftBiasAud)); %use a = ratio*b to yield E[X] = LeftBiasAud using Beta(a,b) pdf
    %cut off between 0.1-0.9 to prevent extreme values (only one side) and div by zero
    BetaA =  (2*AuditoryAlpha*BetaRatio) / (1+BetaRatio); %make a,b symmetric around AuditoryAlpha to make B symmetric
    BetaB = (AuditoryAlpha-BetaA) + AuditoryAlpha;
    for a = 1:Const.PRE_GENERATE_TRIAL_COUNT
        if BpodSystem.Data.Custom.AuditoryTrial(lastidx+a)
            % If it's a fifty-fifty trial, then place stimulus in the middle
            if rand(1,1) < TaskParameters.GUI.Percent50Fifty && iTrial > TaskParameters.GUI.StartEasyTrials % 50Fifty trials
                BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = 0.5;
            else
                if TaskParameters.GUI.AuditoryTrialSelection == AuditoryTrialSelection.BetaDistribution
                    BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = betarnd(max(0,BetaA),max(0,BetaB),1,1); %prevent negative parameters
                elseif TaskParameters.GUI.AuditoryTrialSelection == AuditoryTrialSelection.DiscretePairs
                    % If it's the an easy trial then choose the pair which
                    % are the table's biggest and the smallest values.
                    if iTrial < TaskParameters.GUI.StartEasyTrials % easy trial
                        EasyProb = zeros(numel(TaskParameters.GUI.OmegaTable.OmegaProb),1);
                        EasyProb(1) = 1; EasyProb(end)=1;
                        TaskParameters.GUI.OmegaTable.OmegaProb = EasyProb .* TaskParameters.GUI.OmegaTable.OmegaProb;
                        TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);
                    end
                    % Choose a value randomly given the each value probability
                    BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = randsample(TaskParameters.GUI.OmegaTable.Omega,1,1,TaskParameters.GUI.OmegaTable.OmegaProb)/100;

                else
                    assert(false, 'Unexpected AuditoryTrialSelection value');
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
                BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = rand<0.5; % It's equal distribution
            end
            % cross-modality difficulty for plotting
            %  0 <= (left - right) / (left + right) <= 1
            BpodSystem.Data.Custom.DV(lastidx+a) = (length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) - length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a}))./(length(BpodSystem.Data.Custom.LeftClickTrain{lastidx+a}) + length(BpodSystem.Data.Custom.RightClickTrain{lastidx+a}));
        else
            BpodSystem.Data.Custom.AuditoryOmega(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftClickRate(lastidx+a) = NaN;
            BpodSystem.Data.Custom.RightClickRate(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = NaN;
            BpodSystem.Data.Custom.LeftClickTrain{lastidx+a} = [];
            BpodSystem.Data.Custom.RightClickTrain{lastidx+a} = [];
        end%if auditory
    end%for a=1:5
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

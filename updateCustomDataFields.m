function updateCustomDataFields(iTrial)
% iTrial = The sequential number of the trial that just ran
global BpodSystem
global TaskParameters

tic;
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
% animal completed min sampling, then it's equal to MinSample time,
% otherwise it's how long the animal remained fixated in center-port until
% it either poked-out or the max allowed sampling time was reached.
BpodSystem.Data.Custom.ST(iTrial) = NaN;
% Signals whether a reward was given to the animal (it also includes if the
% animal poked into the correct reward port but poked out afterwards and
% didn't receive a reward, due to 'RewardGrace' being counted as reward).
BpodSystem.Data.Custom.Rewarded(iTrial) = false;
% Signals whether a center-port reward was given after min-sampling ends.
BpodSystem.Data.Custom.RewardAfterMinSampling(iTrial) = false;
% Tracks the amount of water the animal received up tp this point
% TODO: Check if RewardReceivedTotal is needed and calculate it using
% CalcRewObtained() function.
BpodSystem.Data.Custom.RewardReceivedTotal(iTrial+1) = 0; % We will updated later

BpodSystem.Data.Custom.TrialNumber(iTrial) = iTrial;

BpodSystem.Data.Timer.customInitialize(iTrial) = toc; tic;

%% Checking states and rewriting standard
% Extract the states that were used in the last trial
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
eventsStatesThisTrial = BpodSystem.Data.RawEvents.Trial{end}.States;
if any(strcmp('WaitForStimulus',statesThisTrial))
    BpodSystem.Data.Custom.FixDur(iTrial) = ...
     (eventsStatesThisTrial.WaitForStimulus(end,2) - eventsStatesThisTrial.WaitForStimulus(end,1)) + ...
     (eventsStatesThisTrial.TriggerWaitForStimulus(end,2) - eventsStatesThisTrial.TriggerWaitForStimulus(end,1));
end
if any(strcmp('stimulus_delivery',statesThisTrial))
    if TaskParameters.GUI.RewardAfterMinSampling
        BpodSystem.Data.Custom.ST(iTrial) = diff(eventsStatesThisTrial.stimulus_delivery);
    else
        % 'CenterPortRewardDelivery' state would exist even if no
        % 'RewardAfterMinSampling' is active, in such case it means that
        % min sampling is done and we are in the optional sampling stage.
        if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.StimulusTime > TaskParameters.GUI.MinSample
            BpodSystem.Data.Custom.ST(iTrial) = eventsStatesThisTrial.CenterPortRewardDelivery(1,2) - eventsStatesThisTrial.stimulus_delivery(1,1);
        else
            % This covers early_withdrawal.
            BpodSystem.Data.Custom.ST(iTrial) = diff(eventsStatesThisTrial.stimulus_delivery);
        end
    end
end

if any(strcmp('WaitForChoice',statesThisTrial)) && ~any(strcmp('timeOut_missed_choice',statesThisTrial))
    % We might have more than multiple WaitForChoice if
    % HabituateIgnoreIncorrect is enabeld
    BpodSystem.Data.Custom.MT(end) = diff(eventsStatesThisTrial.WaitForChoice(1:2));
end

% Extract trial outcome. Check first if it's a wrong choice or a
% HabituateIgnoreIncorrect but first choice was wrong choice
if any(strcmp('WaitForPunishStart',statesThisTrial)) || any(strcmp('RegisterWrongWaitCorrect',statesThisTrial))
    BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = 0;
    if BpodSystem.Data.Custom.LeftRewarded(iTrial) == 1 % Correct choice = left
        BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 0; % Left not chosen
    else
        BpodSystem.Data.Custom.ChoiceLeft(iTrial) = 1;
    end
    if any(strcmp('WaitForPunish',statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = eventsStatesThisTrial.WaitForPunish(end,end) - eventsStatesThisTrial.WaitForPunishStart(1,1);
    else % It was a  RegisterWrongWaitCorrect state
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = nan;
    end
elseif any(strcmp('WaitForRewardStart',statesThisTrial))  % CorrectChoice
    BpodSystem.Data.Custom.ChoiceCorrect(iTrial) = 1;
    if BpodSystem.Data.Custom.CatchTrial(iTrial)
        catch_stim_idx = GetCatchStimIdx(...
                             BpodSystem.Data.Custom.StimulusOmega(iTrial));
        % Lookup the stimulus probability and increase by its 1/frequency.
        stim_val = BpodSystem.Data.Custom.StimulusOmega(iTrial) * 100;
        if stim_val < 50
            stim_val = 100 - stim_val;
        end
        stim_prob = TaskParameters.GUI.OmegaTable.OmegaProb(...
                          TaskParameters.GUI.OmegaTable.Omega == stim_val);
        sum_all_prob = sum(TaskParameters.GUI.OmegaTable.OmegaProb);
        stim_prob = (1+sum_all_prob-stim_prob)/sum_all_prob;
        BpodSystem.Data.Custom.CatchCount(catch_stim_idx) = ...
             BpodSystem.Data.Custom.CatchCount(catch_stim_idx) + stim_prob;
        BpodSystem.Data.Custom.LastSuccessCatchTial = iTrial;
    end
    if any(strcmp('WaitForReward',statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.FeedbackTime(iTrial) = eventsStatesThisTrial.WaitForReward(end,end) - eventsStatesThisTrial.WaitForRewardStart(1,1);
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
elseif any(strcmp('broke_fixation',statesThisTrial))
    BpodSystem.Data.Custom.FixBroke(iTrial) = true;
elseif any(strcmp('early_withdrawal',statesThisTrial))
    BpodSystem.Data.Custom.EarlyWithdrawal(iTrial) = true;
elseif any(strcmp('missed_choice',statesThisTrial)) % should be timeOut_missed_choice?
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
    BpodSystem.Data.Custom.MissedChoice(iTrial) = true;
end
if any(strcmp('timeOut_SkippedFeedback',statesThisTrial))
    BpodSystem.Data.Custom.Feedback(iTrial) = false;
end
if any(strcmp('Reward',statesThisTrial))
    BpodSystem.Data.Custom.Rewarded(iTrial) = true;
    BpodSystem.Data.Custom.RewardReceivedTotal(iTrial) = ...
        BpodSystem.Data.Custom.RewardReceivedTotal(iTrial) + TaskParameters.GUI.RewardAmount;
end
if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.RewardAfterMinSampling
    BpodSystem.Data.Custom.RewardAfterMinSampling(iTrial) = true;
    BpodSystem.Data.Custom.RewardReceivedTotal(iTrial) = ...
        BpodSystem.Data.Custom.RewardReceivedTotal(iTrial) + TaskParameters.GUI.CenterPortRewAmount;
end
if any(strcmp('WaitCenterPortOut',statesThisTrial))
    BpodSystem.Data.Custom.ReactionTime(iTrial) = diff(eventsStatesThisTrial.WaitCenterPortOut);
else % Assign with -1 so we can differntiate it from nan trials where the
     % state potentially existed but we didn't calculate it
    BpodSystem.Data.Custom.ReactionTime(iTrial) = -1;
end
%% State-independent fields
BpodSystem.Data.Custom.StimDelay(iTrial) = TaskParameters.GUI.StimDelay;
BpodSystem.Data.Custom.FeedbackDelay(iTrial) = TaskParameters.GUI.FeedbackDelay;
BpodSystem.Data.Custom.MinSample(iTrial) = TaskParameters.GUI.MinSample;
BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,:) = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount(iTrial+1) = TaskParameters.GUI.CenterPortRewAmount;
BpodSystem.Data.Custom.PreStimCntrReward(iTrial+1) = TaskParameters.GUI.PreStimuDelayCntrReward;
BpodSystem.Data.Timer.customExtractData(iTrial) = toc; tic;

% IF we are running grating experiments, add the grating orientation that was used
if TaskParameters.GUI.ExperimentType == ExperimentType.GratingOrientation
    BpodSystem.Data.Custom.GratingOrientation(iTrial) = BpodSystem.Data.Custom.drawParams.gratingOrientation;
end

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
BpodSystem.Data.Timer.customStimDelay(iTrial) = toc; tic;

%min sampling time
if iTrial > TaskParameters.GUI.StartEasyTrials
    switch TaskParameters.GUI.MinSampleType
        case MinSampleType.FixMin
            TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
        case MinSampleType.AutoIncr
            % Check if animal completed pre-stimulus delay successfully
            if ~BpodSystem.Data.Custom.FixBroke(iTrial)
                if BpodSystem.Data.Custom.Rewarded(iTrial)
                    TaskParameters.GUI.MinSample = min(TaskParameters.GUI.MinSampleMax,...
                        max(TaskParameters.GUI.MinSampleMin,BpodSystem.Data.Custom.MinSample(iTrial) + TaskParameters.GUI.MinSampleIncr));
                elseif BpodSystem.Data.Custom.EarlyWithdrawal(iTrial)
                    TaskParameters.GUI.MinSample = max(TaskParameters.GUI.MinSampleMin,...
                        min(TaskParameters.GUI.MinSampleMax,BpodSystem.Data.Custom.MinSample(iTrial) - TaskParameters.GUI.MinSampleDecr));
                end
            else % Read new updated GUI values
                TaskParameters.GUI.MinSample = max(TaskParameters.GUI.MinSampleMin,...
                    min(TaskParameters.GUI.MinSampleMax,BpodSystem.Data.Custom.MinSample(iTrial)));
            end
        case MinSampleType.RandBetMinMax_DefIsMax
            use_rand = rand(1,1) < TaskParameters.GUI.MinSampleRandProb;
            if ~use_rand
                TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMax;
            else
                TaskParameters.GUI.MinSample = (TaskParameters.GUI.MinSampleMax-TaskParameters.GUI.MinSampleMin).*rand(1,1) + TaskParameters.GUI.MinSampleMin;
            end
        case MinSampleType.RandNumIntervalsMinMax_DefIsMax
            use_rand = rand(1,1) < TaskParameters.GUI.MinSampleRandProb;
            if ~use_rand
                TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMax;
            else
                TaskParameters.GUI.MinSampleNumInterval = round(TaskParameters.GUI.MinSampleNumInterval);
                if TaskParameters.GUI.MinSampleNumInterval == 0 || TaskParameters.GUI.MinSampleNumInterval == 1
                    TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
                else
                    step = (TaskParameters.GUI.MinSampleMax - TaskParameters.GUI.MinSampleMin)/(TaskParameters.GUI.MinSampleNumInterval-1);
                    intervals = [TaskParameters.GUI.MinSampleMin:step:TaskParameters.GUI.MinSampleMax];
                    intervals_idx = randi([1 TaskParameters.GUI.MinSampleNumInterval],1,1);
                    disp("Intervals:");
                    disp(intervals)
                    TaskParameters.GUI.MinSample = intervals(intervals_idx);
                end
            end
        otherwise
            assert(false, 'Unexpected MinSampleType value');
    end
end
BpodSystem.Data.Timer.customMinSampling(iTrial) = toc; tic;

%feedback delay
switch TaskParameters.GUI.FeedbackDelaySelection
    case FeedbackDelaySelection.None
        TaskParameters.GUI.FeedbackDelay = 0;
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
BpodSystem.Data.Timer.customFeedbackDelay(iTrial) = toc; tic;

%% Drawing future trials

% Calculate bias
% Consider bias only on the last 8 trials/
% indicesRwdLi = find(BpodSystem.Data.Custom.Rewarded,8,'last');
%if length(indicesRwdLi) ~= 0
%	indicesRwd = indicesRwdLi(1);
%else
%	indicesRwd = 1;
%end
LAST_TRIALS=20;
indicesRwd = iff(iTrial > LAST_TRIALS, iTrial - LAST_TRIALS, 1);
%ndxRewd = BpodSystem.Data.Custom.Rewarded(indicesRwd:iTrial);
ndxLeftRewd = BpodSystem.Data.Custom.ChoiceCorrect(indicesRwd:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(indicesRwd:iTrial) == 1;
ndxLeftRewDone = BpodSystem.Data.Custom.LeftRewarded(indicesRwd:iTrial)==1 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(indicesRwd:iTrial));
ndxRightRewd = BpodSystem.Data.Custom.ChoiceCorrect(indicesRwd:iTrial) == 1  & BpodSystem.Data.Custom.ChoiceLeft(indicesRwd:iTrial) == 0;
ndxRightRewDone = BpodSystem.Data.Custom.LeftRewarded(indicesRwd:iTrial)==0 & ~isnan(BpodSystem.Data.Custom.ChoiceLeft(indicesRwd:iTrial));
if sum(ndxLeftRewDone) == 0    
    % SInce we don't have trials on this side, then measuer by how good
    % the animals was performing on the other side. If it did bad on the
    % side then then consider this side performance to be good so it'd
    % still get more trials on the other side.
    PerfL = 1 - (sum(ndxRightRewd)/(LAST_TRIALS*2));
else
    PerfL = sum(ndxLeftRewd)/sum(ndxLeftRewDone);
end
if sum(ndxRightRewDone) == 0
    PerfR = 1 - (sum(ndxLeftRewd)/(LAST_TRIALS*2));
else
    PerfR = sum(ndxRightRewd)/sum(ndxRightRewDone);
end
TaskParameters.GUI.CalcLeftBias = (PerfL-PerfR)/2 + 0.5;

choiceMadeTrials = BpodSystem.Data.Custom.ChoiceCorrect(~isnan(BpodSystem.Data.Custom.ChoiceCorrect));
rewardedTrialsCount = sum(BpodSystem.Data.Custom.Rewarded == 1);
lengthChoiceMadeTrials = length(choiceMadeTrials);
if lengthChoiceMadeTrials >= 1
    performance = rewardedTrialsCount/lengthChoiceMadeTrials;
    TaskParameters.GUI.Performance = [num2str(performance*100,'%.2f'),...
        '%/', num2str(lengthChoiceMadeTrials), 'T'];
    performance = rewardedTrialsCount/iTrial;
    TaskParameters.GUI.AllPerformance = [...
        num2str(performance*100,'%.2f'), '%/', num2str(iTrial), 'T'];
    NUM_LAST_TRIALS=20;
    if iTrial > NUM_LAST_TRIALS
        if lengthChoiceMadeTrials > NUM_LAST_TRIALS
            rewardedTrials_ = choiceMadeTrials(...
                lengthChoiceMadeTrials-NUM_LAST_TRIALS + 1 :...
                lengthChoiceMadeTrials);
            performance = sum(rewardedTrials_ == true)/NUM_LAST_TRIALS;
            TaskParameters.GUI.Performance = [...
                TaskParameters.GUI.Performance, ...
                ' - ', num2str(performance*100,'%.2f'), '%/',...
                num2str(NUM_LAST_TRIALS) ,'T'];
        end
        rewardedTrialsCount = sum(BpodSystem.Data.Custom.Rewarded(...
            iTrial-NUM_LAST_TRIALS+1:iTrial) == 1);
        performance = rewardedTrialsCount/NUM_LAST_TRIALS;
        TaskParameters.GUI.AllPerformance = [...
            TaskParameters.GUI.AllPerformance, ...
            ' - ', num2str(performance*100,'%.2f'), '%/',...
            num2str(NUM_LAST_TRIALS), 'T'];
    end
end
BpodSystem.Data.Timer.customCalcBias(iTrial) = toc; tic;

%create future trials
% Check if its time to generate more future trials
if iTrial > numel(BpodSystem.Data.Custom.DV) - Const.PRE_GENERATE_TRIAL_CHECK
    % Do bias correction only if we have enough trials
    if TaskParameters.GUI.CorrectBias && iTrial > 7  %sum(ndxRewd) > Const.BIAS_CORRECT_MIN_RWD_TRIALS
        LeftBias = TaskParameters.GUI.CalcLeftBias;
        %if LeftBias < 0.2 || LeftBias > 0.8 % Bias is too much, swing it all the way to the other side
        %LeftBias = round(LeftBias);
        %else
        if 0.45 <= LeftBias && LeftBias <= 0.55
           LeftBias = 0.5;
        end
		if isnan(LeftBias) || isinf(LeftBias)
			disp('Left bias is inf or nan: ' + string(LeftBias));
			LeftBias = 0.5;
		end
    else
        LeftBias = TaskParameters.GUI.LeftBias;
    end
    BpodSystem.Data.Timer.customAdjustBias(iTrial) = toc; tic;

    % Adjustment of P(Omega) to make sure that sum(P(Omega))=1
    if ~TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
        if sum(TaskParameters.GUI.OmegaTable.OmegaProb) == 0 % Avoid having no probability and avoid dividing by zero
            TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
        end
        TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);
    end
    BpodSystem.Data.Timer.customCalcOmega(iTrial) = toc; tic;

    % make future trials
    lastidx = numel(BpodSystem.Data.Custom.DV);
    % Generate guaranteed equal possibility of >0.5 and <0.5
    IsLeftRewarded = [zeros(1, round(Const.PRE_GENERATE_TRIAL_COUNT*LeftBias)) ones(1, round(Const.PRE_GENERATE_TRIAL_COUNT*(1-LeftBias)))];
    % Shuffle array and convert it
    IsLeftRewarded = IsLeftRewarded(randperm(numel(IsLeftRewarded))) > LeftBias;
    BpodSystem.Data.Timer.customPrepNewTrials(iTrial) = toc; tic;
    for a = 1:Const.PRE_GENERATE_TRIAL_COUNT
        % If it's a fifty-fifty trial, then place stimulus in the middle
        if rand(1,1) < TaskParameters.GUI.Percent50Fifty && (lastidx+a) > TaskParameters.GUI.StartEasyTrials % 50Fifty trials
            BpodSystem.Data.Custom.StimulusOmega(lastidx+a) = 0.5;
        else
            if TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
                % Divide beta by 4 if we are in an easy trial
                BetaDiv = iff((lastidx+a) <= TaskParameters.GUI.StartEasyTrials, 4, 1);
                Intensity = betarnd(TaskParameters.GUI.BetaDistAlphaNBeta/BetaDiv,TaskParameters.GUI.BetaDistAlphaNBeta/BetaDiv,1,1);
                Intensity = iff(Intensity < 0.1, 0.1, Intensity); %prevent extreme values
                Intensity = iff(Intensity > 0.9, 0.9, Intensity); %prevent extreme values
            elseif TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.DiscretePairs
                if (lastidx+a) <= TaskParameters.GUI.StartEasyTrials;
                    index = find(TaskParameters.GUI.OmegaTable.OmegaProb > 0, 1);
                    Intensity = TaskParameters.GUI.OmegaTable.Omega(index)/100;
                else
                    % Choose a value randomly given the each value probability
                    Intensity = randsample(TaskParameters.GUI.OmegaTable.Omega,1,1,TaskParameters.GUI.OmegaTable.OmegaProb)/100;
                end
            else
                assert(false, 'Unexpected StimulusSelectionCriteria');
            end
            % In case of beta distribution, our distribution is symmetric,
            % so prob < 0.5 is == prob > 0.5, so we can just pick the value
            % that corrects the bias
            if (IsLeftRewarded(a) && Intensity < 0.5) || (~IsLeftRewarded(a) && Intensity >= 0.5)
                Intensity = -Intensity + 1;
            end
            BpodSystem.Data.Custom.StimulusOmega(lastidx+a) = Intensity;
        end

        switch TaskParameters.GUI.ExperimentType
            case ExperimentType.Auditory
                DV = CalcAudClickTrain(lastidx+a);
            case ExperimentType.LightIntensity
                DV = CalcLightIntensity(lastidx+a);
            case ExperimentType.GratingOrientation
                DV = CalcGratingOrientation(lastidx+a);
            case ExperimentType.RandomDots
                DV = CalcDotsCoherence(lastidx+a);
            case ExperimentType.SoundDiscrimination
                DV = CalcSoundDiscrimination(lastidx+a);
            otherwise
                assert(false, 'Unexpected ExperimentType');
        end
        if DV > 0
            BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = 1;
        elseif DV < 0
            BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = 0;
        else
            BpodSystem.Data.Custom.LeftRewarded(lastidx+a) = rand<0.5; % It's equal distribution
        end
        % cross-modality difficulty for plotting
        %  0 <= (left - right) / (left + right) <= 1
        BpodSystem.Data.Custom.DV(lastidx+a) = DV;
    end%for a=1:5
    BpodSystem.Data.Timer.customGenNewTrials(iTrial) = toc;
else
    BpodSystem.Data.Timer.customAdjustBias(iTrial) = 0;
    BpodSystem.Data.Timer.customCalcOmega(iTrial) = 0;
    BpodSystem.Data.Timer.customPrepNewTrials(iTrial) = 0;
    BpodSystem.Data.Timer.customGenNewTrials(iTrial) = 0;
end%if trial > - 5
tic;

% send auditory stimuli to PulsePal for next trial
if TaskParameters.GUI.ExperimentType == ExperimentType.Auditory && ~BpodSystem.EmulatorMode
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{iTrial+1}))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}))*5);
end

% Update RDK GUI
TaskParameters.GUI.OmegaTable.RDK = (TaskParameters.GUI.OmegaTable.Omega - 50)*2;
% Set current stimulus for next trial
DV = BpodSystem.Data.Custom.DV(iTrial+1);
if TaskParameters.GUI.ExperimentType == ExperimentType.RandomDots
    TaskParameters.GUI.CurrentStim = strcat(...
        num2str(abs(DV/0.01)), iff(DV < 0, '% R cohr.', '% L cohr.'));
else
    % Set between -100 to +100
    StimIntensity = num2str(iff(DV > 0, (DV+1)/0.02, (DV-1)/-0.02));
    TaskParameters.GUI.CurrentStim = strcat(StimIntensity,...
        iff(DV < 0, '% R', '% L'));
end

%%update hidden TaskParameter fields
TaskParameters.Figures.ParameterGUI.Position = BpodSystem.ProtocolFigures.ParameterGUI.Position;
BpodSystem.Data.Timer.customFinializeUpdate(iTrial) = toc; tic;

%determine if optogentics trial
OptoEnabled = rand(1,1) <  TaskParameters.GUI.OptoProb_stimulus_delivery;
if iTrial < TaskParameters.GUI.StartEasyTrials
    OptoEnabled = false;
end
BpodSystem.Data.Custom.OptoEnabled_stimulus_delivery(iTrial+1) = OptoEnabled;
TaskParameters.GUI.OptoTrial_stimulus_delivery = iff(OptoEnabled, 'True', 'False');

% determine if catch trial
if iTrial < TaskParameters.GUI.StartEasyTrials || ...
   TaskParameters.GUI.PercentCatch == 0
    BpodSystem.Data.Custom.CatchTrial(iTrial+1) = false;
else
    every_n_trials = round(1/TaskParameters.GUI.PercentCatch);
    limit = round(every_n_trials*0.2);
    lower_limit = every_n_trials - limit;
    upper_limit = every_n_trials + limit;
    if ~BpodSystem.Data.Custom.Rewarded(iTrial) ||...
     iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + lower_limit
        BpodSystem.Data.Custom.CatchTrial(iTrial+1) = false;
    elseif iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + upper_limit
        %TODO: If OmegaProb changed since last time, then redo it
        non_zero_prob = TaskParameters.GUI.OmegaTable.Omega(...
                              TaskParameters.GUI.OmegaTable.OmegaProb > 0);
        non_zero_prob = [1-(non_zero_prob'/100), flip(non_zero_prob'/100)];
        active_stim_idxs = GetCatchStimIdx(non_zero_prob);
        cur_stim_idx = GetCatchStimIdx(...
                           BpodSystem.Data.Custom.StimulusOmega(iTrial+1));
        min_catch_counts = min(...
                      BpodSystem.Data.Custom.CatchCount(active_stim_idxs));
        min_catch_idxs = intersect(active_stim_idxs,find(...
            floor(BpodSystem.Data.Custom.CatchCount) == min_catch_counts));
        if any(min_catch_idxs == cur_stim_idx)
            BpodSystem.Data.Custom.CatchTrial(iTrial+1) = true;
        else
            BpodSystem.Data.Custom.CatchTrial(iTrial+1) = false;
        end
    else
        BpodSystem.Data.Custom.CatchTrial(iTrial+1) = true;
    end
end
% Create as char vector rather than string so that GUI sync doesn't complain
TaskParameters.GUI.IsCatch = iff(BpodSystem.Data.Custom.CatchTrial(iTrial+1), 'true', 'false');
% Determine if Forced LED trial:
if TaskParameters.GUI.PortLEDtoCueReward
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = rand(1,1) < TaskParameters.GUI.PercentForcedLEDTrial;
else
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = false;
end
BpodSystem.Data.Timer.customCatchNForceLed(iTrial) = toc; %tic;


if iTrial == 3
       disp('Disabled attempt to save data to PHP server'); 
end
%send bpod status to server
%try
    %script = 'receivebpodstatus.php';
    %create a common "outcome" vector
    %outcome = BpodSystem.Data.Custom.ChoiceCorrect(1:iTrial); %1=correct, 0=wrong
    %outcome(BpodSystem.Data.Custom.EarlyWithdrawal(1:iTrial))=2; %early withdrawal=2
    %outcome(BpodSystem.Data.Custom.FixBroke(1:iTrial))=3;%jackpot=3
    %SendTrialStatusToServer(script,BpodSystem.Data.Custom.Rig,outcome,BpodSystem.Data.Custom.Subject,BpodSystem.CurrentProtocolName);
%catch
%end
%BpodSystem.Data.Timer.customSendPhp(iTrial) = toc;

end

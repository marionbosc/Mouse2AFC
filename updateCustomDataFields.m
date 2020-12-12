function updateCustomDataFields(iTrial)
% iTrial = The sequential number of the trial that just ran
global BpodSystem
global TaskParameters

function MatStr = str(matrix_state)
    MatStr = MatrixState.String(matrix_state);
end

tic;
%% Standard values
% Stores which lateral port the animal poked into (if any)
BpodSystem.Data.Custom.Trials(iTrial).ChoiceLeft = NaN;
% Stores whether the animal poked into the correct port (if any)
BpodSystem.Data.Custom.Trials(iTrial).ChoiceCorrect = NaN;
% Signals whether confidence was used in this trial. Set to false if
% lateral ports choice timed-out (i.e, MissedChoice(i) is true), it also
% should be set to false (but not due to a bug) if the animal poked the
% a lateral port but didn't complete the feedback period (even with using
% grace).
BpodSystem.Data.Custom.Trials(iTrial).Feedback = true;
% How long the animal spent waiting for the reward (whether in correct or
% in incorrect ports)
BpodSystem.Data.Custom.Trials(iTrial).FeedbackTime = NaN;
% Signals whether the animal broke fixation during stimulus delay state
BpodSystem.Data.Custom.Trials(iTrial).FixBroke = false;
% Signals whether the animal broke fixation during sampling but before
% min-sampling ends
BpodSystem.Data.Custom.Trials(iTrial).EarlyWithdrawal = false;
% Signals whether the animal correctly finished min-sampling but failed
% to poke any of the lateral ports within ChoiceDeadLine period
BpodSystem.Data.Custom.Trials(iTrial).MissedChoice = false;
% How long the animal remained fixated in center poke
BpodSystem.Data.Custom.Trials(iTrial).FixDur = NaN;
% How long between sample end and making a choice (timeout-choice trials
% are excluded)
BpodSystem.Data.Custom.Trials(iTrial).MT = NaN;
% How long the animal sampled. If RewardAfterMinSampling is enabled and
% animal completed min sampling, then it's equal to MinSample time,
% otherwise it's how long the animal remained fixated in center-port until
% it either poked-out or the max allowed sampling time was reached.
BpodSystem.Data.Custom.Trials(iTrial).ST = NaN;
% Signals whether a reward was given to the animal (it also includes if the
% animal poked into the correct reward port but poked out afterwards and
% didn't receive a reward, due to 'RewardGrace' being counted as reward).
BpodSystem.Data.Custom.Trials(iTrial).Rewarded = false;
% Signals whether a center-port reward was given after min-sampling ends.
BpodSystem.Data.Custom.Trials(iTrial).RewardAfterMinSampling = false;
% Tracks the amount of water the animal received up tp this point
% TODO: Check if RewardReceivedTotal is needed and calculate it using
% CalcRewObtained() function.
BpodSystem.Data.Custom.Trials(iTrial+1).RewardReceivedTotal = 0; % We will updated later

BpodSystem.Data.Custom.Trials(iTrial).TrialNumber = iTrial;

BpodSystem.Data.Timer(iTrial).customInitialize = toc; tic;

%% Checking states and rewriting standard
% Extract the states that were used in the last trial
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
eventsStatesThisTrial = BpodSystem.Data.RawEvents.Trial{end}.States;
if any(strcmp(str(MatrixState.WaitForStimulus),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).FixDur = ...
     (eventsStatesThisTrial.WaitForStimulus(end,2) - eventsStatesThisTrial.WaitForStimulus(end,1)) + ...
     (eventsStatesThisTrial.TriggerWaitForStimulus(end,2) - eventsStatesThisTrial.TriggerWaitForStimulus(end,1));
end
if any(strcmp(str(MatrixState.stimulus_delivery),statesThisTrial))
    if TaskParameters.GUI.RewardAfterMinSampling
        BpodSystem.Data.Custom.Trials(iTrial).ST = diff(eventsStatesThisTrial.stimulus_delivery);
    else
        % 'CenterPortRewardDelivery' state would exist even if no
        % 'RewardAfterMinSampling' is active, in such case it means that
        % min sampling is done and we are in the optional sampling stage.
        if any(strcmp(str(MatrixState.CenterPortRewardDelivery),statesThisTrial)) && TaskParameters.GUI.StimulusTime > TaskParameters.GUI.MinSample
            BpodSystem.Data.Custom.Trials(iTrial).ST = eventsStatesThisTrial.CenterPortRewardDelivery(1,2) - eventsStatesThisTrial.stimulus_delivery(1,1);
        else
            % This covers early_withdrawal.
            BpodSystem.Data.Custom.Trials(iTrial).ST = diff(eventsStatesThisTrial.stimulus_delivery);
        end
    end
end

if any(strcmp(str(MatrixState.WaitForChoice),statesThisTrial)) && ~any(strcmp(str(MatrixState.timeOut_missed_choice),statesThisTrial))
    % We might have more than multiple WaitForChoice if
    % HabituateIgnoreIncorrect is enabeld
    BpodSystem.Data.Custom.Trials(end).MT = diff(eventsStatesThisTrial.WaitForChoice(1:2));
end

% Extract trial outcome. Check first if it's a wrong choice or a
% HabituateIgnoreIncorrect but first choice was wrong choice
if any(strcmp(str(MatrixState.WaitForPunishStart),statesThisTrial)) || any(strcmp(str(MatrixState.RegisterWrongWaitCorrect),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).ChoiceCorrect = 0;
    if BpodSystem.Data.Custom.Trials(iTrial).LeftRewarded == 1 % Correct choice = left
        BpodSystem.Data.Custom.Trials(iTrial).ChoiceLeft = 0; % Left not chosen
    else
        BpodSystem.Data.Custom.Trials(iTrial).ChoiceLeft = 1;
    end
    if any(strcmp(str(MatrixState.WaitForPunish),statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.Trials(iTrial).FeedbackTime = eventsStatesThisTrial.WaitForPunish(end,end) - eventsStatesThisTrial.WaitForPunishStart(1,1);
    else % It was a  RegisterWrongWaitCorrect state
        BpodSystem.Data.Custom.Trials(iTrial).FeedbackTime = nan;
    end
elseif any(strcmp(str(MatrixState.WaitForRewardStart),statesThisTrial))  % CorrectChoice
    BpodSystem.Data.Custom.Trials(iTrial).ChoiceCorrect = 1;
    if BpodSystem.Data.Custom.Trials(iTrial).CatchTrial
        catch_stim_idx = GetCatchStimIdx(...
                             BpodSystem.Data.Custom.Trials(iTrial).StimulusOmega);
        % Lookup the stimulus probability and increase by its 1/frequency.
        stim_val = BpodSystem.Data.Custom.Trials(iTrial).StimulusOmega * 100;
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
    if any(strcmp(str(MatrixState.WaitForReward),statesThisTrial))  % Feedback waiting time
        BpodSystem.Data.Custom.Trials(iTrial).FeedbackTime = eventsStatesThisTrial.WaitForReward(end,end) - eventsStatesThisTrial.WaitForRewardStart(1,1);
        if BpodSystem.Data.Custom.Trials(iTrial).LeftRewarded == 1 % Correct choice = left
            BpodSystem.Data.Custom.Trials(iTrial).ChoiceLeft = 1; % Left chosen
        else
            BpodSystem.Data.Custom.Trials(iTrial).ChoiceLeft = 0;
        end
    else
        orig_warn = warning;
        warning('on'); % Temporarily force displaying of warnings
        warning('''WaitForReward'' state should always appear if ''WaitForRewardStart'' was initiated');
        warning(orig_warn); % Restore the original warning values
    end
elseif any(strcmp(str(MatrixState.broke_fixation),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).FixBroke = true;
elseif any(strcmp(str(MatrixState.early_withdrawal),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).EarlyWithdrawal = true;
elseif any(strcmp(str(MatrixState.timeOut_missed_choice),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).Feedback = false;
    BpodSystem.Data.Custom.Trials(iTrial).MissedChoice = true;
end
if any(strcmp(str(MatrixState.timeOut_SkippedFeedback),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).Feedback = false;
end
if any(strcmp(str(MatrixState.Reward),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).Rewarded = true;
    BpodSystem.Data.Custom.Trials(iTrial).RewardReceivedTotal = ...
        BpodSystem.Data.Custom.Trials(iTrial).RewardReceivedTotal + TaskParameters.GUI.RewardAmount;
end
if any(strcmp(str(MatrixState.CenterPortRewardDelivery),statesThisTrial)) && TaskParameters.GUI.RewardAfterMinSampling
    BpodSystem.Data.Custom.Trials(iTrial).RewardAfterMinSampling = true;
    BpodSystem.Data.Custom.Trials(iTrial).RewardReceivedTotal = ...
        BpodSystem.Data.Custom.Trials(iTrial).RewardReceivedTotal + TaskParameters.GUI.CenterPortRewAmount;
end
if any(strcmp(str(MatrixState.WaitCenterPortOut),statesThisTrial))
    BpodSystem.Data.Custom.Trials(iTrial).ReactionTime = diff(eventsStatesThisTrial.WaitCenterPortOut);
else % Assign with -1 so we can differntiate it from nan trials where the
     % state potentially existed but we didn't calculate it
    BpodSystem.Data.Custom.Trials(iTrial).ReactionTime = -1;
end
%% State-independent fields
BpodSystem.Data.Custom.Trials(iTrial).StimDelay = TaskParameters.GUI.StimDelay;
BpodSystem.Data.Custom.Trials(iTrial).FeedbackDelay = TaskParameters.GUI.FeedbackDelay;
BpodSystem.Data.Custom.Trials(iTrial).MinSample = TaskParameters.GUI.MinSample;
BpodSystem.Data.Custom.Trials(iTrial+1).RewardMagnitude = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.Trials(iTrial+1).CenterPortRewAmount = TaskParameters.GUI.CenterPortRewAmount;
BpodSystem.Data.Custom.Trials(iTrial+1).PreStimCntrReward = TaskParameters.GUI.PreStimuDelayCntrReward;
BpodSystem.Data.Timer(iTrial).customExtractData = toc; tic;

% IF we are running grating experiments, add the grating orientation that was used
if TaskParameters.GUI.ExperimentType == ExperimentType.GratingOrientation
    BpodSystem.Data.Custom.Trials(iTrial).GratingOrientation = BpodSystem.Data.Custom.drawParams.gratingOrientation;
end

%% Updating Delays
%stimulus delay
if TaskParameters.GUI.StimDelayAutoincrement
    if BpodSystem.Data.Custom.Trials(iTrial).FixBroke
        TaskParameters.GUI.StimDelay = max(TaskParameters.GUI.StimDelayMin,...
            min(TaskParameters.GUI.StimDelayMax,BpodSystem.Data.Custom.Trials(iTrial).StimDelay-TaskParameters.GUI.StimDelayDecr));
    else
        TaskParameters.GUI.StimDelay = min(TaskParameters.GUI.StimDelayMax,...
            max(TaskParameters.GUI.StimDelayMin,BpodSystem.Data.Custom.Trials(iTrial).StimDelay+TaskParameters.GUI.StimDelayIncr));
    end
else
    if ~BpodSystem.Data.Custom.Trials(iTrial).FixBroke
        TaskParameters.GUI.StimDelay = random('unif',TaskParameters.GUI.StimDelayMin,TaskParameters.GUI.StimDelayMax);
    else
        TaskParameters.GUI.StimDelay = BpodSystem.Data.Custom.Trials(iTrial).StimDelay;
    end
end
BpodSystem.Data.Timer(iTrial).customStimDelay = toc; tic;

%min sampling time
if iTrial > TaskParameters.GUI.StartEasyTrials
    switch TaskParameters.GUI.MinSampleType
        case MinSampleType.FixMin
            TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
        case MinSampleType.AutoIncr
            % Check if animal completed pre-stimulus delay successfully
            if ~BpodSystem.Data.Custom.Trials(iTrial).FixBroke
                if BpodSystem.Data.Custom.Trials(iTrial).Rewarded
                    TaskParameters.GUI.MinSample = min(TaskParameters.GUI.MinSampleMax,...
                        max(TaskParameters.GUI.MinSampleMin,BpodSystem.Data.Custom.Trials(iTrial).MinSample + TaskParameters.GUI.MinSampleIncr));
                elseif BpodSystem.Data.Custom.Trials(iTrial).EarlyWithdrawal
                    TaskParameters.GUI.MinSample = max(TaskParameters.GUI.MinSampleMin,...
                        min(TaskParameters.GUI.MinSampleMax,BpodSystem.Data.Custom.Trials(iTrial).MinSample - TaskParameters.GUI.MinSampleDecr));
                end
            else % Read new updated GUI values
                TaskParameters.GUI.MinSample = max(TaskParameters.GUI.MinSampleMin,...
                    min(TaskParameters.GUI.MinSampleMax,BpodSystem.Data.Custom.Trials(iTrial).MinSample));
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
BpodSystem.Data.Timer(iTrial).customMinSampling = toc; tic;

%feedback delay
switch TaskParameters.GUI.FeedbackDelaySelection
    case FeedbackDelaySelection.None
        TaskParameters.GUI.FeedbackDelay = 0;
    case FeedbackDelaySelection.AutoIncr
        % if no feedback was not completed then use the last value unless
        % then decrement the feedback.
        % Do we consider the case where 'broke_fixation' or
        % 'early_withdrawal' terminated early the trial?
        if ~BpodSystem.Data.Custom.Trials(iTrial).Feedback
            TaskParameters.GUI.FeedbackDelay = max(TaskParameters.GUI.FeedbackDelayMin,...
                min(TaskParameters.GUI.FeedbackDelayMax,BpodSystem.Data.Custom.Trials(iTrial).FeedbackDelay-TaskParameters.GUI.FeedbackDelayDecr));
        else
            % Increase the feedback if the feedback was successfully
            % completed in the last trial, or use the the GUI value that
            % the user updated if needed.
            % Do we also here consider the case where 'broke_fixation' or
            % 'early_withdrawal' terminated early the trial?
            TaskParameters.GUI.FeedbackDelay = min(TaskParameters.GUI.FeedbackDelayMax,...
                max(TaskParameters.GUI.FeedbackDelayMin,BpodSystem.Data.Custom.Trials(iTrial).FeedbackDelay+TaskParameters.GUI.FeedbackDelayIncr));
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
BpodSystem.Data.Timer(iTrial).customFeedbackDelay = toc; tic;

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
startTrialBiasCalc = iff(iTrial > LAST_TRIALS, iTrial - LAST_TRIALS, 1);
%ndxRewd = BpodSystem.Data.Custom.Trials(indicesRwd:iTrial).Rewarded;
allBiasTrials = [BpodSystem.Data.Custom.Trials(startTrialBiasCalc:iTrial).ChoiceLeft];
choiceBiasTrialsIdxs = find(~isnan(allBiasTrials)) + startTrialBiasCalc;
%TODO: Check if we need to add an offset to the indices
leftChoiceBiasTrials = find([BpodSystem.Data.Custom.Trials(...
              choiceBiasTrialsIdxs).ChoiceLeft] == 1) + startTrialBiasCalc;
rightChoiceBiasTrials = find([BpodSystem.Data.Custom.Trials(...
              choiceBiasTrialsIdxs).ChoiceLeft] == 0) + startTrialBiasCalc;

ndxLeftRewd = [BpodSystem.Data.Custom.Trials(leftChoiceBiasTrials).ChoiceCorrect] == 1;
ndxLeftRewDone = [BpodSystem.Data.Custom.Trials(choiceBiasTrialsIdxs).LeftRewarded] == 1;
ndxRightRewd = [BpodSystem.Data.Custom.Trials(rightChoiceBiasTrials).ChoiceCorrect] == 1;
ndxRightRewDone = [BpodSystem.Data.Custom.Trials(choiceBiasTrialsIdxs).LeftRewarded] == 0;
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

allTrialsChoices = [BpodSystem.Data.Custom.Trials(1:iTrial).ChoiceCorrect];
choiceMadeTrials = allTrialsChoices(~isnan(allTrialsChoices));
rewardedTrialsCount = sum([BpodSystem.Data.Custom.Trials(1:iTrial).Rewarded] == 1);
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
        rewardedTrialsCount = sum(...
            [BpodSystem.Data.Custom.Trials(...
                          iTrial-NUM_LAST_TRIALS+1:iTrial).Rewarded] == 1);
        performance = rewardedTrialsCount/NUM_LAST_TRIALS;
        TaskParameters.GUI.AllPerformance = [...
            TaskParameters.GUI.AllPerformance, ...
            ' - ', num2str(performance*100,'%.2f'), '%/',...
            num2str(NUM_LAST_TRIALS), 'T'];
    end
end
BpodSystem.Data.Timer(iTrial).customCalcBias = toc; tic;

%create future trials
% Check if its time to generate more future trials
if iTrial > BpodSystem.Data.Custom.DVsAlreadyGenerated - Const.PRE_GENERATE_TRIAL_CHECK
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
    BpodSystem.Data.Timer(iTrial).customAdjustBias = toc; tic;

    % Adjustment of P(Omega) to make sure that sum(P(Omega))=1
    if ~TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
        if sum(TaskParameters.GUI.OmegaTable.OmegaProb) == 0 % Avoid having no probability and avoid dividing by zero
            TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.OmegaProb));
        end
        TaskParameters.GUI.OmegaTable.OmegaProb = TaskParameters.GUI.OmegaTable.OmegaProb/sum(TaskParameters.GUI.OmegaTable.OmegaProb);
    end
    BpodSystem.Data.Timer(iTrial).customCalcOmega = toc; tic;

    % make future trials
    lastidx = BpodSystem.Data.Custom.DVsAlreadyGenerated;
    % Generate guaranteed equal possibility of >0.5 and <0.5
    IsLeftRewarded = [zeros(1, round(Const.PRE_GENERATE_TRIAL_COUNT*LeftBias)) ones(1, round(Const.PRE_GENERATE_TRIAL_COUNT*(1-LeftBias)))];
    % Shuffle array and convert it
    IsLeftRewarded = IsLeftRewarded(randperm(numel(IsLeftRewarded))) > LeftBias;
    BpodSystem.Data.Timer(iTrial).customPrepNewTrials = toc; tic;
    for a = 1:Const.PRE_GENERATE_TRIAL_COUNT
        % If it's a fifty-fifty trial, then place stimulus in the middle
        if rand(1,1) < TaskParameters.GUI.Percent50Fifty && (lastidx+a) > TaskParameters.GUI.StartEasyTrials % 50Fifty trials
            BpodSystem.Data.Custom.Trials(lastidx+a).StimulusOmega = 0.5;
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
            BpodSystem.Data.Custom.Trials(lastidx+a).StimulusOmega = Intensity;
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
            otherwise
                assert(false, 'Unexpected ExperimentType');
        end
        if DV > 0
            BpodSystem.Data.Custom.Trials(lastidx+a).LeftRewarded = 1;
        elseif DV < 0
            BpodSystem.Data.Custom.Trials(lastidx+a).LeftRewarded = 0;
        else
            BpodSystem.Data.Custom.Trials(lastidx+a).LeftRewarded = rand<0.5; % It's equal distribution
        end
        % cross-modality difficulty for plotting
        %  0 <= (left - right) / (left + right) <= 1
        BpodSystem.Data.Custom.Trials(lastidx+a).DV = DV;
    end%for a=1:5
    BpodSystem.Data.Custom.DVsAlreadyGenerated = ...
                            BpodSystem.Data.Custom.DVsAlreadyGenerated +...
                            Const.PRE_GENERATE_TRIAL_COUNT;
    BpodSystem.Data.Timer(iTrial).customGenNewTrials = toc;
else
    BpodSystem.Data.Timer(iTrial).customAdjustBias = 0;
    BpodSystem.Data.Timer(iTrial).customCalcOmega = 0;
    BpodSystem.Data.Timer(iTrial).customPrepNewTrials = 0;
    BpodSystem.Data.Timer(iTrial).customGenNewTrials = 0;
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
DV = BpodSystem.Data.Custom.Trials(iTrial+1).DV;
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
BpodSystem.Data.Timer(iTrial).customFinializeUpdate = toc; tic;

%determine if optogentics trial
OptoEnabled = rand(1,1) <  TaskParameters.GUI.OptoProb;
if iTrial < TaskParameters.GUI.StartEasyTrials
    OptoEnabled = false;
end
BpodSystem.Data.Custom.Trials(iTrial+1).OptoEnabled = OptoEnabled;
TaskParameters.GUI.IsOptoTrial = iff(OptoEnabled, 'true', 'false');

% determine if catch trial
if iTrial < TaskParameters.GUI.StartEasyTrials || ...
   TaskParameters.GUI.PercentCatch == 0
    BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial = false;
else
    every_n_trials = round(1/TaskParameters.GUI.PercentCatch);
    limit = round(every_n_trials*0.2);
    lower_limit = every_n_trials - limit;
    upper_limit = every_n_trials + limit;
    if ~BpodSystem.Data.Custom.Trials(iTrial).Rewarded ||...
     iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + lower_limit
        BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial = false;
    elseif iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + upper_limit
        %TODO: If OmegaProb changed since last time, then redo it
        non_zero_prob = TaskParameters.GUI.OmegaTable.Omega(...
                              TaskParameters.GUI.OmegaTable.OmegaProb > 0);
        non_zero_prob = [1-(non_zero_prob'/100), flip(non_zero_prob'/100)];
        active_stim_idxs = GetCatchStimIdx(non_zero_prob);
        cur_stim_idx = GetCatchStimIdx(...
                           BpodSystem.Data.Custom.Trials(iTrial+1).StimulusOmega);
        min_catch_counts = min(...
                      BpodSystem.Data.Custom.CatchCount(active_stim_idxs));
        min_catch_idxs = intersect(active_stim_idxs,find(...
            floor(BpodSystem.Data.Custom.CatchCount) == min_catch_counts));
        if any(min_catch_idxs == cur_stim_idx)
            BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial = true;
        else
            BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial = false;
        end
    else
        BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial = true;
    end
end
% Create as char vector rather than string so that GUI sync doesn't complain
TaskParameters.GUI.IsCatch = iff(BpodSystem.Data.Custom.Trials(iTrial+1).CatchTrial, 'true', 'false');
% Determine if Forced LED trial:
if TaskParameters.GUI.PortLEDtoCueReward
    BpodSystem.Data.Custom.Trials(iTrial+1).ForcedLEDTrial = rand(1,1) < TaskParameters.GUI.PercentForcedLEDTrial;
else
    BpodSystem.Data.Custom.Trials(iTrial+1).ForcedLEDTrial = false;
end
BpodSystem.Data.Timer(iTrial).customCatchNForceLed = toc; %tic;


if iTrial == 3
       disp('Disabled attempt to save data to PHP server'); 
end
%send bpod status to server
%try
    %script = 'receivebpodstatus.php';
    %create a common "outcome" vector
    %outcome = BpodSystem.Data.Custom.Trials(1:iTrial).ChoiceCorrect; %1=correct, 0=wrong
    %outcome(BpodSystem.Data.Custom.Trials(1:iTrial).EarlyWithdrawal)=2; %early withdrawal=2
    %outcome(BpodSystem.Data.Custom.Trials(1:iTrial).FixBroke)=3;%jackpot=3
    %SendTrialStatusToServer(script,BpodSystem.Data.Custom.Rig,outcome,BpodSystem.Data.Custom.Subject,BpodSystem.CurrentProtocolName);
%catch
%end
%BpodSystem.Data.Timer(iTrial).customSendPhp = toc;

end

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
BpodSystem.Data.Custom.TrialNumber(iTrial) = iTrial;

BpodSystem.Data.Timer.customInitialize(iTrial) = toc; tic;

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
        if any(strcmp('CenterPortRewardDelivery',statesThisTrial)) && TaskParameters.GUI.StimulusTime > TaskParameters.GUI.MinSample
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
BpodSystem.Data.Custom.MinSample(iTrial) = TaskParameters.GUI.MinSample;
BpodSystem.Data.Custom.RewardMagnitude(iTrial+1,:) = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount(iTrial+1) =TaskParameters.GUI.CenterPortRewAmount;

BpodSystem.Data.Timer.customExtractData(iTrial) = toc; tic;

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
if TaskParameters.GUI.MinSampleAutoincrement && iTrial > TaskParameters.GUI.StartEasyTrials
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
else % Use non-incremental fixed value
    TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
end
BpodSystem.Data.Timer.customMinSampling(iTrial) = toc; tic;

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
BpodSystem.Data.Timer.customFeedbackDelay(iTrial) = toc; tic;

%% Drawing future trials

% determine if catch trial
if iTrial > TaskParameters.GUI.StartEasyTrials
    BpodSystem.Data.Custom.CatchTrial(iTrial+1) = rand(1,1) < TaskParameters.GUI.PercentCatch;
else
    BpodSystem.Data.Custom.CatchTrial(iTrial+1) = false;
end
% Create as char vector rather than string so that GUI sync doesn't complain
TaskParameters.GUI.IsCatch = iff(BpodSystem.Data.Custom.CatchTrial(iTrial+1), 'true', 'false');

% Determine if Forced LED trial:
if TaskParameters.GUI.PortLEDtoCueReward
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = rand(1,1) < TaskParameters.GUI.PercentForcedLEDTrial;
else
    BpodSystem.Data.Custom.ForcedLEDTrial(iTrial+1) = false;
end
BpodSystem.Data.Timer.customCatchNForceLed(iTrial) = toc; tic;

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
rewardedTrials = BpodSystem.Data.Custom.ChoiceCorrect(BpodSystem.Data.Custom.Rewarded == 1);
lengthChoiceMadeTrials = length(choiceMadeTrials);
if lengthChoiceMadeTrials >= 1
    performance = sum(rewardedTrials == true)/lengthChoiceMadeTrials;
    TaskParameters.GUI.Performance = [num2str(performance*100,'%.2f'), '%/', num2str(lengthChoiceMadeTrials), 'T'];
    NUM_LAST_TRIALS=20;
    if lengthChoiceMadeTrials > NUM_LAST_TRIALS
        choiceMadeTrials = choiceMadeTrials(lengthChoiceMadeTrials-NUM_LAST_TRIALS + 1:lengthChoiceMadeTrials);
        performance = sum(choiceMadeTrials == true)/NUM_LAST_TRIALS;
        TaskParameters.GUI.Performance = [TaskParameters.GUI.Performance, ...
            ' - ', num2str(performance*100,'%.2f'), '%/', num2str(NUM_LAST_TRIALS) ,'T'];
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
BpodSystem.Data.Timer.customFinializeUpdate(iTrial) = toc; % tic;

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

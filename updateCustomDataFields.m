function updateCustomDataFields(iTrial)
% iTrial = The sequential number of the trial that just ran
global BpodSystem
global TaskParameters

function MatStr = str(matrix_state)
    MatStr = MatrixState.String(matrix_state);
end

CurTrial = BpodSystem.Data.Custom.Trials(iTrial);
NextTrial = BpodSystem.Data.Custom.Trials(iTrial+1);
CurTimer = BpodSystem.Data.Timer(iTrial);
GUI = TaskParameters.GUI;
tic;
%% Standard values
% Stores which lateral port the animal poked into (if any)
CurTrial.ChoiceLeft = NaN;
% Stores whether the animal poked into the correct port (if any)
CurTrial.ChoiceCorrect = NaN;
% Signals whether confidence was used in this trial. Set to false if
% lateral ports choice timed-out (i.e, MissedChoice(i) is true), it also
% should be set to false (but not due to a bug) if the animal poked the
% a lateral port but didn't complete the feedback period (even with using
% grace).
CurTrial.Feedback = true;
% How long the animal spent waiting for the reward (whether in correct or
% in incorrect ports)
CurTrial.FeedbackTime = NaN;
% Signals whether the animal broke fixation during stimulus delay state
CurTrial.FixBroke = false;
% Signals whether the animal broke fixation during sampling but before
% min-sampling ends
CurTrial.EarlyWithdrawal = false;
% Signals whether the animal correctly finished min-sampling but failed
% to poke any of the lateral ports within ChoiceDeadLine period
CurTrial.MissedChoice = false;
% How long the animal remained fixated in center poke
CurTrial.FixDur = NaN;
% How long between sample end and making a choice (timeout-choice trials
% are excluded)
CurTrial.MT = NaN;
% How long the animal sampled. If RewardAfterMinSampling is enabled and
% animal completed min sampling, then it's equal to MinSample time,
% otherwise it's how long the animal remained fixated in center-port until
% it either poked-out or the max allowed sampling time was reached.
CurTrial.ST = NaN;
% Signals whether a reward was given to the animal (it also includes if the
% animal poked into the correct reward port but poked out afterwards and
% didn't receive a reward, due to 'RewardGrace' being counted as reward).
CurTrial.Rewarded = false;
% Signals whether a center-port reward was given after min-sampling ends.
CurTrial.RewardAfterMinSampling = false;
% Tracks the amount of water the animal received up tp this point
% TODO: Check if RewardReceivedTotal is needed and calculate it using
% CalcRewObtained() function.
NextTrial.RewardReceivedTotal = 0; % We will updated later

CurTrial.TrialNumber = iTrial;

CurTimer.customInitialize = toc; tic;

%% Checking states and rewriting standard
% Extract the states that were used in the last trial
statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial}(BpodSystem.Data.RawData.OriginalStateData{iTrial});
eventsStatesThisTrial = BpodSystem.Data.RawEvents.Trial{end}.States;
if any(strcmp(str(MatrixState.WaitForStimulus),statesThisTrial))
    CurTrial.FixDur = ...
     (eventsStatesThisTrial.WaitForStimulus(end,2) - eventsStatesThisTrial.WaitForStimulus(end,1)) + ...
     (eventsStatesThisTrial.TriggerWaitForStimulus(end,2) - eventsStatesThisTrial.TriggerWaitForStimulus(end,1));
end
if any(strcmp(str(MatrixState.stimulus_delivery),statesThisTrial))
    if GUI.RewardAfterMinSampling
        CurTrial.ST = diff(eventsStatesThisTrial.stimulus_delivery);
    else
        % 'CenterPortRewardDelivery' state would exist even if no
        % 'RewardAfterMinSampling' is active, in such case it means that
        % min sampling is done and we are in the optional sampling stage.
        if any(strcmp(str(MatrixState.CenterPortRewardDelivery),statesThisTrial)) && GUI.StimulusTime > GUI.MinSample
            CurTrial.ST = eventsStatesThisTrial.CenterPortRewardDelivery(1,2) - eventsStatesThisTrial.stimulus_delivery(1,1);
        else
            % This covers early_withdrawal.
            CurTrial.ST = diff(eventsStatesThisTrial.stimulus_delivery);
        end
    end
end

if any(strcmp(str(MatrixState.WaitForChoice),statesThisTrial)) && ~any(strcmp(str(MatrixState.timeOut_missed_choice),statesThisTrial))
    % We might have more than multiple WaitForChoice if
    % HabituateIgnoreIncorrect is enabeld
    CurTrial.MT = diff(eventsStatesThisTrial.WaitForChoice(1:2));
end

% Extract trial outcome. Check first if it's a wrong choice or a
% HabituateIgnoreIncorrect but first choice was wrong choice
if any(strcmp(str(MatrixState.WaitForPunishStart),statesThisTrial)) || any(strcmp(str(MatrixState.RegisterWrongWaitCorrect),statesThisTrial))
    CurTrial.ChoiceCorrect = 0;
    if CurTrial.LeftRewarded == 1 % Correct choice = left
        CurTrial.ChoiceLeft = 0; % Left not chosen
    else
        CurTrial.ChoiceLeft = 1;
    end
    if any(strcmp(str(MatrixState.WaitForPunish),statesThisTrial))  % Feedback waiting time
        CurTrial.FeedbackTime = eventsStatesThisTrial.WaitForPunish(end,end) - eventsStatesThisTrial.WaitForPunishStart(1,1);
    else % It was a  RegisterWrongWaitCorrect state
        CurTrial.FeedbackTime = nan;
    end
elseif any(strcmp(str(MatrixState.WaitForRewardStart),statesThisTrial))  % CorrectChoice
    CurTrial.ChoiceCorrect = 1;
    if CurTrial.CatchTrial
        catch_stim_idx = GetCatchStimIdx(CurTrial.StimulusOmega);
        % Lookup the stimulus probability and increase by its 1/frequency.
        stim_val = CurTrial.StimulusOmega * 100;
        if stim_val < 50
            stim_val = 100 - stim_val;
        end
        stim_prob = GUI.OmegaTable.OmegaProb(GUI.OmegaTable.Omega == stim_val);
        sum_all_prob = sum(GUI.OmegaTable.OmegaProb);
        stim_prob = (1+sum_all_prob-stim_prob)/sum_all_prob;
        BpodSystem.Data.Custom.CatchCount(catch_stim_idx) = ...
             BpodSystem.Data.Custom.CatchCount(catch_stim_idx) + stim_prob;
        BpodSystem.Data.Custom.LastSuccessCatchTial = iTrial;
    end
    if any(strcmp(str(MatrixState.WaitForReward),statesThisTrial))  % Feedback waiting time
        CurTrial.FeedbackTime = eventsStatesThisTrial.WaitForReward(end,end) - eventsStatesThisTrial.WaitForRewardStart(1,1);
        if CurTrial.LeftRewarded == 1 % Correct choice = left
            CurTrial.ChoiceLeft = 1; % Left chosen
        else
            CurTrial.ChoiceLeft = 0;
        end
    else
        orig_warn = warning;
        warning('on'); % Temporarily force displaying of warnings
        warning('''WaitForReward'' state should always appear if ''WaitForRewardStart'' was initiated');
        warning(orig_warn); % Restore the original warning values
    end
elseif any(strcmp(str(MatrixState.broke_fixation),statesThisTrial))
    CurTrial.FixBroke = true;
elseif any(strcmp(str(MatrixState.early_withdrawal),statesThisTrial))
    CurTrial.EarlyWithdrawal = true;
elseif any(strcmp(str(MatrixState.timeOut_missed_choice),statesThisTrial))
    CurTrial.Feedback = false;
    CurTrial.MissedChoice = true;
end
if any(strcmp(str(MatrixState.timeOut_SkippedFeedback),statesThisTrial))
    CurTrial.Feedback = false;
end
if any(strcmp(str(MatrixState.Reward),statesThisTrial))
    CurTrial.Rewarded = true;
    CurTrial.RewardReceivedTotal = CurTrial.RewardReceivedTotal + GUI.RewardAmount;
end
if any(strcmp(str(MatrixState.CenterPortRewardDelivery),statesThisTrial)) && GUI.RewardAfterMinSampling
    CurTrial.RewardAfterMinSampling = true;
    CurTrial.RewardReceivedTotal = CurTrial.RewardReceivedTotal + GUI.CenterPortRewAmount;
end
if any(strcmp(str(MatrixState.WaitCenterPortOut),statesThisTrial))
    CurTrial.ReactionTime = diff(eventsStatesThisTrial.WaitCenterPortOut);
else % Assign with -1 so we can differntiate it from nan trials where the
     % state potentially existed but we didn't calculate it
    CurTrial.ReactionTime = -1;
end
%% State-independent fields
CurTrial.StimDelay = GUI.StimDelay;
CurTrial.FeedbackDelay = GUI.FeedbackDelay;
CurTrial.MinSample = GUI.MinSample;
NextTrial.RewardMagnitude = GUI.RewardAmount*[1,1];
NextTrial.CenterPortRewAmount = GUI.CenterPortRewAmount;
NextTrial.PreStimCntrReward = GUI.PreStimuDelayCntrReward;
CurTimer.customExtractData = toc; tic;

% If we are running grating experiments, add the grating orientation that was
% finally used. If grating should have been instructed to be used, then it
% shouldn't be nan.
if ~isnan(CurTrial.GratingOrientation)
    CurTrial.GratingOrientation =...
                            BpodSystem.Data.Custom.drawParams.gratingOrientation;
end

%% Updating Delays
%stimulus delay
if GUI.StimDelayAutoincrement
    if CurTrial.FixBroke
        GUI.StimDelay = max(GUI.StimDelayMin,...
            min(GUI.StimDelayMax,CurTrial.StimDelay-GUI.StimDelayDecr));
    else
        GUI.StimDelay = min(GUI.StimDelayMax,...
            max(GUI.StimDelayMin,CurTrial.StimDelay+GUI.StimDelayIncr));
    end
else
    if ~CurTrial.FixBroke
        GUI.StimDelay = random('unif',GUI.StimDelayMin,GUI.StimDelayMax);
    else
        GUI.StimDelay = CurTrial.StimDelay;
    end
end
CurTimer.customStimDelay = toc; tic;

%min sampling time
if iTrial > GUI.StartEasyTrials
    switch GUI.MinSampleType
        case MinSampleType.FixMin
            GUI.MinSample = GUI.MinSampleMin;
        case MinSampleType.AutoIncr
            % Check if animal completed pre-stimulus delay successfully
            if ~CurTrial.FixBroke
                if CurTrial.Rewarded
                    GUI.MinSample = min(GUI.MinSampleMax,...
                        max(GUI.MinSampleMin,CurTrial.MinSample + GUI.MinSampleIncr));
                elseif CurTrial.EarlyWithdrawal
                    GUI.MinSample = max(GUI.MinSampleMin,...
                        min(GUI.MinSampleMax,CurTrial.MinSample - GUI.MinSampleDecr));
                end
            else % Read new updated GUI values
                GUI.MinSample = max(GUI.MinSampleMin,...
                    min(GUI.MinSampleMax,CurTrial.MinSample));
            end
        case MinSampleType.RandBetMinMax_DefIsMax
            use_rand = rand(1,1) < GUI.MinSampleRandProb;
            if ~use_rand
                GUI.MinSample = GUI.MinSampleMax;
            else
                GUI.MinSample = (GUI.MinSampleMax-GUI.MinSampleMin).*rand(1,1) + GUI.MinSampleMin;
            end
        case MinSampleType.RandNumIntervalsMinMax_DefIsMax
            use_rand = rand(1,1) < GUI.MinSampleRandProb;
            if ~use_rand
                GUI.MinSample = GUI.MinSampleMax;
            else
                GUI.MinSampleNumInterval = round(GUI.MinSampleNumInterval);
                if GUI.MinSampleNumInterval == 0 || GUI.MinSampleNumInterval == 1
                    GUI.MinSample = GUI.MinSampleMin;
                else
                    step = (GUI.MinSampleMax - GUI.MinSampleMin)/(GUI.MinSampleNumInterval-1);
                    intervals = [GUI.MinSampleMin:step:GUI.MinSampleMax];
                    intervals_idx = randi([1 GUI.MinSampleNumInterval],1,1);
                    disp("Intervals:");
                    disp(intervals)
                    GUI.MinSample = intervals(intervals_idx);
                end
            end
        otherwise
            assert(false, 'Unexpected MinSampleType value');
    end
end
CurTimer.customMinSampling = toc; tic;

%feedback delay
switch GUI.FeedbackDelaySelection
    case FeedbackDelaySelection.None
        GUI.FeedbackDelay = 0;
    case FeedbackDelaySelection.AutoIncr
        % if no feedback was not completed then use the last value unless
        % then decrement the feedback.
        % Do we consider the case where 'broke_fixation' or
        % 'early_withdrawal' terminated early the trial?
        if ~CurTrial.Feedback
            GUI.FeedbackDelay = max(GUI.FeedbackDelayMin,...
                                    min(GUI.FeedbackDelayMax,...
                                        CurTrial.FeedbackDelay-GUI.FeedbackDelayDecr));
        else
            % Increase the feedback if the feedback was successfully
            % completed in the last trial, or use the the GUI value that
            % the user updated if needed.
            % Do we also here consider the case where 'broke_fixation' or
            % 'early_withdrawal' terminated early the trial?
            GUI.FeedbackDelay = min(GUI.FeedbackDelayMax,...
                                    max(GUI.FeedbackDelayMin,...
                                        CurTrial.FeedbackDelay+GUI.FeedbackDelayIncr));
        end
    case FeedbackDelaySelection.TruncExp
        GUI.FeedbackDelay = TruncatedExponential(GUI.FeedbackDelayMin,...
                                                 GUI.FeedbackDelayMax,...
                                                 GUI.FeedbackDelayTau);
    case FeedbackDelaySelection.Fix
        %     ATTEMPT TO GRAY OUT FIELDS
        %     if ~strcmp('edit',GUIMeta.FeedbackDelay.Style)
        %         GUIMeta.FeedbackDelay.Style = 'edit';
        %     end
        GUI.FeedbackDelay = GUI.FeedbackDelayMax;
    otherwise
        assert(false, 'Unexpected FeedbackDelaySelection value');
end
CurTimer.customFeedbackDelay = toc; tic;

%% Drawing future trials

% Calculate bias
% Consider bias only on the last 8 trials/
% indicesRwdLi = find(BpodSystem.Data.Custom.Rewarded,8,'last');
%if length(indicesRwdLi) ~= 0
%	indicesRwd = indicesRwdLi(1);
%else
%	indicesRwd = 1;
%end
LAST_TRIALS=10;
startTrialBiasCalc = iff(iTrial > LAST_TRIALS, iTrial - LAST_TRIALS, 1);
%ndxRewd = BpodSystem.Data.Custom.Trials(indicesRwd:iTrial).Rewarded;
allBiasTrials = [BpodSystem.Data.Custom.Trials(startTrialBiasCalc:iTrial).ChoiceLeft];
choiceBiasTrialsIdxs = find(~isnan(allBiasTrials)) + startTrialBiasCalc - 1;
leftRewarded = sum([...
         BpodSystem.Data.Custom.Trials(choiceBiasTrialsIdxs).LeftRewarded] == 1);
rightRewarded = sum([...
         BpodSystem.Data.Custom.Trials(choiceBiasTrialsIdxs).LeftRewarded] == 0);
leftChoiceBiasTrials = choiceBiasTrialsIdxs([BpodSystem.Data.Custom.Trials(...
                                         choiceBiasTrialsIdxs).ChoiceLeft] == 1);
rightChoiceBiasTrials = setdiff(choiceBiasTrialsIdxs, leftChoiceBiasTrials);
nLeftChoiceCorrect = sum([BpodSystem.Data.Custom.Trials(leftChoiceBiasTrials).ChoiceCorrect] == 1);
nRightChoiceCorrect = sum([BpodSystem.Data.Custom.Trials(rightChoiceBiasTrials).ChoiceCorrect] == 1);
PerfL = nLeftChoiceCorrect/leftRewarded;
PerfR = nRightChoiceCorrect/rightRewarded;
if isnan(PerfL)
    % SInce we don't have trials on this side, then measuere by how good
    % the animals was performing on the other side. If it did bad on the
    % side then then consider this side performance to be good so it'd
    % still get more trials on the other side. Multiply by 2 to dilute its
    % effect.
    denominator = iff(rightRewarded, rightRewarded*2, 1);
    PerfL = 1 - nRightChoiceCorrect/denominator;
end
if isnan(PerfR) % Same as above
    denominator = iff(leftRewarded, leftRewarded*2, 1);
    PerfR = 1 - nLeftChoiceCorrect/denominator;
end
GUI.CalcLeftBias = (PerfL-PerfR)/2 + 0.5;

allTrialsChoices = [BpodSystem.Data.Custom.Trials(1:iTrial).ChoiceCorrect];
choiceMadeTrials = allTrialsChoices(~isnan(allTrialsChoices));
rewardedTrialsCount = sum([BpodSystem.Data.Custom.Trials(1:iTrial).Rewarded] == 1);
lengthChoiceMadeTrials = length(choiceMadeTrials);
if lengthChoiceMadeTrials >= 1
    performance = rewardedTrialsCount/lengthChoiceMadeTrials;
    GUI.Performance = [num2str(performance*100,'%.2f'),'%/',num2str(lengthChoiceMadeTrials), 'T'];
    performance = rewardedTrialsCount/iTrial;
    GUI.AllPerformance = [num2str(performance*100,'%.2f'),'%/',num2str(iTrial),'T'];
    NUM_LAST_TRIALS=20;
    if iTrial > NUM_LAST_TRIALS
        if lengthChoiceMadeTrials > NUM_LAST_TRIALS
            rewardedTrials_ = choiceMadeTrials(...
                lengthChoiceMadeTrials-NUM_LAST_TRIALS + 1 :...
                lengthChoiceMadeTrials);
            performance = sum(rewardedTrials_ == true)/NUM_LAST_TRIALS;
            GUI.Performance = [GUI.Performance,' - ',...
                               num2str(performance*100,'%.2f'), '%/',num2str(NUM_LAST_TRIALS) ,'T'];
        end
        rewardedTrialsCount = sum(...
            [BpodSystem.Data.Custom.Trials(...
                          iTrial-NUM_LAST_TRIALS+1:iTrial).Rewarded] == 1);
        performance = rewardedTrialsCount/NUM_LAST_TRIALS;
        GUI.AllPerformance = [GUI.AllPerformance,' - ',...
                              num2str(performance*100,'%.2f'),'%/',num2str(NUM_LAST_TRIALS), 'T'];
    end
end
CurTimer.customCalcBias = toc; tic;

%create future trials
% Check if its time to generate more future trials
% We need first to assign next trial before processing future trials
BpodSystem.Data.Custom.Trials(iTrial+1) = NextTrial;
if iTrial > BpodSystem.Data.Custom.DVsAlreadyGenerated - Const.PRE_GENERATE_TRIAL_CHECK
    % Do bias correction only if we have enough trials
    if GUI.CorrectBias && iTrial > 7 %sum(ndxRewd) > Const.BIAS_CORRECT_MIN_RWD_TRIALS
        LeftBias = GUI.CalcLeftBias;
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
        LeftBias = GUI.LeftBias;
    end
    CurTimer.customAdjustBias = toc; tic;

    % Adjustment of P(Omega) to make sure that sum(P(Omega))=1
    if ~GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
        if sum(GUI.OmegaTable.OmegaProb) == 0 % Avoid having no probability and avoid dividing by zero
            GUI.OmegaTable.OmegaProb = ones(size(GUI.OmegaTable.OmegaProb));
        end
        GUI.OmegaTable.OmegaProb = GUI.OmegaTable.OmegaProb/sum(GUI.OmegaTable.OmegaProb);
    end
    CurTimer.customCalcOmega = toc; tic;

    % make future trials
    lastidx = BpodSystem.Data.Custom.DVsAlreadyGenerated;
    % Generate guaranteed equal possibility of >0.5 and <0.5
    IsLeftRewarded = [zeros(1, round(Const.PRE_GENERATE_TRIAL_COUNT*LeftBias)) ones(1, round(Const.PRE_GENERATE_TRIAL_COUNT*(1-LeftBias)))];
    % Shuffle array and convert it
    IsLeftRewarded = IsLeftRewarded(randperm(numel(IsLeftRewarded))) > LeftBias;
    CurTimer.customPrepNewTrials = toc; tic;
    for a = 1:Const.PRE_GENERATE_TRIAL_COUNT
        % If it's a fifty-fifty trial, then place stimulus in the middle
        if rand(1,1) < GUI.Percent50Fifty && (lastidx+a) > GUI.StartEasyTrials % 50Fifty trials
            StimulusOmega = 0.5;
        else
            if GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
                % Divide beta by 4 if we are in an easy trial
                BetaDiv = iff((lastidx+a) <= GUI.StartEasyTrials, 4, 1);
                StimulusOmega = betarnd(GUI.BetaDistAlphaNBeta/BetaDiv,GUI.BetaDistAlphaNBeta/BetaDiv,1,1);
                StimulusOmega = iff(StimulusOmega < 0.1, 0.1, StimulusOmega); %prevent extreme values
                StimulusOmega = iff(StimulusOmega > 0.9, 0.9, StimulusOmega); %prevent extreme values
            elseif GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.DiscretePairs
                if (lastidx+a) <= GUI.StartEasyTrials
                    index = find(GUI.OmegaTable.OmegaProb > 0, 1);
                    StimulusOmega = GUI.OmegaTable.Omega(index)/100;
                else
                    % Choose a value randomly given the each value probability
                    StimulusOmega = randsample(GUI.OmegaTable.Omega,1,1,GUI.OmegaTable.OmegaProb)/100;
                end
            else
                assert(false, 'Unexpected StimulusSelectionCriteria');
            end
            % In case of beta distribution, our distribution is symmetric,
            % so prob < 0.5 is == prob > 0.5, so we can just pick the value
            % that corrects the bias
            if (IsLeftRewarded(a) && StimulusOmega < 0.5) || (~IsLeftRewarded(a) && StimulusOmega >= 0.5)
                StimulusOmega = -StimulusOmega + 1;
            end
        end

        BpodSystem.Data.Custom.Trials(lastidx+a).StimulusOmega = StimulusOmega;
        DV = CalcTrialDV(lastidx+a, GUI.ExperimentType, StimulusOmega);
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
    CurTimer.customGenNewTrials = toc;
else
    CurTimer.customAdjustBias = 0;
    CurTimer.customCalcOmega = 0;
    CurTimer.customPrepNewTrials = 0;
    CurTimer.customGenNewTrials = 0;
end%if trial > - 5
NextTrial = BpodSystem.Data.Custom.Trials(iTrial+1);
tic;
% Secondary Experiment DV can be none or another value.
if rand(1,1) < GUI.SecExpUseProb
    NextTrial.SecDV = GenSecExp(GUI.SecExperimentType, GUI.SecExpStimIntensity,...
                                GUI.SecExpStimDir, iTrial+1, GUI.OmegaTable,...
                                NextTrial.StimulusOmega, NextTrial.LeftRewarded);
else
    NextTrial.SecDV = NaN;
end
CurTimer.customSecDV = toc; tic;

% send auditory stimuli to PulsePal for next trial
if GUI.ExperimentType == ExperimentType.Auditory && ~BpodSystem.EmulatorMode
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{iTrial+1}))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}))*5);
end


% Update RDK GUI
GUI.OmegaTable.RDK = (GUI.OmegaTable.Omega - 50)*2;

% Set current stimulus for next trial
GUI.CurrentStim = PerfStr(GUI.ExperimentType, NextTrial.DV,...
                          GUI.SecExperimentType, NextTrial.SecDV);

%%update hidden TaskParameter fields
TaskParameters.Figures.ParameterGUI.Position = BpodSystem.ProtocolFigures.ParameterGUI.Position;
CurTimer.customFinializeUpdate = toc; tic;

%determine if optogentics trial
OptoEnabled = rand(1,1) <  GUI.OptoProb;
if iTrial < GUI.StartEasyTrials
    OptoEnabled = false;
end
NextTrial.OptoEnabled = OptoEnabled;
GUI.IsOptoTrial = iff(OptoEnabled, 'true', 'false');

% determine if catch trial
if iTrial < GUI.StartEasyTrials || GUI.PercentCatch == 0
    NextTrial.CatchTrial = false;
else
    every_n_trials = round(1/GUI.PercentCatch);
    limit = round(every_n_trials*0.2);
    lower_limit = every_n_trials - limit;
    upper_limit = every_n_trials + limit;
    if ~CurTrial.Rewarded ||...
     iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + lower_limit
        NextTrial.CatchTrial = false;
    elseif iTrial + 1 < BpodSystem.Data.Custom.LastSuccessCatchTial + upper_limit
        %TODO: If OmegaProb changed since last time, then redo it
        non_zero_prob = GUI.OmegaTable.Omega(GUI.OmegaTable.OmegaProb > 0);
        non_zero_prob = [1-(non_zero_prob'/100), flip(non_zero_prob'/100)];
        active_stim_idxs = GetCatchStimIdx(non_zero_prob);
        cur_stim_idx = GetCatchStimIdx(NextTrial.StimulusOmega);
        min_catch_counts = min(...
                      BpodSystem.Data.Custom.CatchCount(active_stim_idxs));
        min_catch_idxs = intersect(active_stim_idxs,find(...
            floor(BpodSystem.Data.Custom.CatchCount) == min_catch_counts));
        if any(min_catch_idxs == cur_stim_idx)
            NextTrial.CatchTrial = true;
        else
            NextTrial.CatchTrial = false;
        end
    else
        NextTrial.CatchTrial = true;
    end
end
% Create as char vector rather than string so that GUI sync doesn't complain
GUI.IsCatch = iff(NextTrial.CatchTrial, 'true', 'false');
% Determine if Forced LED trial:
if GUI.PortLEDtoCueReward
    NextTrial.ForcedLEDTrial = rand(1,1) < GUI.PercentForcedLEDTrial;
else
    NextTrial.ForcedLEDTrial = false;
end
CurTimer.customCatchNForceLed = toc; %tic;


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
%CurTimer.customSendPhp = toc;

BpodSystem.Data.Custom.Trials(iTrial) = CurTrial;
BpodSystem.Data.Custom.Trials(iTrial+1) = NextTrial;
BpodSystem.Data.Timer(iTrial) = CurTimer;
TaskParameters.GUI = GUI;
end

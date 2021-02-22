function updateCustomDataFields(iTrial)
% iTrial = The sequential number of the trial that just ran
global BpodSystem
global TaskParameters

function MatStr = str(matrix_state)
    MatStr = MatrixState.String(matrix_state);
end

CurTrial = BpodSystem.Data.Custom.Trials(iTrial);
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
% We need to re-assign the current trial so it would be included in the
% calculations. It ani't pretty, but I can't think of a cleaner solution on
% the spot.
BpodSystem.Data.Custom.Trials(iTrial) = CurTrial;
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

[NextTrialBlockNum, NewLeftBias, NewExpType, NewSecExpType, ...
 BpodSystem.Data.Custom.BlocksInfo, GUI.Block] = CalcBlockInfo(GUI, iTrial,...
                                              BpodSystem.Data.Custom.Trials,...
                                              BpodSystem.Data.Custom.BlocksInfo);

%% Check if we should generate more future trials
if iTrial+1 >= BpodSystem.Data.Custom.DVsAlreadyGenerated || ...
   (~all(isnan([NextTrialBlockNum, CurTrial.BlockNum])) &&...
    NextTrialBlockNum ~= CurTrial.BlockNum)
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
        LeftBias = NewLeftBias;
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

    %CurTimer.customPrepNewTrials = toc; tic;
    [BpodSystem.Data.Custom.Trials,...
     BpodSystem.Data.Custom.DVsAlreadyGenerated] = AssignFutureTrials(...
        BpodSystem.Data.Custom.Trials, GUI, iTrial+1,...
        Const.PRE_GENERATE_TRIAL_COUNT, LeftBias);
    CurTimer.customGenNewTrials = toc;
else
    CurTimer.customAdjustBias = 0;
    CurTimer.customCalcOmega = 0;
    CurTimer.customPrepNewTrials = 0;
    CurTimer.customGenNewTrials = 0;
end%if trial > - 5

NextTrial = BpodSystem.Data.Custom.Trials(iTrial+1);
[NextTrial, GUI, CurTimer] = GenNextTrial(NextTrial, iTrial+1, GUI,...
                                NewExpType, NewSecExpType, CurTimer,...
                                BpodSystem.Data.Custom.LastSuccessCatchTial,...
                                BpodSystem.Data.Custom.CatchCount,...
                                CurTrial.Rewarded, NextTrialBlockNum);
tic;
% send auditory stimuli to PulsePal for next trial
if GUI.ExperimentType == ExperimentType.Auditory && ~BpodSystem.EmulatorMode
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{iTrial+1}))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{iTrial+1}))*5);
end

%%update hidden TaskParameter fields
TaskParameters.Figures.ParameterGUI.Position = BpodSystem.ProtocolFigures.ParameterGUI.Position;
CurTimer.customFinializeUpdate = toc;

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

% The CurTrial assignment here is not necessary as it was already assigned
% above, but we do it just as precaution against future changes.
BpodSystem.Data.Custom.Trials(iTrial) = CurTrial;
BpodSystem.Data.Custom.Trials(iTrial+1) = NextTrial;
BpodSystem.Data.Timer(iTrial) = CurTimer;
TaskParameters.GUI = GUI;
end

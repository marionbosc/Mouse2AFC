function sma = stateMatrix(iTrial)
global BpodSystem
global TaskParameters

%% Define ports
LeftPort = floor(mod(TaskParameters.GUI.Ports_LMR/100,10));
CenterPort = floor(mod(TaskParameters.GUI.Ports_LMR/10,10));
RightPort = mod(TaskParameters.GUI.Ports_LMR,10);
LeftPortOut = strcat('Port',num2str(LeftPort),'Out');
CenterPortOut = strcat('Port',num2str(CenterPort),'Out');
RightPortOut = strcat('Port',num2str(RightPort),'Out');
LeftPortIn = strcat('Port',num2str(LeftPort),'In');
CenterPortIn = strcat('Port',num2str(CenterPort),'In');
RightPortIn = strcat('Port',num2str(RightPort),'In');

LeftValve = 2^(LeftPort-1);
CenterValve = 2^(CenterPort-1);
RightValve = 2^(RightPort-1);

LeftValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,1), LeftPort);
CenterValveTime  = GetValveTimes(BpodSystem.Data.Custom.CenterPortRewAmount(iTrial), LeftPort);
RightValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,2), RightPort);

if BpodSystem.Data.Custom.AuditoryTrial(iTrial) %auditory trial
    LeftRewarded = BpodSystem.Data.Custom.LeftRewarded(iTrial);
end

% Trial type (left = correct or right = correct)
if LeftRewarded == 1
    RewardedPort = LeftPort;
    LeftActionState = 'WaitForRewardStart';
    RightActionState = 'WaitForPunishStart';
    RewardIn = LeftPortIn;
    RewardOut = LeftPortOut;
    PunishIn = RightPortIn;
    PunishOut = RightPortOut;
    ValveTime = LeftValveTime;
    ValveCode = LeftValve;
elseif LeftRewarded == 0
    RewardedPort = RightPort;
    LeftActionState = 'WaitForPunishStart';
    RightActionState = 'WaitForRewardStart';
    RewardIn = RightPortIn;
    RewardOut = RightPortOut;
    PunishIn = LeftPortIn;
    PunishOut = LeftPortOut;
    ValveTime = RightValveTime;
    ValveCode = RightValve;
else
    error('Bpod:Olf2AFC:unknownStim','Undefined stimulus');
end

% GUI option RewardAfterMinSampling
if TaskParameters.GUI.RewardAfterMinSampling
    RewardCenterPort = {'ValveState',CenterValve,'BNCState',0};
    Timer_CPRD = CenterValveTime;
else
    RewardCenterPort = {'BNCState',1};
    Timer_CPRD = TaskParameters.GUI.AuditoryStimulusTime - TaskParameters.GUI.MinSampleAud;
end

% White Noise played as Error Feedback 
if TaskParameters.GUI.PlayNoiseforError
    ErrorFeedback = {'SoftCode',11};
else
    ErrorFeedback = {};
end

% CatchTrial
if BpodSystem.Data.Custom.CatchTrial(iTrial)
    FeedbackDelayCorrect = 20;
else
    FeedbackDelayCorrect = TaskParameters.GUI.FeedbackDelay;
end

% GUI option CatchError
if TaskParameters.GUI.CatchError
    FeedbackDelayError = 20;
    SkippedFeedbackSignal = {};
else
    FeedbackDelayError = TaskParameters.GUI.FeedbackDelay;
    SkippedFeedbackSignal = ErrorFeedback;
end

% Incorrect Choice signal
if TaskParameters.GUI.IncorrectChoiceSignalType == 2 % Noise
    PunishmentDuration = 0.01;
    IncorrectChoice_Signal = {'SoftCode', 11};
elseif TaskParameters.GUI.IncorrectChoiceSignalType == 3 % LED Flash
    PunishmentDuration = 0.1;
    IncorrectChoice_Signal = {strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(CenterPort)),255,strcat('PWM',num2str(RightPort)),255};
else % no signal
    PunishmentDuration = 0.01;
    IncorrectChoice_Signal = {};
end

% ITI signal
if TaskParameters.GUI.ITISignalType == 2 % Beep
    ITI_Signal_Duration = 0.01;
    ITI_Signal = {'SoftCode', 12};
elseif TaskParameters.GUI.ITISignalType == 3 % LED Flash
    ITI_Signal_Duration = 0.1;
    ITI_Signal = {strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(CenterPort)),255,strcat('PWM',num2str(RightPort)),255};
    ITI_Signal_Duration = 0.01;
    ITI_Signal = {};
end

%Wire1 settings
if TaskParameters.GUI.Wire1VideoTrigger
    Wire1OutError =	{'WireState', 1};
    if BpodSystem.Data.Custom.CatchTrial(iTrial)
    	Wire1OutCorrect =	{'WireState', 1};
    else
        Wire1OutCorrect =	{};
    end
else
    Wire1OutError = {};
    Wire1OutCorrect =	{};
end

% LED on the side lateral port to cue the rewarded side at the beginning of
% the training on auditory discrimination:
if BpodSystem.Data.Custom.ForcedLEDTrial(iTrial)
    LEDActivation = {strcat('PWM',num2str(RewardedPort)),255};
else
    LEDActivation = {strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(RightPort)),255};
end

%% Build state matrix
sma = NewStateMatrix();
sma = SetGlobalTimer(sma,1,FeedbackDelayCorrect);
sma = SetGlobalTimer(sma,2,FeedbackDelayError);
sma = AddState(sma, 'Name', 'WaitForCenterPoke',...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortIn, 'WaitForStimulus'},...
    'OutputActions', {strcat('PWM',num2str(CenterPort)),255});
sma = AddState(sma, 'Name', 'broke_fixation',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','timeOut_BrokeFixation'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'WaitForStimulus',...
    'Timer', TaskParameters.GUI.StimDelay,...
    'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup', 'stimulus_delivery'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'stimulus_delivery',...
    'Timer', TaskParameters.GUI.MinSampleAud,...
    'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','CenterPortRewardDelivery'},...
    'OutputActions', {'BNCState',1});
sma = AddState(sma, 'Name', 'early_withdrawal',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
    'OutputActions',{'BNCState',0});
sma = AddState(sma, 'Name', 'CenterPortRewardDelivery',...
    'Timer', Timer_CPRD,...
    'StateChangeConditions', {CenterPortOut,'WaitForChoice','Tup','WaitForChoice'},...
    'OutputActions', RewardCenterPort);
sma = AddState(sma, 'Name', 'WaitForChoice',...
    'Timer',TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {LeftPortIn,LeftActionState,RightPortIn,RightActionState,'Tup','timeOut_missed_choice'},...
    'OutputActions',[{'BNCState',0} LEDActivation]);
sma = AddState(sma, 'Name','WaitForRewardStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForReward'},...
    'OutputActions', [Wire1OutCorrect {'GlobalTimerTrig',1}]);
sma = AddState(sma, 'Name','WaitForReward',...
    'Timer',FeedbackDelayCorrect,...
    'StateChangeConditions', {'Tup','Reward','GlobalTimer1_End','Reward',RewardOut, 'RewardGrace' },...
    'OutputActions',{});
sma = AddState(sma, 'Name','RewardGrace',...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {RewardIn,'WaitForReward','Tup','timeOut_SkippedFeedback','GlobalTimer1_End' ,'timeOut_SkippedFeedback', CenterPortIn,'timeOut_SkippedFeedback', PunishIn,'timeOut_SkippedFeedback'},...
    'OutputActions',{});
sma = AddState(sma, 'Name','Reward',...
    'Timer',ValveTime,...
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions',{'ValveState', ValveCode});
sma = AddState(sma, 'Name','WaitForPunishStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForPunish'},...
    'OutputActions',[Wire1OutError {'GlobalTimerTrig',2}]);
sma = AddState(sma, 'Name','WaitForPunish',...
    'Timer',FeedbackDelayError,...
    'StateChangeConditions', {'Tup','Punishment','GlobalTimer2_End','Punishment',PunishOut, 'PunishGrace' },...
    'OutputActions',{});
sma = AddState(sma, 'Name','PunishGrace',...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {PunishIn,'WaitForPunish','Tup','timeOut_SkippedFeedback','GlobalTimer2_End' ,'timeOut_SkippedFeedback', CenterPortIn,'timeOut_SkippedFeedback', RewardIn,'timeOut_SkippedFeedback'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'Punishment',...
    'Timer',PunishmentDuration,...
    'StateChangeConditions',{'Tup','timeOut_IncorrectChoice'},...
    'OutputActions',IncorrectChoice_Signal);
sma = AddState(sma, 'Name', 'timeOut_BrokeFixation',...
    'Timer',TaskParameters.GUI.TimeOutBrokeFixation,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'timeOut_EarlyWithdrawal',...
    'Timer',TaskParameters.GUI.TimeOutEarlyWithdrawal,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice',...
    'Timer',TaskParameters.GUI.TimeOutIncorrectChoice,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback',...
    'Timer',TaskParameters.GUI.TimeOutSkippedFeedback,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',SkippedFeedbackSignal);
sma = AddState(sma, 'Name', 'timeOut_missed_choice',...
    'Timer',TaskParameters.GUI.TimeOutMissedChoice,...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'ITI',...
    'Timer',TaskParameters.GUI.ITI,...
    'StateChangeConditions',{'Tup','ITI_Signal'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'ITI_Signal',...
    'Timer',ITI_Signal_Duration,...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions',ITI_Signal);
% sma = AddState(sma, 'Name', 'state_name',...
%     'Timer', 0,...
%     'StateChangeConditions', {},...
%     'OutputActions', {});
end

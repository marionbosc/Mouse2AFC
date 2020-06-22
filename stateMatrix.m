function sma = stateMatrix(iTrial)
global BpodSystem
global TaskParameters

%% Define ports
LeftPort = floor(mod(TaskParameters.GUI.Ports_LMRAir/1000,10));
CenterPort = floor(mod(TaskParameters.GUI.Ports_LMRAir/100,10));
RightPort = floor(mod(TaskParameters.GUI.Ports_LMRAir/10,10));
AirSolenoid = mod(TaskParameters.GUI.Ports_LMRAir,10);
LeftPortOut = strcat('Port',num2str(LeftPort),'Out');
CenterPortOut = strcat('Port',num2str(CenterPort),'Out');
RightPortOut = strcat('Port',num2str(RightPort),'Out');
LeftPortIn = strcat('Port',num2str(LeftPort),'In');
CenterPortIn = strcat('Port',num2str(CenterPort),'In');
RightPortIn = strcat('Port',num2str(RightPort),'In');

% Duration of the TTL signal to denote start and end of trial for 2P
WireTTLDuration=0.02;

% PWM = (255 * (100-Attenuation))/100
LeftPWM = round((100-TaskParameters.GUI.LeftPokeAttenPrcnt) * 2.55);
CenterPWM = round((100-TaskParameters.GUI.CenterPokeAttenPrcnt) * 2.55);
RightPWM = round((100-TaskParameters.GUI.RightPokeAttenPrcnt) * 2.55);
LEDErrorRate = 0.1;

IsLeftRewarded = BpodSystem.Data.Custom.LeftRewarded(iTrial);

if TaskParameters.GUI.ExperimentType == ExperimentType.Auditory
    DeliverStimulus =  {'BNCState',1};
    ContDeliverStimulus = {};
    StopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {}, {'BNCState',0});
    ChoiceStopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {'BNCState',0}, {});
    EWDStopStimulus = {'BNCState',0};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.LightIntensity
    % Divide Intensity by 100 to get fraction value
    LeftPWMStim = round(BpodSystem.Data.Custom.LightIntensityLeft(iTrial)*LeftPWM/100);
    RightPWMStim = round(BpodSystem.Data.Custom.LightIntensityRight(iTrial)*RightPWM/100);
    DeliverStimulus = {strcat('PWM',num2str(LeftPort)),LeftPWMStim,...
                       strcat('PWM',num2str(RightPort)),RightPWMStim};
    ContDeliverStimulus = DeliverStimulus;
    StopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, DeliverStimulus, {});
    ChoiceStopStimulus = {};
    EWDStopStimulus = {};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.GratingOrientation
    rightPortAngle = VisualStimAngle.getDegrees(TaskParameters.GUI.VisualStimAnglePortRight);
    leftPortAngle = VisualStimAngle.getDegrees(TaskParameters.GUI.VisualStimAnglePortLeft);
    % Calculate the distance between right and left port angle to determine
    % whether we should use the circle arc between the two values in the
    % clock-wise or counter-clock-wise direction to calculate the different
    % difficulties.
    ccw = iff(mod(rightPortAngle-leftPortAngle,360) < mod(leftPortAngle-rightPortAngle,360), true, false);
    if ccw
        finalDV = BpodSystem.Data.Custom.DV(iTrial);
        if rightPortAngle < leftPortAngle
            rightPortAngle = rightPortAngle + 360;
        end
        angleDiff = rightPortAngle - leftPortAngle;
        minAngle = leftPortAngle;
    else
        finalDV = -BpodSystem.Data.Custom.DV(iTrial);
        if leftPortAngle < rightPortAngle
            leftPortAngle = leftPortAngle + 360;
        end
        angleDiff = leftPortAngle - rightPortAngle;
        minAngle = rightPortAngle;
    end
    % orientation = ((DVMax - DV)*(DVMAX-DVMin)*(MaxAngle - MinANgle)) + MinAngle
    gratingOrientation = ((1 - finalDV)*angleDiff/2) + minAngle;
    gratingOrientation = mod(gratingOrientation, 360);
    BpodSystem.Data.Custom.drawParams.stimType = DrawStimType.StaticGratings;
    BpodSystem.Data.Custom.drawParams.gratingOrientation = gratingOrientation;
    BpodSystem.Data.Custom.drawParams.numCycles = TaskParameters.GUI.numCycles;
    BpodSystem.Data.Custom.drawParams.cyclesPerSecondDrift = TaskParameters.GUI.cyclesPerSecondDrift;
    BpodSystem.Data.Custom.drawParams.phase = TaskParameters.GUI.phase;
    BpodSystem.Data.Custom.drawParams.gaborSizeFactor = TaskParameters.GUI.gaborSizeFactor;
    BpodSystem.Data.Custom.drawParams.gaussianFilterRatio = TaskParameters.GUI.gaussianFilterRatio;
    % Start from the 5th byte
    serializeAndWrite(BpodSystem.Data.dotsMapped_file, 5, BpodSystem.Data.Custom.drawParams);
    BpodSystem.Data.dotsMapped_file.Data(1:4) = typecast(uint32(1), 'uint8');

    DeliverStimulus = {'SoftCode',5};
    ContDeliverStimulus = {};
    StopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {}, {'SoftCode',6});
    ChoiceStopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {'SoftCode',6}, {});
    EWDStopStimulus = {'SoftCode',6};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.RandomDots
    % Setup the parameters
    % Use 20% of the screen size. Assume apertureSize is the diameter
    TaskParameters.GUI.circleArea = ...
                        (pi*((TaskParameters.GUI.apertureSizeWidth/2).^2));
    TaskParameters.GUI.nDots = ...
       round(TaskParameters.GUI.circleArea * TaskParameters.GUI.drawRatio);

    BpodSystem.Data.Custom.drawParams.stimType = DrawStimType.RDK;
    BpodSystem.Data.Custom.drawParams.centerX = TaskParameters.GUI.centerX;
    BpodSystem.Data.Custom.drawParams.centerY = TaskParameters.GUI.centerY;
    BpodSystem.Data.Custom.drawParams.apertureSizeWidth = TaskParameters.GUI.apertureSizeWidth;
    BpodSystem.Data.Custom.drawParams.apertureSizeHeight = TaskParameters.GUI.apertureSizeHeight;
    BpodSystem.Data.Custom.drawParams.drawRatio = TaskParameters.GUI.drawRatio;
    BpodSystem.Data.Custom.drawParams.mainDirection = floor(VisualStimAngle.getDegrees(...
        iff(IsLeftRewarded,TaskParameters.GUI.VisualStimAnglePortLeft,...
                           TaskParameters.GUI.VisualStimAnglePortRight)));
    BpodSystem.Data.Custom.drawParams.dotSpeed = TaskParameters.GUI.dotSpeedDegsPerSec;
    BpodSystem.Data.Custom.drawParams.dotLifetimeSecs = TaskParameters.GUI.dotLifetimeSecs;
    BpodSystem.Data.Custom.drawParams.coherence = BpodSystem.Data.Custom.DotsCoherence(iTrial);
    BpodSystem.Data.Custom.drawParams.screenWidthCm = TaskParameters.GUI.screenWidthCm;
    BpodSystem.Data.Custom.drawParams.screenDistCm = TaskParameters.GUI.screenDistCm;
    BpodSystem.Data.Custom.drawParams.dotSizeInDegs = TaskParameters.GUI.dotSizeInDegs;

    % Start from the 5th byte
    serializeAndWrite(BpodSystem.Data.dotsMapped_file, 5, BpodSystem.Data.Custom.drawParams);
    BpodSystem.Data.dotsMapped_file.Data(1:4) = typecast(uint32(1), 'uint8');

    DeliverStimulus = {'SoftCode',5};
    ContDeliverStimulus = {};
    StopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {}, {'SoftCode',6});
    ChoiceStopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {'SoftCode',6}, {});
    EWDStopStimulus = {'SoftCode',6};
else
    assert(false, 'Unexpected ExperimentType');
end

% Valve opening is a bitmap. Open each valve separately by raising 2 to
% the power of port number - 1
LeftValve = 2^(LeftPort-1);
CenterValve = 2^(CenterPort-1);
RightValve = 2^(RightPort-1);
AirSolenoidOn = 2^(AirSolenoid-1);
AirSolenoidOff = 0;

LeftValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,1), LeftPort);
CenterValveTime  = GetValveTimes(BpodSystem.Data.Custom.CenterPortRewAmount(iTrial), CenterPort);
RightValveTime  = GetValveTimes(BpodSystem.Data.Custom.RewardMagnitude(iTrial,2), RightPort);

% iff() function takes first parameter as first condition, if the condition
% is true then it returns the 2nd parameter, else it returns the 3rd one
RewardedPort = iff(IsLeftRewarded, LeftPort, RightPort);
RewardedPortPWM = iff(IsLeftRewarded, LeftPWM, RightPWM);
IncorrectConsequence = iff(~TaskParameters.GUI.HabituateIgnoreIncorrect,...
                           'WaitForPunishStart', 'RegisterWrongWaitCorrect');
LeftActionState = iff(IsLeftRewarded, 'WaitForRewardStart', IncorrectConsequence);
RightActionState = iff(IsLeftRewarded, IncorrectConsequence, 'WaitForRewardStart');
RewardIn = iff(IsLeftRewarded, LeftPortIn, RightPortIn);
RewardOut = iff(IsLeftRewarded, LeftPortOut, RightPortOut);
PunishIn = iff(IsLeftRewarded, RightPortIn, LeftPortIn);
PunishOut = iff(IsLeftRewarded, RightPortOut, LeftPortOut);
ValveTime = iff(IsLeftRewarded, LeftValveTime, RightValveTime);
ValveCode = iff(IsLeftRewarded, LeftValve, RightValve);

ValveOrWireSolenoid='ValveState';
if TaskParameters.GUI.CutAirStimDelay && TaskParameters.GUI.CutAirSampling
    AirFlowStimDelayOff = {ValveOrWireSolenoid, AirSolenoidOn};
    AirFlowStimDelayOn = {};
    AirFlowSamplingOff = {ValveOrWireSolenoid, AirSolenoidOn}; % Must set it on again
    AirFlowSamplingOn = {ValveOrWireSolenoid, AirSolenoidOff};
elseif TaskParameters.GUI.CutAirStimDelay
    AirFlowStimDelayOff = {ValveOrWireSolenoid, AirSolenoidOn};
    AirFlowStimDelayOn = {ValveOrWireSolenoid, AirSolenoidOff};
    AirFlowSamplingOff = {};
    AirFlowSamplingOn = {};
elseif TaskParameters.GUI.CutAirSampling
    AirFlowStimDelayOff = {};
    AirFlowStimDelayOn = {};
    AirFlowSamplingOff = {ValveOrWireSolenoid, AirSolenoidOn};
    AirFlowSamplingOn = {ValveOrWireSolenoid, AirSolenoidOff};
else
    AirFlowStimDelayOff = {};
    AirFlowStimDelayOn = {};
    AirFlowSamplingOff = {};
    AirFlowSamplingOn = {};
end

if TaskParameters.GUI.CutAirReward
    AirFlowRewardOff = {'ValveState', AirSolenoidOn};
else
    AirFlowRewardOff = {};
end
AirFlowRewardOn = {'ValveState', AirSolenoidOff};

% Check if to play beep at end of minimum sampling
MinSampleBeep = iff(TaskParameters.GUI.BeepAfterMinSampling, {'SoftCode',12}, {});
MinSampleBeepDuration = iff(TaskParameters.GUI.BeepAfterMinSampling, 0.01, 0);
% GUI option RewardAfterMinSampling
% If center-reward is enabled, then a reward is given once MinSample
% is over and no further sampling is given.
RewardCenterPort = iff(TaskParameters.GUI.RewardAfterMinSampling, [{'ValveState',CenterValve} ,StopStimulus], ContDeliverStimulus);
Timer_CPRD = iff(TaskParameters.GUI.RewardAfterMinSampling, CenterValveTime, TaskParameters.GUI.StimulusTime - TaskParameters.GUI.MinSample);
% Optogentics on BNC 2
Opto_stimulus_delivery = iff(BpodSystem.Data.Custom.OptoEnabled_stimulus_delivery(iTrial), {'BNCState',2}, {});

% White Noise played as Error Feedback
ErrorFeedback = iff(TaskParameters.GUI.PlayNoiseforError, {'SoftCode',11}, {});

% CatchTrial
FeedbackDelayCorrect = iff(BpodSystem.Data.Custom.CatchTrial(iTrial), Const.FEEDBACK_CATCH_CORRECT_SEC, TaskParameters.GUI.FeedbackDelay);

% GUI option CatchError
FeedbackDelayError = iff(TaskParameters.GUI.CatchError, Const.FEEDBACK_CATCH_INCORRECT_SEC, TaskParameters.GUI.FeedbackDelay);
SkippedFeedbackSignal = iff(TaskParameters.GUI.CatchError, {}, ErrorFeedback);

% Incorrect Choice signal
if TaskParameters.GUI.IncorrectChoiceSignalType == IncorrectChoiceSignalType.NoisePulsePal
    PunishmentDuration = 0.01;
    IncorrectChoice_Signal = {'SoftCode', 11};
elseif TaskParameters.GUI.IncorrectChoiceSignalType == IncorrectChoiceSignalType.BeepOnWire_1
    PunishmentDuration = 0.25;
    IncorrectChoice_Signal = {'WireState', 2^0};
elseif TaskParameters.GUI.IncorrectChoiceSignalType == IncorrectChoiceSignalType.PortLED
    PunishmentDuration = 0.1;
    IncorrectChoice_Signal = {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(CenterPort)),CenterPWM,strcat('PWM',num2str(RightPort)),RightPWM};
elseif TaskParameters.GUI.IncorrectChoiceSignalType == IncorrectChoiceSignalType.None
    PunishmentDuration = 0.01;
    IncorrectChoice_Signal = {};
else
    assert(false, 'Unexpected IncorrectChoiceSignalType value');
end

% ITI signal
if TaskParameters.GUI.ITISignalType == ITISignalType.Beep
    ITI_Signal_Duration = 0.01;
    ITI_Signal = {'SoftCode', 12};
elseif TaskParameters.GUI.ITISignalType == ITISignalType.PortLED
    ITI_Signal_Duration = 0.1;
    ITI_Signal = {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(CenterPort)),CenterPWM,strcat('PWM',num2str(RightPort)),RightPWM};
elseif TaskParameters.GUI.ITISignalType == ITISignalType.None
    ITI_Signal_Duration = 0.01;
    ITI_Signal = {};
else
    assert(false, 'Unexpected ITISignalType value');
end

%Wire1 settings
Wire1OutError = iff(TaskParameters.GUI.Wire1VideoTrigger, {'WireState', 2^1}, {});
Wire1OutCorrect = iff(TaskParameters.GUI.Wire1VideoTrigger && BpodSystem.Data.Custom.CatchTrial(iTrial), {'WireState', 2^1}, {});

% LED on the side lateral port to cue the rewarded side at the beginning of
% the training. On auditory discrimination task, both lateral ports are
% illuminated after end of stimulus delivery.
if BpodSystem.Data.Custom.ForcedLEDTrial(iTrial)
    ExtendedStimulus = {strcat('PWM',num2str(RewardedPort)),RewardedPortPWM};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.Auditory
    ExtendedStimulus = {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(RightPort)),RightPWM};
else
    ExtendedStimulus = {};
end

% Softcode handler for iTrial == 1 in HomeCage to close training chamber door
CloseChamber = iff(iTrial == 1 && BpodSystem.Data.Custom.IsHomeCage, {'SoftCode', 30}, {});

PCTimeout=TaskParameters.GUI.PCTimeout;
%% Build state matrix
sma = NewStateMatrix();
sma = SetGlobalTimer(sma,1,FeedbackDelayCorrect);
sma = SetGlobalTimer(sma,2,FeedbackDelayError);
sma = SetGlobalTimer(sma,3,iff(TaskParameters.GUI.TimeOutEarlyWithdrawal, TaskParameters.GUI.TimeOutEarlyWithdrawal, 0.01));
sma = SetGlobalTimer(sma,4,TaskParameters.GUI.ChoiceDeadLine);
sma = AddState(sma, 'Name', 'ITI_Signal',...
    'Timer',ITI_Signal_Duration,...
    'StateChangeConditions',{'Tup','WaitForCenterPoke'},...
    'OutputActions',ITI_Signal);
sma = AddState(sma, 'Name', 'WaitForCenterPoke',...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortIn, 'PreStimReward'},...
    'OutputActions', {strcat('PWM',num2str(CenterPort)),CenterPWM});
sma = AddState(sma, 'Name', 'PreStimReward',...
    'Timer', iff(TaskParameters.GUI.PreStimuDelayCntrReward,...
                 GetValveTimes(TaskParameters.GUI.PreStimuDelayCntrReward, CenterPort),0.01),...
    'StateChangeConditions', {'Tup', 'TriggerWaitForStimulus'},...
    'OutputActions', iff(TaskParameters.GUI.PreStimuDelayCntrReward,{'ValveState',CenterValve},[]));
sma = AddState(sma, 'Name', 'TriggerWaitForStimulus',...
    'Timer', WireTTLDuration,...
    'StateChangeConditions', {CenterPortOut,'StimDelayGrace','Tup','WaitForStimulus'},...
    'OutputActions', [{'WireState', 2^2} CloseChamber AirFlowStimDelayOff]);
sma = AddState(sma, 'Name', 'WaitForStimulus',...
    'Timer', max(0, TaskParameters.GUI.StimDelay - WireTTLDuration),...
    'StateChangeConditions', {CenterPortOut,'StimDelayGrace','Tup', 'stimulus_delivery'},...
    'OutputActions', AirFlowStimDelayOff);
sma = AddState(sma, 'Name', 'StimDelayGrace',...
    'Timer',TaskParameters.GUI.StimDelayGrace,...
    'StateChangeConditions',{'Tup','broke_fixation',CenterPortIn,'TriggerWaitForStimulus'},...
    'OutputActions',[AirFlowStimDelayOff]);
sma = AddState(sma, 'Name', 'broke_fixation',...
    'Timer',iff(~PCTimeout, TaskParameters.GUI.TimeOutBrokeFixation, 0.01),...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',[ErrorFeedback]);
sma = AddState(sma, 'Name', 'stimulus_delivery',...
    'Timer', TaskParameters.GUI.MinSample,...
    'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','BeepMinSampling'},...
    'OutputActions', [DeliverStimulus AirFlowSamplingOff Opto_stimulus_delivery]);
sma = AddState(sma, 'Name', 'early_withdrawal',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
    'OutputActions', [EWDStopStimulus AirFlowSamplingOn, {'GlobalTimerTrig',3}]);
sma = AddState(sma, 'Name', 'BeepMinSampling',...
    'Timer', MinSampleBeepDuration,...
    'StateChangeConditions', {CenterPortOut,'TriggerWaitChoiceTimer','Tup','CenterPortRewardDelivery'},...
    'OutputActions', [ContDeliverStimulus MinSampleBeep]);
sma = AddState(sma, 'Name', 'CenterPortRewardDelivery',...
    'Timer', Timer_CPRD,...
    'StateChangeConditions', {CenterPortOut,'TriggerWaitChoiceTimer','Tup','WaitCenterPortOut'},...
    'OutputActions', RewardCenterPort);
% TODO: Stop stimulus is fired twice in case of center reward and then wait
% for choice. Fix it such that it'll be always fired once.
sma = AddState(sma, 'Name', 'TriggerWaitChoiceTimer',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForChoice'},...
    'OutputActions',[StopStimulus ExtendedStimulus {'GlobalTimerTrig',4}]);
sma = AddState(sma, 'Name', 'WaitCenterPortOut',...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortOut,'WaitForChoice',...
                              LeftPortIn,LeftActionState,...
                              RightPortIn,RightActionState,...
                              'GlobalTimer4_End','timeOut_missed_choice'},...
    'OutputActions', [StopStimulus ExtendedStimulus {'GlobalTimerTrig',4}]);
sma = AddState(sma, 'Name', 'WaitForChoice',...
    'Timer',0,...
    'StateChangeConditions', {LeftPortIn,LeftActionState,RightPortIn,RightActionState,'GlobalTimer4_End','timeOut_missed_choice'},...
    'OutputActions',[StopStimulus ExtendedStimulus]);
sma = AddState(sma, 'Name','WaitForRewardStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForReward'},...
    'OutputActions', [Wire1OutCorrect ChoiceStopStimulus {'GlobalTimerTrig',1}]);
sma = AddState(sma, 'Name','WaitForReward',...
    'Timer',FeedbackDelayCorrect,...
    'StateChangeConditions', {'Tup','Reward','GlobalTimer1_End','Reward',RewardOut, 'RewardGrace' },...
    'OutputActions', AirFlowRewardOff);
sma = AddState(sma, 'Name','RewardGrace',...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {RewardIn,'WaitForReward','Tup','timeOut_SkippedFeedback','GlobalTimer1_End' ,'timeOut_SkippedFeedback', CenterPortIn,'timeOut_SkippedFeedback', PunishIn,'timeOut_SkippedFeedback'},...
    'OutputActions', AirFlowRewardOn);
sma = AddState(sma, 'Name','Reward',...
    'Timer',ValveTime,...
    'StateChangeConditions', {'Tup','WaitRewardOut'},...
    'OutputActions', {'ValveState', ValveCode});
sma = AddState(sma, 'Name','WaitRewardOut',...
    'Timer',1.0,...
    'StateChangeConditions', {'Tup','ITI',RewardOut,'ITI'},...
    'OutputActions', {});
sma = AddState(sma, 'Name','RegisterWrongWaitCorrect',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForChoice'},...
    'OutputActions',[]);
sma = AddState(sma, 'Name','WaitForPunishStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForPunish'},...
    'OutputActions',[Wire1OutError ChoiceStopStimulus {'GlobalTimerTrig',2}]);
sma = AddState(sma, 'Name','WaitForPunish',...
    'Timer',FeedbackDelayError,...
    'StateChangeConditions', {'Tup','Punishment','GlobalTimer2_End','Punishment',PunishOut, 'PunishGrace' },...
    'OutputActions', AirFlowRewardOff);
sma = AddState(sma, 'Name','PunishGrace',...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {PunishIn,'WaitForPunish','Tup','timeOut_SkippedFeedback','GlobalTimer2_End' ,'timeOut_SkippedFeedback', CenterPortIn,'timeOut_SkippedFeedback', RewardIn,'timeOut_SkippedFeedback'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'Punishment',...
    'Timer',PunishmentDuration,...
    'StateChangeConditions',{'Tup','timeOut_IncorrectChoice'},...
    'OutputActions',[IncorrectChoice_Signal AirFlowRewardOn]);
sma = AddState(sma, 'Name', 'timeOut_EarlyWithdrawal',...
    'Timer',LEDErrorRate,...
    'StateChangeConditions',{'GlobalTimer3_End','ITI','Tup','timeOut_EarlyWithdrawalFlashOn'},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'timeOut_EarlyWithdrawalFlashOn',...
    'Timer',LEDErrorRate,...
    'StateChangeConditions',{'GlobalTimer3_End','ITI','Tup','timeOut_EarlyWithdrawal'},...
    'OutputActions',[ErrorFeedback, {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(RightPort)),RightPWM}]);
sma = AddState(sma, 'Name', 'timeOut_IncorrectChoice',...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutIncorrectChoice,0.01),...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',{});
sma = AddState(sma, 'Name', 'timeOut_SkippedFeedback',...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutSkippedFeedback,0.01),...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',SkippedFeedbackSignal); % TODO: See how to get around this if PCTimeout
sma = AddState(sma, 'Name', 'timeOut_missed_choice',...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutMissedChoice,0.01),...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',[ErrorFeedback ChoiceStopStimulus]);
sma = AddState(sma, 'Name', 'ITI',...
    'Timer',WireTTLDuration,...
    'StateChangeConditions',{'Tup','ext_ITI'},...
    'OutputActions', [{'WireState', 2^3} AirFlowRewardOn]);
sma = AddState(sma, 'Name', 'ext_ITI',...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.ITI,0.01),...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions', AirFlowRewardOn);
% sma = AddState(sma, 'Name', 'state_name',...
%     'Timer', 0,...
%     'StateChangeConditions', {},...
%     'OutputActions', {});
end

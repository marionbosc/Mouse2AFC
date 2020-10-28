function sma = stateMatrix(iTrial)
global BpodSystem
global TaskParameters

function MatStr = str(matrix_state)
    MatStr = MatrixState.String(matrix_state);
end
function enc_trigger = EncTrig(trigger_id)
    % Provides V1 & V2 compitability
    % The Bpod2 emulator requires some strange formatting compared to the
    % actual real board running.
    enc_trigger = ...
        iff(BpodSystem.SystemSettings.IsVer2 && BpodSystem.EmulatorMode,...
            dec2bin(trigger_id, 3), trigger_id);
end

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

IsLeftRewarded = BpodSystem.Data.Custom.Trials(iTrial).LeftRewarded;

if TaskParameters.GUI.ExperimentType == ExperimentType.Auditory
    DeliverStimulus =  {'BNCState',1};
    ContDeliverStimulus = {};
    StopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {}, {'BNCState',0});
    ChoiceStopStimulus = iff(TaskParameters.GUI.StimAfterPokeOut, {'BNCState',0}, {});
    EWDStopStimulus = {'BNCState',0};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.LightIntensity
    % Divide Intensity by 100 to get fraction value
    LeftPWMStim = round(BpodSystem.Data.Custom.Trials(iTrial).LightIntensityLeft*LeftPWM/100);
    RightPWMStim = round(BpodSystem.Data.Custom.Trials(iTrial).LightIntensityRight*RightPWM/100);
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
        finalDV = BpodSystem.Data.Custom.Trials(iTrial).DV;
        if rightPortAngle < leftPortAngle
            rightPortAngle = rightPortAngle + 360;
        end
        angleDiff = rightPortAngle - leftPortAngle;
        minAngle = leftPortAngle;
    else
        finalDV = -BpodSystem.Data.Custom.Trials(iTrial).DV;
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
    serializeAndWrite(BpodSystem.SystemSettings.dotsMapped_file, 5,...
                      BpodSystem.Data.Custom.drawParams);
    BpodSystem.SystemSettings.dotsMapped_file.Data(1:4) =...
                                                    typecast(uint32(1), 'uint8');

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
    BpodSystem.Data.Custom.drawParams.coherence = BpodSystem.Data.Custom.Trials(iTrial).DotsCoherence;
    BpodSystem.Data.Custom.drawParams.screenWidthCm = TaskParameters.GUI.screenWidthCm;
    BpodSystem.Data.Custom.drawParams.screenDistCm = TaskParameters.GUI.screenDistCm;
    BpodSystem.Data.Custom.drawParams.dotSizeInDegs = TaskParameters.GUI.dotSizeInDegs;

    % Start from the 5th byte
    wait_mmap_file = createMMFile(tempdir, 'mmap_matlab_dot_read.dat', 4);
    serializeAndWrite(BpodSystem.SystemSettings.dotsMapped_file, 5,...
                      BpodSystem.Data.Custom.drawParams, wait_mmap_file, 1);
    BpodSystem.SystemSettings.dotsMapped_file.Data(1:4) =...
                                                    typecast(uint32(1), 'uint8');

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

LeftValveTime  = GetValveTimes(BpodSystem.Data.Custom.Trials(iTrial).RewardMagnitude(1), LeftPort);
CenterValveTime  = GetValveTimes(BpodSystem.Data.Custom.Trials(iTrial).CenterPortRewAmount, CenterPort);
RightValveTime  = GetValveTimes(BpodSystem.Data.Custom.Trials(iTrial).RewardMagnitude(2), RightPort);

% iff() function takes first parameter as first condition, if the condition
% is true then it returns the 2nd parameter, else it returns the 3rd one
RewardedPort = iff(IsLeftRewarded, LeftPort, RightPort);
RewardedPortPWM = iff(IsLeftRewarded, LeftPWM, RightPWM);
IncorrectConsequence = iff(~TaskParameters.GUI.HabituateIgnoreIncorrect,...
                           str(MatrixState.WaitForPunishStart), str(MatrixState.RegisterWrongWaitCorrect));
LeftActionState = iff(IsLeftRewarded, str(MatrixState.WaitForRewardStart), IncorrectConsequence);
RightActionState = iff(IsLeftRewarded, IncorrectConsequence, str(MatrixState.WaitForRewardStart));
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

% White Noise played as Error Feedback
ErrorFeedback = iff(TaskParameters.GUI.PlayNoiseforError, {'SoftCode',11}, {});

% CatchTrial
FeedbackDelayCorrect = iff(BpodSystem.Data.Custom.Trials(iTrial).CatchTrial, Const.FEEDBACK_CATCH_CORRECT_SEC, TaskParameters.GUI.FeedbackDelay);

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
Wire1OutCorrect = iff(TaskParameters.GUI.Wire1VideoTrigger && BpodSystem.Data.Custom.Trials(iTrial).CatchTrial, {'WireState', 2^1}, {});

% LED on the side lateral port to cue the rewarded side at the beginning of
% the training. On auditory discrimination task, both lateral ports are
% illuminated after end of stimulus delivery.
if BpodSystem.Data.Custom.Trials(iTrial).ForcedLEDTrial
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
sma = AddState(sma, 'Name', str(MatrixState.ITI_Signal),...
    'Timer',ITI_Signal_Duration,...
    'StateChangeConditions',{'Tup',str(MatrixState.WaitForCenterPoke)},...
    'OutputActions',ITI_Signal);
sma = AddState(sma, 'Name', str(MatrixState.WaitForCenterPoke),...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortIn, str(MatrixState.PreStimReward)},...
    'OutputActions', {strcat('PWM',num2str(CenterPort)),CenterPWM});
sma = AddState(sma, 'Name', str(MatrixState.PreStimReward),...
    'Timer', iff(TaskParameters.GUI.PreStimuDelayCntrReward,...
                 GetValveTimes(TaskParameters.GUI.PreStimuDelayCntrReward, CenterPort),0.01),...
    'StateChangeConditions', {'Tup', str(MatrixState.TriggerWaitForStimulus)},...
    'OutputActions', iff(TaskParameters.GUI.PreStimuDelayCntrReward,{'ValveState',CenterValve},[]));
% The next method is useful to close the 2-photon shutter. It is enabled
% by setting Optogenetics StartState to this state and end state to ITI.
sma = AddState(sma, 'Name', str(MatrixState.TriggerWaitForStimulus),...
    'Timer', WireTTLDuration,...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.StimDelayGrace),'Tup',str(MatrixState.WaitForStimulus)},...
    'OutputActions', [CloseChamber AirFlowStimDelayOff]);
sma = AddState(sma, 'Name', str(MatrixState.WaitForStimulus),...
    'Timer', max(0, TaskParameters.GUI.StimDelay - WireTTLDuration),...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.StimDelayGrace),'Tup', str(MatrixState.stimulus_delivery)},...
    'OutputActions', AirFlowStimDelayOff);
sma = AddState(sma, 'Name', str(MatrixState.StimDelayGrace),...
    'Timer',TaskParameters.GUI.StimDelayGrace,...
    'StateChangeConditions',{'Tup',str(MatrixState.broke_fixation),CenterPortIn,str(MatrixState.TriggerWaitForStimulus)},...
    'OutputActions',[AirFlowStimDelayOff]);
sma = AddState(sma, 'Name', str(MatrixState.broke_fixation),...
    'Timer',iff(~PCTimeout, TaskParameters.GUI.TimeOutBrokeFixation, 0.01),...
    'StateChangeConditions',{'Tup',str(MatrixState.ITI)},...
    'OutputActions',[ErrorFeedback]);
sma = AddState(sma, 'Name', str(MatrixState.stimulus_delivery),...
    'Timer', TaskParameters.GUI.MinSample,...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.early_withdrawal),'Tup',str(MatrixState.BeepMinSampling)},...
    'OutputActions', [DeliverStimulus AirFlowSamplingOff]);
sma = AddState(sma, 'Name', str(MatrixState.early_withdrawal),...
    'Timer',0,...
    'StateChangeConditions',{'Tup',str(MatrixState.timeOut_EarlyWithdrawal)},...
    'OutputActions', [EWDStopStimulus AirFlowSamplingOn, {'GlobalTimerTrig',EncTrig(3)}]);
sma = AddState(sma, 'Name', str(MatrixState.BeepMinSampling),...
    'Timer', MinSampleBeepDuration,...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.TriggerWaitChoiceTimer),'Tup',str(MatrixState.CenterPortRewardDelivery)},...
    'OutputActions', [ContDeliverStimulus MinSampleBeep]);
sma = AddState(sma, 'Name', str(MatrixState.CenterPortRewardDelivery),...
    'Timer', Timer_CPRD,...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.TriggerWaitChoiceTimer),'Tup',str(MatrixState.WaitCenterPortOut)},...
    'OutputActions', RewardCenterPort);
% TODO: Stop stimulus is fired twice in case of center reward and then wait
% for choice. Fix it such that it'll be always fired once.
sma = AddState(sma, 'Name', str(MatrixState.TriggerWaitChoiceTimer),...
    'Timer',0,...
    'StateChangeConditions', {'Tup',str(MatrixState.WaitForChoice)},...
    'OutputActions',[StopStimulus ExtendedStimulus {'GlobalTimerTrig',EncTrig(4)}]);
sma = AddState(sma, 'Name', str(MatrixState.WaitCenterPortOut),...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortOut,str(MatrixState.WaitForChoice),...
                              LeftPortIn,LeftActionState,...
                              RightPortIn,RightActionState,...
                              'GlobalTimer4_End',str(MatrixState.timeOut_missed_choice)},...
    'OutputActions', [StopStimulus ExtendedStimulus {'GlobalTimerTrig',EncTrig(4)}]);
sma = AddState(sma, 'Name', str(MatrixState.WaitForChoice),...
    'Timer',0,...
    'StateChangeConditions', {LeftPortIn,LeftActionState,RightPortIn,RightActionState,'GlobalTimer4_End',str(MatrixState.timeOut_missed_choice)},...
    'OutputActions',[StopStimulus ExtendedStimulus]);
sma = AddState(sma, 'Name',str(MatrixState.WaitForRewardStart),...
    'Timer',0,...
    'StateChangeConditions', {'Tup',str(MatrixState.WaitForReward)},...
    'OutputActions', [Wire1OutCorrect ChoiceStopStimulus {'GlobalTimerTrig',EncTrig(1)}]);
sma = AddState(sma, 'Name',str(MatrixState.WaitForReward),...
    'Timer',FeedbackDelayCorrect,...
    'StateChangeConditions', {'Tup',str(MatrixState.Reward),'GlobalTimer1_End',str(MatrixState.Reward),RewardOut, str(MatrixState.RewardGrace) },...
    'OutputActions', AirFlowRewardOff);
sma = AddState(sma, 'Name',str(MatrixState.RewardGrace),...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {RewardIn,str(MatrixState.WaitForReward),'Tup',str(MatrixState.timeOut_SkippedFeedback),'GlobalTimer1_End' ,str(MatrixState.timeOut_SkippedFeedback), CenterPortIn,str(MatrixState.timeOut_SkippedFeedback), PunishIn,str(MatrixState.timeOut_SkippedFeedback)},...
    'OutputActions', AirFlowRewardOn);
sma = AddState(sma, 'Name',str(MatrixState.Reward),...
    'Timer',ValveTime,...
    'StateChangeConditions', {'Tup',str(MatrixState.WaitRewardOut)},...
    'OutputActions', {'ValveState', ValveCode});
sma = AddState(sma, 'Name',str(MatrixState.WaitRewardOut),...
    'Timer',1.0,...
    'StateChangeConditions', {'Tup',str(MatrixState.ITI),RewardOut,str(MatrixState.ITI)},...
    'OutputActions', {});
sma = AddState(sma, 'Name',str(MatrixState.RegisterWrongWaitCorrect),...
    'Timer',0,...
    'StateChangeConditions', {'Tup',str(MatrixState.WaitForChoice)},...
    'OutputActions',[]);
sma = AddState(sma, 'Name',str(MatrixState.WaitForPunishStart),...
    'Timer',0,...
    'StateChangeConditions', {'Tup',str(MatrixState.WaitForPunish)},...
    'OutputActions',[Wire1OutError ChoiceStopStimulus {'GlobalTimerTrig',EncTrig(2)}]);
sma = AddState(sma, 'Name',str(MatrixState.WaitForPunish),...
    'Timer',FeedbackDelayError,...
    'StateChangeConditions', {'Tup',str(MatrixState.Punishment),'GlobalTimer2_End',str(MatrixState.Punishment),PunishOut, str(MatrixState.PunishGrace) },...
    'OutputActions', AirFlowRewardOff);
sma = AddState(sma, 'Name',str(MatrixState.PunishGrace),...
    'Timer',TaskParameters.GUI.FeedbackDelayGrace,...
    'StateChangeConditions', {PunishIn,str(MatrixState.WaitForPunish),'Tup',str(MatrixState.timeOut_SkippedFeedback),'GlobalTimer2_End' ,str(MatrixState.timeOut_SkippedFeedback), CenterPortIn,str(MatrixState.timeOut_SkippedFeedback), RewardIn,str(MatrixState.timeOut_SkippedFeedback)},...
    'OutputActions',{});
sma = AddState(sma, 'Name', str(MatrixState.Punishment),...
    'Timer',PunishmentDuration,...
    'StateChangeConditions',{'Tup',str(MatrixState.timeOut_IncorrectChoice)},...
    'OutputActions',[IncorrectChoice_Signal AirFlowRewardOn]);
sma = AddState(sma, 'Name', str(MatrixState.timeOut_EarlyWithdrawal),...
    'Timer',LEDErrorRate,...
    'StateChangeConditions',{'GlobalTimer3_End',str(MatrixState.ITI),'Tup',str(MatrixState.timeOut_EarlyWithdrawalFlashOn)},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', str(MatrixState.timeOut_EarlyWithdrawalFlashOn),...
    'Timer',LEDErrorRate,...
    'StateChangeConditions',{'GlobalTimer3_End',str(MatrixState.ITI),'Tup',str(MatrixState.timeOut_EarlyWithdrawal)},...
    'OutputActions',[ErrorFeedback, {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(RightPort)),RightPWM}]);
sma = AddState(sma, 'Name', str(MatrixState.timeOut_IncorrectChoice),...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutIncorrectChoice,0.01),...
    'StateChangeConditions',{'Tup',str(MatrixState.ITI)},...
    'OutputActions',{});
sma = AddState(sma, 'Name', str(MatrixState.timeOut_SkippedFeedback),...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutSkippedFeedback,0.01),...
    'StateChangeConditions',{'Tup',str(MatrixState.ITI)},...
    'OutputActions',SkippedFeedbackSignal); % TODO: See how to get around this if PCTimeout
sma = AddState(sma, 'Name', str(MatrixState.timeOut_missed_choice),...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.TimeOutMissedChoice,0.01),...
    'StateChangeConditions',{'Tup',str(MatrixState.ITI)},...
    'OutputActions',[ErrorFeedback ChoiceStopStimulus]);
sma = AddState(sma, 'Name', str(MatrixState.ITI),...
    'Timer',WireTTLDuration,...
    'StateChangeConditions',{'Tup',str(MatrixState.ext_ITI)},...
    'OutputActions', [AirFlowRewardOn]);
sma = AddState(sma, 'Name', str(MatrixState.ext_ITI),...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.ITI,0.01),...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions', AirFlowRewardOn);

% If Optogenetics/2-Photon is enabled for a particular state, then we
% modify that gien state such that it would send a signal to arduino with
% the required offset delay to trigger the optogentics box.
% Note: To precisely track your optogentics signal, split the arduino
% output to the optogentics box and feed it as an input to Bpod input TTL,
% e.g Wire1. This way, the optogentics signal gets written as part of your
% data file. Don't forget to activate that input in the Bpod main config.
if BpodSystem.Data.Custom.Trials(iTrial).OptoEnabled
    % Convert seconds to millis as we will send ints to Arduino
    OptoDelay = uint32(TaskParameters.GUI.OptoStartDelay*1000);
    OptoDelay = typecast(OptoDelay, 'int8');
    OptoTime  = uint32(TaskParameters.GUI.OptoMaxTime*1000);
    OptoTime = typecast(OptoTime, 'int8');
    if ~BpodSystem.EmulatorMode || isfield(...
                                 BpodSystem.PluginSerialPorts,'OptoSerial')
        fwrite(BpodSystem.PluginSerialPorts.OptoSerial, OptoDelay, 'int8');
        fwrite(BpodSystem.PluginSerialPorts.OptoSerial, OptoTime, 'int8');
    end
    OptoStartTTLPin = 2.^(3-1);
    OptoStopTTLPin = 2.^(4-1);
    Tuple = {str(TaskParameters.GUI.OptoStartState1) OptoStartTTLPin;
             str(TaskParameters.GUI.OptoEndState1)   OptoStopTTLPin;
             str(TaskParameters.GUI.OptoEndState2)   OptoStopTTLPin;
             str(MatrixState.ext_ITI)                OptoStopTTLPin};
    % New few lines adaped from EditState.m
    EventCode = strcmp('WireState', BpodSystem.OutputActionNames);
    for i = 1:length(Tuple)
        StateName = Tuple{i, 1};
        TTLPin = Tuple{i, 2};
        TrgtStateNum = strcmp(StateName, sma.StateNames);
        OrigTTLVal = sma.OutputMatrix(TrgtStateNum, EventCode);
        sma.OutputMatrix(TrgtStateNum, EventCode) = bitor(OrigTTLVal,...
                                                          TTLPin);
    end
end
end

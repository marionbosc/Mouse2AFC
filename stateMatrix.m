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

% PWM = (255 * (100-Attenuation))/100
LeftPWM = round((100-TaskParameters.GUI.LeftPokeAttenPrcnt) * 2.55);
CenterPWM = round((100-TaskParameters.GUI.CenterPokeAttenPrcnt) * 2.55);
RightPWM = round((100-TaskParameters.GUI.RightPokeAttenPrcnt) * 2.55);
LEDErrorRate = 0.1;

IsLeftRewarded = BpodSystem.Data.Custom.LeftRewarded(iTrial);

if TaskParameters.GUI.ExperimentType == ExperimentType.Auditory
    DeliverStimulus =  {'BNCState',1};
    ContDeliverStimulus = DeliverStimulus;
    StopStimulus = {'BNCState',0};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.LightIntensity
    % Divide Intensity by 100 to get fraction value
    LeftPWM = round(BpodSystem.Data.Custom.LightIntensityLeft(iTrial)*LeftPWM/100);
    RightPWM = round(BpodSystem.Data.Custom.LightIntensityRight(iTrial)*RightPWM/100);
    DeliverStimulus = {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(RightPort)),RightPWM};
    ContDeliverStimulus = DeliverStimulus;
    StopStimulus = {};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.GratingOrientation
    % Clear first any previously drawn buffer by drawing a rect
    Screen(BpodSystem.Data.Custom.visual.window,'FillRect',...
           TaskParameters.GUI.grey);
    Screen('Flip', BpodSystem.Data.Custom.visual.window);
    % Prepare the new texture for drawing
    orientation = BpodSystem.Data.Custom.GratingOrientation(iTrial);
    [gabortex, propertiesMat] = GetGaborData(BpodSystem.Data.Custom.visual, TaskParameters.GUI);
    Screen('DrawTextures', BpodSystem.Data.Custom.visual.window,gabortex,...
        [], [], orientation,[], [], [], [], kPsychDontDoRotation, propertiesMat');
    DeliverStimulus = {'SoftCode',3};
    ContDeliverStimulus = {};
    StopStimulus = {'SoftCode',4};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.RandomDots
    % Clear first any previously drawn buffer by drawing a rect
    Screen(BpodSystem.Data.Custom.visual.window,'FillRect', 0);
    % The screen might have something pre-drawn on it with 'DrawFInished'
    % passed. Flip twice, once to draw back buffer and second time to clear
    % it.
    %Screen('Flip', BpodSystem.Data.Custom.visual.window);
    Screen('Flip', BpodSystem.Data.Custom.visual.window);
    % Setup the parameters
    % TODO: Remove kbcheck from the DrawDots() function
    % Use 20% of the screen size. Assume apertureSize is the diameter
    TaskParameters.GUI.circleArea = ...
        (pi*((TaskParameters.GUI.apertureSizeWidth/2).^2));
    TaskParameters.GUI.nDots = round(TaskParameters.GUI.circleArea * 0.05);
    % First we'll calculate the left, right top and bottom of the aperture (in
    % degrees)
    BpodSystem.Data.Custom.rDots.l = ...
        TaskParameters.GUI.centerX-TaskParameters.GUI.apertureSizeWidth/2;
    BpodSystem.Data.Custom.rDots.r = ...
        TaskParameters.GUI.centerX+TaskParameters.GUI.apertureSizeWidth/2;
    BpodSystem.Data.Custom.rDots.b = ...
        TaskParameters.GUI.centerY-TaskParameters.GUI.apertureSizeHeight/2;
    BpodSystem.Data.Custom.rDots.t = ...
        TaskParameters.GUI.centerY+TaskParameters.GUI.apertureSizeHeight/2;

    % Direction in degrees (clockwise from straight up) for the main stimulus
    mainDirection = iff(IsLeftRewarded, 270, 90);
    coherence = BpodSystem.Data.Custom.DotsCoherence(iTrial);
    directions = BpodSystem.Data.Custom.rDots.directions;
    frameRate = BpodSystem.Data.Custom.rDots.frameRate;
    dotSpeed = TaskParameters.GUI.dotSpeedDegsPerSec;
    % Calculate ratio of incoherent for each direction so can use it later
    % to know how many dots should be per each direction. The ratio is
    % equal to the total incoherence divide by the number of directions
    % minus one. A coherence of zero has equal oppurtunity in all
    % directions, and thus the main direction ratio is the normal coherence
    % plus the its share of random incoherence.
    directionIncoherence = (1 - coherence)/length(directions);
    directionsRatios(1:length(directions)) = directionIncoherence;
    directionsRatios(directions == mainDirection) = ...
                 directionsRatios(directions == mainDirection) + coherence;
    % Round the number of dots that we have such that we get whole number
    % for each direction
    BpodSystem.Data.Custom.rDots.directionNDots = ...
                        round(directionsRatios * TaskParameters.GUI.nDots);
    % Re-evaluate the number of dots
    TaskParameters.GUI.nDots = sum(...
                              BpodSystem.Data.Custom.rDots.directionNDots);
    % Convert lifetime to number of frames
    BpodSystem.Data.Custom.rDots.lifetime = ceil(...
                           TaskParameters.GUI.dotLifetimeSecs * frameRate);
    % Each dot will have a integer value 'life' which is how many frames the
    % dot has been going.  The starting 'life' of each dot will be a random
    % number between 0 and dotsParams.lifetime-1 so that they don't all 'die' on the
    % same frame:
    BpodSystem.Data.Custom.rDots.dotsLife = ceil(...
        rand(1,TaskParameters.GUI.nDots)*...
        BpodSystem.Data.Custom.rDots.lifetime);
    % The distance traveled by a dot (in degrees) is the speed (degrees/second)
    % divided by the frame rate (frames/second). The units cancel, leaving
    % degrees/frame which makes sense. Basic trigonometry (sines and cosines)
    % allows us to determine how much the changes in the x and y position.
    BpodSystem.Data.Custom.rDots.dx = ...
                                 dotSpeed*sin(directions*pi/180)/frameRate;
    BpodSystem.Data.Custom.rDots.dy = ...
                                -dotSpeed*cos(directions*pi/180)/frameRate;
    % Create all the dots in random starting positions
    BpodSystem.Data.Custom.rDots.x = ...
        (rand(1,TaskParameters.GUI.nDots)-.5)*...
        TaskParameters.GUI.apertureSizeWidth + TaskParameters.GUI.centerX;
    BpodSystem.Data.Custom.rDots.y = ...
        (rand(1,TaskParameters.GUI.nDots)-.5)*...
        TaskParameters.GUI.apertureSizeHeight + TaskParameters.GUI.centerY;
    % Calculate the size of a dot in pixel
    BpodSystem.Data.Custom.rDots.dotSizePx = Angle2Pix(...
        TaskParameters.GUI.screenWidthCm,...
        BpodSystem.Data.Custom.visual.windowRect(3),...
        TaskParameters.GUI.screenDistCm, TaskParameters.GUI.dotSizeInDegs);
    % Prepare the first frame for drawing
    PreDrawDots();
    DeliverStimulus = {'SoftCode',5};
    ContDeliverStimulus = {};
    StopStimulus = {'SoftCode',6};
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
LeftActionState = iff(IsLeftRewarded, 'WaitForRewardStart', 'WaitForPunishStart');
RightActionState = iff(IsLeftRewarded,'WaitForPunishStart', 'WaitForRewardStart');
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
FeedbackDelayCorrect = iff(BpodSystem.Data.Custom.CatchTrial(iTrial), Const.FEEDBACK_CATCH_CORRECT_SEC, TaskParameters.GUI.FeedbackDelay);

% GUI option CatchError
FeedbackDelayError = iff(TaskParameters.GUI.CatchError, Const.FEEDBACK_CATCH_INCORRECT_SEC, TaskParameters.GUI.FeedbackDelay);
SkippedFeedbackSignal = iff(TaskParameters.GUI.CatchError, {}, ErrorFeedback);

% Incorrect Choice signal
if TaskParameters.GUI.IncorrectChoiceSignalType == IncorrectChoiceSignalType.NoisePulsePal
    PunishmentDuration = 0.01;
    IncorrectChoice_Signal = {'SoftCode', 11};
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
Wire1OutError = iff(TaskParameters.GUI.Wire1VideoTrigger, {'WireState', 1}, {});
Wire1OutCorrect = iff(TaskParameters.GUI.Wire1VideoTrigger && BpodSystem.Data.Custom.CatchTrial(iTrial), {'WireState', 1}, {});

% LED on the side lateral port to cue the rewarded side at the beginning of
% the training. On auditory discrimination task, both lateral ports are
% illuminated after end of stimulus delivery.
if BpodSystem.Data.Custom.ForcedLEDTrial(iTrial)
    LEDActivation = {strcat('PWM',num2str(RewardedPort)),RewardedPortPWM};
elseif TaskParameters.GUI.ExperimentType == ExperimentType.Auditory || TaskParameters.GUI.StimAfterPokeOut
    LEDActivation = {strcat('PWM',num2str(LeftPort)),LeftPWM,strcat('PWM',num2str(RightPort)),RightPWM};
else
    LEDActivation = {};
end

PCTimeout=TaskParameters.GUI.PCTimeout;
%% Build state matrix
sma = NewStateMatrix();
sma = SetGlobalTimer(sma,1,FeedbackDelayCorrect);
sma = SetGlobalTimer(sma,2,FeedbackDelayError);
sma = SetGlobalTimer(sma,3,iff(TaskParameters.GUI.TimeOutEarlyWithdrawal, TaskParameters.GUI.TimeOutEarlyWithdrawal, 0.01));
sma = AddState(sma, 'Name', 'ITI_Signal',...
    'Timer',ITI_Signal_Duration,...
    'StateChangeConditions',{'Tup','WaitForCenterPoke'},...
    'OutputActions',ITI_Signal);
sma = AddState(sma, 'Name', 'WaitForCenterPoke',...
    'Timer', 0,...
    'StateChangeConditions', {CenterPortIn, 'WaitForStimulus'},...
    'OutputActions', {strcat('PWM',num2str(CenterPort)),CenterPWM});
sma = AddState(sma, 'Name', 'broke_fixation',...
    'Timer',iff(~PCTimeout, TaskParameters.GUI.TimeOutBrokeFixation, 0.01),...
    'StateChangeConditions',{'Tup','ITI'},...
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'WaitForStimulus',...
    'Timer', TaskParameters.GUI.StimDelay,...
    'StateChangeConditions', {CenterPortOut,'broke_fixation','Tup', 'stimulus_delivery'},...
    'OutputActions', AirFlowStimDelayOff);
sma = AddState(sma, 'Name', 'stimulus_delivery',...
    'Timer', TaskParameters.GUI.MinSample,...
    'StateChangeConditions', {CenterPortOut,'early_withdrawal','Tup','BeepMinSampling'},...
    'OutputActions', [DeliverStimulus AirFlowSamplingOff]);
sma = AddState(sma, 'Name', 'early_withdrawal',...
    'Timer',0,...
    'StateChangeConditions',{'Tup','timeOut_EarlyWithdrawal'},...
    'OutputActions', [StopStimulus AirFlowSamplingOn, {'GlobalTimerTrig',3}]);
sma = AddState(sma, 'Name', 'BeepMinSampling',...
    'Timer', MinSampleBeepDuration,...
    'StateChangeConditions', {CenterPortOut,'WaitForChoice','Tup','CenterPortRewardDelivery'},...
    'OutputActions', [ContDeliverStimulus MinSampleBeep]);
sma = AddState(sma, 'Name', 'CenterPortRewardDelivery',...
    'Timer', Timer_CPRD,...
    'StateChangeConditions', {CenterPortOut,'WaitForChoice','Tup','WaitForChoice'},...
    'OutputActions', RewardCenterPort);
% TODO: Stop stimulus is fired twice in case of center reward and then wait
% for choice. Fix it such that it'll be always fired once.
sma = AddState(sma, 'Name', 'WaitForChoice',...
    'Timer',TaskParameters.GUI.ChoiceDeadLine,...
    'StateChangeConditions', {LeftPortIn,LeftActionState,RightPortIn,RightActionState,'Tup','timeOut_missed_choice'},...
    'OutputActions',[StopStimulus LEDActivation]);
sma = AddState(sma, 'Name','WaitForRewardStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForReward'},...
    'OutputActions', [Wire1OutCorrect {'GlobalTimerTrig',1}]);
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
    'StateChangeConditions', {'Tup','ITI'},...
    'OutputActions', {'ValveState', ValveCode});
sma = AddState(sma, 'Name','WaitForPunishStart',...
    'Timer',0,...
    'StateChangeConditions', {'Tup','WaitForPunish'},...
    'OutputActions',[Wire1OutError {'GlobalTimerTrig',2}]);
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
    'OutputActions',[ErrorFeedback, {strcat('PWM',num2str(LeftPort)),255,strcat('PWM',num2str(RightPort)),255}]);
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
    'OutputActions',ErrorFeedback);
sma = AddState(sma, 'Name', 'ITI',...
    'Timer',iff(~PCTimeout,TaskParameters.GUI.ITI,0.01),...
    'StateChangeConditions',{'Tup','exit'},...
    'OutputActions', AirFlowRewardOn);
% sma = AddState(sma, 'Name', 'state_name',...
%     'Timer', 0,...
%     'StateChangeConditions', {},...
%     'OutputActions', {});
end

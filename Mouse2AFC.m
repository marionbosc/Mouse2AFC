function Mouse2AFC
% 2-AFC  auditory discrimination task implented for Bpod fork https://github.com/KepecsLab/bpod
% This project is available on https://github.com/KepecsLab/BpodProtocols_Olf2AFC/

global BpodSystem
addpath('Definitions');

%% Task parameters
global TaskParameters
TaskParameters = BpodSystem.ProtocolSettings;
if isempty(fieldnames(TaskParameters))
    %% General
    TaskParameters.GUI.ITI = 0.5; % (s)
    TaskParameters.GUI.RewardAmount = 2;
    TaskParameters.GUI.ChoiceDeadLine = 5;
    TaskParameters.GUI.TimeOutIncorrectChoice = 3; % (s)
    TaskParameters.GUI.TimeOutBrokeFixation = 3; % (s)
    TaskParameters.GUI.TimeOutEarlyWithdrawal = 3; % (s)
    TaskParameters.GUI.TimeOutMissedChoice = 3; % (s)
    TaskParameters.GUI.TimeOutSkippedFeedback = 0; % (s)
    TaskParameters.GUI.PlayNoiseforError = 0;
    TaskParameters.GUIMeta.PlayNoiseforError.Style = 'checkbox';
    TaskParameters.GUI.StartEasyTrials = 50;
    TaskParameters.GUI.Percent50Fifty = 0;
    TaskParameters.GUI.PercentCatch = 0;
    TaskParameters.GUI.CatchError = false;
    TaskParameters.GUIMeta.CatchError.Style = 'checkbox';
    TaskParameters.GUI.Ports_LMR = 123;
    TaskParameters.GUI.Wire1VideoTrigger = false;
    TaskParameters.GUIMeta.Wire1VideoTrigger.Style = 'checkbox';
    TaskParameters.GUIPanels.General = {'ITI','RewardAmount','ChoiceDeadLine','TimeOutIncorrectChoice','TimeOutBrokeFixation','TimeOutEarlyWithdrawal','TimeOutMissedChoice','TimeOutSkippedFeedback','PlayNoiseforError','StartEasyTrials','Percent50Fifty','PercentCatch','CatchError','Ports_LMR','Wire1VideoTrigger'};
    %% StimDelay
    TaskParameters.GUI.StimDelayAutoincrement = 0;
    TaskParameters.GUIMeta.StimDelayAutoincrement.Style = 'checkbox';
    TaskParameters.GUIMeta.StimDelayAutoincrement.String = 'Auto';
    TaskParameters.GUI.StimDelayMin = 0.01;
    TaskParameters.GUI.StimDelayMax = 0.01;
    TaskParameters.GUI.StimDelayIncr = 0.01;
    TaskParameters.GUI.StimDelayDecr = 0.01;
    TaskParameters.GUI.StimDelay = TaskParameters.GUI.StimDelayMin;
    TaskParameters.GUIMeta.StimDelay.Style = 'text';
    TaskParameters.GUIPanels.StimDelay = {'StimDelayAutoincrement','StimDelayMin','StimDelayMax','StimDelayIncr','StimDelayDecr','StimDelay'};
    %% FeedbackDelay
    TaskParameters.GUI.FeedbackDelaySelection = FeedbackDelaySelection.Fix;
    TaskParameters.GUIMeta.FeedbackDelaySelection.Style = 'popupmenu';
    TaskParameters.GUIMeta.FeedbackDelaySelection.String = FeedbackDelaySelection.String;
    TaskParameters.GUI.FeedbackDelayMin = 0.1;
    TaskParameters.GUI.FeedbackDelayMax = 0.1;
    TaskParameters.GUI.FeedbackDelayIncr = 0.01;
    TaskParameters.GUI.FeedbackDelayDecr = 0.01;
    TaskParameters.GUI.FeedbackDelayTau = 0.1;
    TaskParameters.GUI.FeedbackDelayGrace = 0.4;
    TaskParameters.GUI.IncorrectChoiceSignalType = IncorrectChoiceSignalType.Noise;
    TaskParameters.GUIMeta.IncorrectChoiceSignalType.Style = 'popupmenu';
    TaskParameters.GUIMeta.IncorrectChoiceSignalType.String = IncorrectChoiceSignalType.String;
    TaskParameters.GUI.ITISignalType = ITISignalType.Beep;
    TaskParameters.GUIMeta.ITISignalType.Style = 'popupmenu';
    TaskParameters.GUIMeta.ITISignalType.String = ITISignalType.String;
    TaskParameters.GUI.FeedbackDelay = TaskParameters.GUI.FeedbackDelayMin;
    TaskParameters.GUIMeta.FeedbackDelay.Style = 'text';
    TaskParameters.GUIPanels.FeedbackDelay = {'FeedbackDelaySelection','FeedbackDelayMin','FeedbackDelayMax','FeedbackDelayIncr','FeedbackDelayDecr','FeedbackDelayTau','FeedbackDelayGrace','FeedbackDelay','IncorrectChoiceSignalType','ITISignalType'};
    %% Stimulus and Sampling Params
    % Stimulus
    TaskParameters.GUI.LeftBias = 0.5;
    TaskParameters.GUIMeta.LeftBias.Style = 'text';
    TaskParameters.GUIMeta.PortLEDtoCueReward.Style = 'checkbox';
    TaskParameters.GUI.StimulusSelectionCriteria = StimulusSelectionCriteria.BiasCorrecting;
    TaskParameters.GUIMeta.StimulusSelectionCriteria.Style = 'popupmenu';
    TaskParameters.GUIMeta.StimulusSelectionCriteria.String = StimulusSelectionCriteria.String;
    TaskParameters.GUI.BetaDistAlphaNBeta = 0.3;
    TaskParameters.GUI.OmegaTable.Omega = [0, 5, 10, 90, 95, 100]';
    TaskParameters.GUI.OmegaTable.OmegaProb = ones(size(TaskParameters.GUI.OmegaTable.Omega))/numel(TaskParameters.GUI.OmegaTable.Omega);
    TaskParameters.GUIMeta.OmegaTable.Style = 'table';
    TaskParameters.GUIMeta.OmegaTable.String = 'Omega probabilities';
    TaskParameters.GUIMeta.OmegaTable.ColumnLabel = {'a = Omega*100','P(a)'};
    % Sampling
    TaskParameters.GUI.StimulusTime = 0.5;
    TaskParameters.GUI.RewardAfterMinSampling = true;
    TaskParameters.GUIMeta.RewardAfterMinSampling.Style = 'checkbox';
    TaskParameters.GUI.CenterPortRewAmount = 0.5;
    TaskParameters.GUI.MinSampleMin = 0.5;
    TaskParameters.GUI.MinSampleMax = 0.5;
    TaskParameters.GUI.MinSampleAutoincrement = false;
    TaskParameters.GUIMeta.MinSampleAutoincrement.Style = 'checkbox';
    TaskParameters.GUI.MinSampleIncr = 0.05;
    TaskParameters.GUI.MinSampleDecr = 0.02;
    TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
    TaskParameters.GUIMeta.MinSample.Style = 'text';
    % Auditory Specific
    TaskParameters.GUI.SumRates = 100;
    TaskParameters.GUI.PortLEDtoCueReward = false;
    TaskParameters.GUI.PercentForcedLEDTrial = 1;
    TaskParameters.GUIPanels.Auditory = {'PortLEDtoCueReward','PercentForcedLEDTrial','SumRates'};
    TaskParameters.GUIPanels.StimulusSelection = {'OmegaTable','BetaDistAlphaNBeta','StimulusSelectionCriteria','LeftBias'};
    TaskParameters.GUIPanels.Sampling = {'RewardAfterMinSampling','CenterPortRewAmount','MinSampleMin','MinSampleMax','MinSampleAutoincrement','MinSampleIncr','MinSampleDecr','MinSample','StimulusTime'};
    %% Plots
    %Show Plots
    TaskParameters.GUI.ShowPsycStim = 1;
    TaskParameters.GUIMeta.ShowPsycStim.Style = 'checkbox';
    TaskParameters.GUI.ShowVevaiometric = 1;
    TaskParameters.GUIMeta.ShowVevaiometric.Style = 'checkbox';
    TaskParameters.GUI.ShowTrialRate = 1;
    TaskParameters.GUIMeta.ShowTrialRate.Style = 'checkbox';
    TaskParameters.GUI.ShowFix = 1;
    TaskParameters.GUIMeta.ShowFix.Style = 'checkbox';
    TaskParameters.GUI.ShowST = 1;
    TaskParameters.GUIMeta.ShowST.Style = 'checkbox';
    TaskParameters.GUI.ShowFeedback = 1;
    TaskParameters.GUIMeta.ShowFeedback.Style = 'checkbox';
    TaskParameters.GUIPanels.ShowPlots = {'ShowPsycStim','ShowVevaiometric','ShowTrialRate','ShowFix','ShowST','ShowFeedback'};
    %Vevaiometric
    TaskParameters.GUI.VevaiometricMinWT = 2;
    TaskParameters.GUI.VevaiometricNBin = 8;
    TaskParameters.GUI.VevaiometricShowPoints = 1;
    TaskParameters.GUIMeta.VevaiometricShowPoints.Style = 'checkbox';
    TaskParameters.GUIPanels.Vevaiometric = {'VevaiometricMinWT','VevaiometricNBin','VevaiometricShowPoints'};
    %%
    TaskParameters.GUI = orderfields(TaskParameters.GUI);
    %% Tabs
    TaskParameters.GUITabs.General = {'ExperimentType','StimDelay','General','FeedbackDelay'};
    TaskParameters.GUITabs.Sampling = {'Auditory','Sampling','StimulusSelection'};
    TaskParameters.GUITabs.Plots = {'ShowPlots','Vevaiometric'};
    %%Non-GUI Parameters (but saved)
    TaskParameters.Figures.OutcomePlot.Position = [200, 200, 1000, 400];
    TaskParameters.Figures.ParameterGUI.Position =  [9, 454, 1474, 562];

end
BpodParameterGUI('init', TaskParameters);

%% Initializing data (trial type) vectors
BpodSystem.Data.Custom.ChoiceLeft = [];
BpodSystem.Data.Custom.ChoiceCorrect = [];
BpodSystem.Data.Custom.Feedback = false(0);
BpodSystem.Data.Custom.FeedbackTime = [];
BpodSystem.Data.Custom.FixBroke = false(0);
BpodSystem.Data.Custom.EarlyWithdrawal = false(0);
BpodSystem.Data.Custom.MissedChoice = false(0);
BpodSystem.Data.Custom.FixDur = [];
BpodSystem.Data.Custom.MT = [];
BpodSystem.Data.Custom.CatchTrial = false;
BpodSystem.Data.Custom.ST = [];
BpodSystem.Data.Custom.Rewarded = false(0);
BpodSystem.Data.Custom.RewardAfterMinSampling = false(0);
% RewardMagnitude is an array of length 2
% TODO: Use an array of 1 and just assign it to the rewarding port
BpodSystem.Data.Custom.RewardMagnitude = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount =TaskParameters.GUI.CenterPortRewAmount;
BpodSystem.Data.Custom.TrialNumber = [];

BpodSystem.Data.Custom.ForcedLEDTrial = false;
% make auditory stimuli for first trials
for a = 1:Const.NUM_EASY_TRIALS
    switch TaskParameters.GUI.StimulusSelectionCriteria
    case {StimulusSelectionCriteria.BetaDistribution, StimulusSelectionCriteria.BiasCorrecting, StimulusSelectionCriteria.Flat}
        % Why divide by 4?
        % Do we need the extra 1, 1 parameters at the end?
        % This random value is between 0 and 1, the beta distribution
        % parameters makes it very likely to very close to zero or very
        % close to 1.
        BpodSystem.Data.Custom.StimulusOmega(a) = betarnd(TaskParameters.GUI.BetaDistAlphaNBeta/4,TaskParameters.GUI.BetaDistAlphaNBeta/4,1,1);
    case TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.DiscretePairs
        % Choose randomly either the top or the bottom value in the
        % Omega table (e.g 0 or 100) and divide it by 100.
        BpodSystem.Data.Custom.StimulusOmega(a) = randsample([min(TaskParameters.GUI.OmegaTable.Omega) max(TaskParameters.GUI.OmegaTable.Omega)],1)/100;
    otherwise
        assert(false, 'This part of the code shouldn''t be reached');
    end
    DV = CalcAudClickTrain(a);
    if DV > 0
        BpodSystem.Data.Custom.LeftRewarded(a) = 1;
    elseif DV < 0
        BpodSystem.Data.Custom.LeftRewarded(a) = 0;
    else
        BpodSystem.Data.Custom.LeftRewarded(a) = rand<0.5; % It's equal distribution
    end
    % cross-modality difficulty for plotting
    %  0 <= (left - right) / (left + right) <= 1
    BpodSystem.Data.Custom.DV(a) = DV;
end%for a+1:2
% Bpod will provide feedback that we can useto trigger pulse pal

BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

%server data
[~,BpodSystem.Data.Custom.Rig] = system('hostname');
[~,BpodSystem.Data.Custom.Subject] = fileparts(fileparts(fileparts(fileparts(BpodSystem.DataPath))));

%% Configuring PulsePal
load PulsePalParamStimulus.mat
load PulsePalParamFeedback.mat
BpodSystem.Data.Custom.PulsePalParamStimulus=PulsePalParamStimulus;
BpodSystem.Data.Custom.PulsePalParamFeedback=PulsePalParamFeedback;
clear PulsePalParamFeedback PulsePalParamStimulus

if ~BpodSystem.EmulatorMode
    ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{1}))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{1}))*5);
end

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', TaskParameters.Figures.OutcomePlot.Position,'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleOutcome = axes('Position',    [  .055          .15 .91 .3]);
BpodSystem.GUIHandles.OutcomePlot.HandlePsycStim = axes('Position',    [2*.05 + 1*.08   .6  .1  .3], 'Visible', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleTrialRate = axes('Position',  [3*.05 + 2*.08   .6  .1  .3], 'Visible', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleFix = axes('Position',        [4*.05 + 3*.08   .6  .1  .3], 'Visible', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleST = axes('Position',         [5*.05 + 4*.08   .6  .1  .3], 'Visible', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleFeedback = axes('Position',   [6*.05 + 5*.08   .6  .1  .3], 'Visible', 'off');
BpodSystem.GUIHandles.OutcomePlot.HandleVevaiometric = axes('Position',   [7*.05 + 6*.08   .6  .1  .3], 'Visible', 'off');
MainPlot(BpodSystem.GUIHandles.OutcomePlot,'init');
BpodSystem.ProtocolFigures.ParameterGUI.Position = TaskParameters.Figures.ParameterGUI.Position;
%BpodNotebook('init');

%% Main loop
RunSession = true;
iTrial = 1;

% The state-matrix is generated only once in each iteration, however some
% of the trials parameters are pre-generated and updated in the plots few
% iterations before.
while RunSession
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    sma = stateMatrix(iTrial);
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.TrialSettings(iTrial) = TaskParameters;
        SaveBpodSessionData;
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.BeingUsed == 0
        return
    end

    updateCustomDataFields(iTrial);
    MainPlot(BpodSystem.GUIHandles.OutcomePlot,'update',iTrial);
    iTrial = iTrial + 1;

end
end
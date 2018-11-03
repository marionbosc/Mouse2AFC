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
    TaskParameters.GUI.ExperimentType = ExperimentType.LightIntensity;
    TaskParameters.GUIMeta.ExperimentType.Style = 'popupmenu';
    TaskParameters.GUIMeta.ExperimentType.String = ExperimentType.String;
    TaskParameters.GUI.ITI = 0; % (s)
    TaskParameters.GUI.RewardAmount = 5;
    TaskParameters.GUI.CutAirReward = false;
    TaskParameters.GUIMeta.CutAirReward.Style = 'checkbox';
    TaskParameters.GUI.ChoiceDeadLine = 20;
    TaskParameters.GUI.TimeOutIncorrectChoice = 0; % (s)
    TaskParameters.GUI.TimeOutBrokeFixation = 0; % (s)
    TaskParameters.GUI.TimeOutEarlyWithdrawal = 0; % (s)
    TaskParameters.GUI.TimeOutMissedChoice = 0; % (s)
    TaskParameters.GUI.TimeOutSkippedFeedback = 0; % (s)
    TaskParameters.GUI.PlayNoiseforError = 0;
    TaskParameters.GUIMeta.PlayNoiseforError.Style = 'checkbox';
    TaskParameters.GUI.StartEasyTrials = 10;
    TaskParameters.GUI.Percent50Fifty = 0;
    TaskParameters.GUI.PercentCatch = 0;
    TaskParameters.GUI.CatchError = true;
    TaskParameters.GUIMeta.CatchError.Style = 'checkbox';
    TaskParameters.GUI.Ports_LMRAir = 1238;
    TaskParameters.GUI.Wire1VideoTrigger = false;
    TaskParameters.GUIMeta.Wire1VideoTrigger.Style = 'checkbox';
    TaskParameters.GUIPanels.General = {'ExperimentType','ITI','RewardAmount','CutAirReward','ChoiceDeadLine','TimeOutIncorrectChoice','TimeOutBrokeFixation','TimeOutEarlyWithdrawal','TimeOutMissedChoice','TimeOutSkippedFeedback','PlayNoiseforError','StartEasyTrials','Percent50Fifty','PercentCatch','CatchError','Ports_LMRAir','Wire1VideoTrigger'};
    %% StimDelay
    TaskParameters.GUI.StimDelayAutoincrement = 0;
    TaskParameters.GUIMeta.StimDelayAutoincrement.Style = 'checkbox';
    TaskParameters.GUIMeta.StimDelayAutoincrement.String = 'Auto';
    TaskParameters.GUI.StimDelayMin = 0.3;
    TaskParameters.GUI.StimDelayMax = 0.6;
    TaskParameters.GUI.StimDelayIncr = 0.01;
    TaskParameters.GUI.StimDelayDecr = 0.01;
    TaskParameters.GUI.CutAirStimDelay = true;
    TaskParameters.GUIMeta.CutAirStimDelay.Style = 'checkbox';
    TaskParameters.GUI.StimDelay = TaskParameters.GUI.StimDelayMin;
    TaskParameters.GUIMeta.StimDelay.Style = 'text';
    TaskParameters.GUIPanels.StimDelay = {'StimDelayAutoincrement','StimDelayMin','StimDelayMax','StimDelayIncr','StimDelayDecr','CutAirStimDelay'};
    %% FeedbackDelay
    TaskParameters.GUI.FeedbackDelaySelection = FeedbackDelaySelection.Fix;
    TaskParameters.GUIMeta.FeedbackDelaySelection.Style = 'popupmenu';
    TaskParameters.GUIMeta.FeedbackDelaySelection.String = FeedbackDelaySelection.String;
    TaskParameters.GUI.FeedbackDelayMin = 0;
    TaskParameters.GUI.FeedbackDelayMax = 0;
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
    TaskParameters.GUIPanels.FeedbackDelay = {'FeedbackDelaySelection','FeedbackDelayMin','FeedbackDelayMax','FeedbackDelayIncr','FeedbackDelayDecr','FeedbackDelayTau','FeedbackDelayGrace','IncorrectChoiceSignalType','ITISignalType'};
    %% Stimulus and Sampling Params
    % Stimulus
    TaskParameters.GUI.LeftBias = 0.5;
    TaskParameters.GUIMeta.LeftBias.Style = 'slider';
    TaskParameters.GUIMeta.LeftBias.Callback = @UpdateLeftBiasVal;
    TaskParameters.GUI.LeftBiasVal = TaskParameters.GUI.LeftBias;
    TaskParameters.GUIMeta.LeftBiasVal.Callback = @UpdateLeftBias;
    TaskParameters.GUI.CorrectBias = false;
    TaskParameters.GUIMeta.CorrectBias.Style = 'checkbox';
    TaskParameters.GUI.CalcLeftBias = 0.5;
    TaskParameters.GUIMeta.CalcLeftBias.Style = 'text';
    TaskParameters.GUI.StimulusSelectionCriteria = StimulusSelectionCriteria.DiscretePairs;
    TaskParameters.GUIMeta.StimulusSelectionCriteria.Style = 'popupmenu';
    TaskParameters.GUIMeta.StimulusSelectionCriteria.String = StimulusSelectionCriteria.String;
    TaskParameters.GUI.BetaDistAlphaNBeta = 0.3;
    TaskParameters.GUI.OmegaTable.Omega =  [100:-5:55]';
    % Set first and last 3 values to be the effective ones
    TaskParameters.GUI.OmegaTable.OmegaProb = zeros(numel(TaskParameters.GUI.OmegaTable.Omega),1);
    TaskParameters.GUI.OmegaTable.OmegaProb(1) = 9; % 100
    TaskParameters.GUI.OmegaTable.OmegaProb(2) = 8; % 95
    TaskParameters.GUI.OmegaTable.OmegaProb(3) = 7; % 90
    TaskParameters.GUI.OmegaTable.OmegaProb(4) = 6; % 85
    TaskParameters.GUI.OmegaTable.OmegaProb(5) = 5; % 80
    TaskParameters.GUI.OmegaTable.OmegaProb(6) = 4; % 75
    TaskParameters.GUI.OmegaTable.OmegaProb(7) = 3; % 70
    TaskParameters.GUI.OmegaTable.OmegaProb(8) = 2; % 65
    TaskParameters.GUI.OmegaTable.OmegaProb(9) = 1; % 60
    TaskParameters.GUI.OmegaTable.OmegaProb(10) = 0; % 55
    TaskParameters.GUI.CurrentStim = 0;
    TaskParameters.GUIMeta.CurrentStim.Style = 'text';
    TaskParameters.GUIMeta.OmegaTable.Style = 'table';
    TaskParameters.GUIMeta.OmegaTable.String = 'Omega probabilities';
    TaskParameters.GUIMeta.OmegaTable.ColumnLabel = {'a = Omega*100','P(a)'};
    % Sampling
    TaskParameters.GUI.StimulusTime = 0.3;
    TaskParameters.GUI.RewardAfterMinSampling = false;
    TaskParameters.GUIMeta.RewardAfterMinSampling.Style = 'checkbox';
    TaskParameters.GUI.CenterPortRewAmount = 0.5;
    TaskParameters.GUI.MinSampleMin = 0;
    TaskParameters.GUI.MinSampleMax = 0;
    TaskParameters.GUI.MinSampleAutoincrement = false;
    TaskParameters.GUIMeta.MinSampleAutoincrement.Style = 'checkbox';
    TaskParameters.GUI.MinSampleIncr = 0.05;
    TaskParameters.GUI.MinSampleDecr = 0.02;
    TaskParameters.GUI.CutAirSampling = true;
    TaskParameters.GUIMeta.CutAirSampling.Style = 'checkbox';
    TaskParameters.GUI.MinSample = TaskParameters.GUI.MinSampleMin;
    TaskParameters.GUIMeta.MinSample.Style = 'text';
    TaskParameters.GUI.PercentForcedLEDTrial = 0;
    TaskParameters.GUI.PortLEDtoCueReward = false;
    TaskParameters.GUIMeta.PortLEDtoCueReward.Style = 'checkbox';
    % Auditory Specific
    TaskParameters.GUI.SumRates = 100;
    % Light Intensity Specific
    TaskParameters.GUI.LeftPokeAttenPrcnt = 73;
    TaskParameters.GUI.CenterPokeAttenPrcnt = 95;
    TaskParameters.GUI.RightPokeAttenPrcnt = 73;
    TaskParameters.GUI.StimAfterPokeOut = false;
    TaskParameters.GUIMeta.StimAfterPokeOut.Style = 'checkbox';
    TaskParameters.GUI.BeepAfterMinSampling = false;
    TaskParameters.GUIMeta.BeepAfterMinSampling.Style = 'checkbox';
    TaskParameters.GUIPanels.Auditory = {'SumRates'};
    TaskParameters.GUIPanels.LightIntensity = {'LeftPokeAttenPrcnt','CenterPokeAttenPrcnt','RightPokeAttenPrcnt','StimAfterPokeOut', 'BeepAfterMinSampling'};
    TaskParameters.GUIPanels.StimulusSelection = {'OmegaTable','BetaDistAlphaNBeta','StimulusSelectionCriteria','LeftBias','LeftBiasVal','CorrectBias'};
    TaskParameters.GUIPanels.Sampling = {'RewardAfterMinSampling','CenterPortRewAmount','MinSampleMin',...
                                         'MinSampleMax','MinSampleAutoincrement','MinSampleIncr','MinSampleDecr',...
                                         'CutAirSampling','StimulusTime','PortLEDtoCueReward','PercentForcedLEDTrial'};
    TaskParameters.GUI.IsCatch = 'false';
    TaskParameters.GUIMeta.IsCatch.Style = 'text';
    TaskParameters.GUIPanels.CurrentTrial = {'StimDelay','MinSample','CurrentStim','CalcLeftBias','FeedbackDelay', 'IsCatch'};
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
    TaskParameters.GUI.VevaiometricMinWT = 0.5;
    TaskParameters.GUI.VevaiometricNBin = 8;
    TaskParameters.GUI.VevaiometricShowPoints = 1;
    TaskParameters.GUIMeta.VevaiometricShowPoints.Style = 'checkbox';
    TaskParameters.GUIPanels.Vevaiometric = {'VevaiometricMinWT','VevaiometricNBin','VevaiometricShowPoints'};
    %%
    TaskParameters.GUI = orderfields(TaskParameters.GUI);
    %% Tabs
    TaskParameters.GUITabs.General = {'CurrentTrial','StimDelay','General','FeedbackDelay'};
    TaskParameters.GUITabs.Sampling = {'CurrentTrial','Auditory','LightIntensity','Sampling','StimulusSelection'};
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
BpodSystem.Data.Custom.LightIntensityLeft = [];
BpodSystem.Data.Custom.LightIntensityRight = [];
% RewardMagnitude is an array of length 2
% TODO: Use an array of 1 and just assign it to the rewarding port
BpodSystem.Data.Custom.RewardMagnitude = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount =TaskParameters.GUI.CenterPortRewAmount;
BpodSystem.Data.Custom.TrialNumber = [];
BpodSystem.Data.Custom.PCTimeout=true; % TODO: Read from GUI
BpodSystem.Data.Custom.ForcedLEDTrial = false;

file_size = 40*1024*1024; % 40 MB mem-mapped file
mapped_file = createMMFile(tempdir, 'mmap_matlab_plot.dat', file_size);

% make auditory stimuli for first trials
for a = 1:Const.NUM_EASY_TRIALS
    if TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
        % This random value is between 0 and 1, the beta distribution
        % parameters makes it very likely to very close to zero or very
        % close to 1.
        BpodSystem.Data.Custom.StimulusOmega(a) = betarnd(TaskParameters.GUI.BetaDistAlphaNBeta/4,TaskParameters.GUI.BetaDistAlphaNBeta/4,1,1);
    elseif TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.DiscretePairs
        index = find(TaskParameters.GUI.OmegaTable.OmegaProb > 0, 1);
        Intensity = TaskParameters.GUI.OmegaTable.Omega(index)/100;
    else
        assert(false, 'Unexpected StimulusSelectionCriteria');
    end
    % Randomly choose right or left
    isLeftRewarded = rand(1, 1) >= 0.5;
    % In case of beta distribution, our distribution is symmetric,
    % so prob < 0.5 is == prob > 0.5, so we can just pick the value
    % that corrects the bias
    if ~isLeftRewarded && Intensity >= 0.5
        Intensity = -Intensity + 1;
    end
    BpodSystem.Data.Custom.StimulusOmega(a) = Intensity;

    switch TaskParameters.GUI.ExperimentType
        case ExperimentType.Auditory
            DV = CalcAudClickTrain(a);
        case ExperimentType.LightIntensity
            DV = CalcLightIntensity(a);
        otherwise
            assert(false, 'Unexpected ExperimentType');
    end
    if DV > 0
        BpodSystem.Data.Custom.LeftRewarded(a) = 1;
    elseif DV < 0
        BpodSystem.Data.Custom.LeftRewarded(a) = 0;
    else
        BpodSystem.Data.Custom.LeftRewarded(a) = rand<0.5; % It's equal distribution
    end
    % cross-modality difficulty for plotting
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

if TaskParameters.GUI.ExperimentType == ExperimentType.Auditory && ~BpodSystem.EmulatorMode
    ProgramPulsePal(BpodSystem.Data.Custom.PulsePalParamStimulus);
    SendCustomPulseTrain(1, BpodSystem.Data.Custom.RightClickTrain{1}, ones(1,length(BpodSystem.Data.Custom.RightClickTrain{1}))*5);
    SendCustomPulseTrain(2, BpodSystem.Data.Custom.LeftClickTrain{1}, ones(1,length(BpodSystem.Data.Custom.LeftClickTrain{1}))*5);
end

% Set current stimulus for next trial - set between -100 to +100
TaskParameters.GUI.CurrentStim = iff(BpodSystem.Data.Custom.DV(1) > 0, (BpodSystem.Data.Custom.DV(1) + 1)/0.02,(BpodSystem.Data.Custom.DV(1) - 1)/0.02);

%BpodNotebook('init');
iTrial=0;
sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI, [0]);

%% Main loop
RunSession = true;
iTrial = 1;
sleepDur = 0;
trialEndTime = clock;
% The state-matrix is generated only once in each iteration, however some
% of the trials parameters are pre-generated and updated in the plots few
% iterations before.
while true
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    sma = stateMatrix(iTrial);
    SendStateMatrix(sma);
    pauseTime = (trialEndTime + sleepDur) - clock();
    if pauseTime > 0
        pause(pauseTime);
    end
    RawEvents = RunStateMatrix;
    trialEndTime = clock;
    if ~isempty(fieldnames(RawEvents))
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.TrialSettings(iTrial) = TaskParameters;
		try
			SaveBpodSessionData;
		catch ME
			warning(datestr(datetime('now')) + ": Failed to save file: " + ME.message);
		end
    end
    if BpodSystem.BeingUsed == 0
		while true
			try
				SaveBpodSessionData;
				break;
			catch ME
				warning(strcat("Error during last save: " + getReport(ME)));
				warning(datestr(datetime('now')) + ": trying again in few secs...");
				pause(.5);
			end
		end
        return
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    updateCustomDataFields(iTrial);
    sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI, BpodSystem.Data.TrialStartTimestamp);
    iTrial = iTrial + 1;
    if ~BpodSystem.Data.Custom.PCTimeout
        continue
    end;
    sleepDur = 0;
    statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial-1}(BpodSystem.Data.RawData.OriginalStateData{iTrial-1});
    if any(strcmp('timeOut_IncorrectChoice',statesThisTrial))
        sleepDur = sleepDur + TaskParameters.GUI.TimeOutIncorrectChoice;
    end
    if any(strcmp('timeOut_SkippedFeedback',statesThisTrial))
        sleepDur = sleepDur + TaskParameters.GUI.TimeOutSkippedFeedback;
    end
    if any(strcmp('timeOut_missed_choice',statesThisTrial))
        sleepDur = sleepDur + TaskParameters.GUI.TimeOutMissedChoice;
    end
    if any(strcmp('ITI',statesThisTrial))
        sleepDur = sleepDur + TaskParameters.GUI.ITI;
    end
end
end
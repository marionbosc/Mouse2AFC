function TaskParameters = CreateTaskParameters(GUICurVer)
TaskParameters = struct;
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
TaskParameters.GUI.PCTimeout = true;
TaskParameters.GUIMeta.PCTimeout.Style = 'checkbox';
TaskParameters.GUI.StartEasyTrials = 10;
TaskParameters.GUI.Percent50Fifty = 0;
TaskParameters.GUI.PercentCatch = 0;
TaskParameters.GUI.CatchError = false;
TaskParameters.GUIMeta.CatchError.Style = 'checkbox';
TaskParameters.GUI.Ports_LMRAir = 1238;
TaskParameters.GUI.Wire1VideoTrigger = false;
TaskParameters.GUIMeta.Wire1VideoTrigger.Style = 'checkbox';
TaskParameters.GUIPanels.General = {'ExperimentType','ITI','RewardAmount','CutAirReward','ChoiceDeadLine',...
    'TimeOutIncorrectChoice','TimeOutBrokeFixation','TimeOutEarlyWithdrawal','TimeOutMissedChoice',...
    'TimeOutSkippedFeedback','PlayNoiseforError','PCTimeout',...
    'StartEasyTrials','Percent50Fifty','PercentCatch','CatchError','Ports_LMRAir','Wire1VideoTrigger'};
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
TaskParameters.GUI.IncorrectChoiceSignalType = IncorrectChoiceSignalType.BeepOnWire_1;
TaskParameters.GUIMeta.IncorrectChoiceSignalType.Style = 'popupmenu';
TaskParameters.GUIMeta.IncorrectChoiceSignalType.String = IncorrectChoiceSignalType.String;
TaskParameters.GUI.ITISignalType = ITISignalType.None;
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
TaskParameters.GUI.Performance = '(Calc. after 1st trial)';
TaskParameters.GUIMeta.Performance.Style = 'text';
TaskParameters.GUI.AllPerformance = '(Calc. after 1st trial)';
TaskParameters.GUIMeta.AllPerformance.Style = 'text';
TaskParameters.GUI.IsCatch = 'false';
TaskParameters.GUIMeta.IsCatch.Style = 'text';
TaskParameters.GUIPanels.CurrentTrial = {'StimDelay','MinSample',...
    'CurrentStim','CalcLeftBias','FeedbackDelay', 'IsCatch',...
    'Performance','AllPerformance'};
% General Visual options
TaskParameters.GUI.screenNumber = 2;
TaskParameters.GUI.runSyncTests = false;
TaskParameters.GUI.centerX = 0; % center of the field of dots (x,y)
TaskParameters.GUI.centerY = 0;
TaskParameters.GUIPanels.VisualGeneral = {'screenNumber','runSyncTests',...
    'centerX','centerY'};
% Random dots options
TaskParameters.GUI.screenDistCm = 30;
TaskParameters.GUI.screenWidthCm = 20;
TaskParameters.GUI.apertureSizeWidth = 36; % size of rectangular aperture [w,h] in degrees
TaskParameters.GUI.apertureSizeHeight = 36;
% Use 20% of the screen size
TaskParameters.GUI.drawRatio = 0.2; 
TaskParameters.GUI.circleArea = (pi*((TaskParameters.GUI.apertureSizeWidth/2).^2)); % assume apertureSize is the diameter
TaskParameters.GUIMeta.circleArea.Style = 'text';
TaskParameters.GUI.nDots = round(TaskParameters.GUI.circleArea * 0.05);
TaskParameters.GUIMeta.nDots.Style = 'text';
%dotsParams.nDots = 300;     % total number of dots
TaskParameters.GUI.dotSizeInDegs = 2; % size of dots in degrees
TaskParameters.GUI.dotSpeedDegsPerSec = 25; %degrees/second
TaskParameters.GUI.dotLifetimeSecs = 1;  %lifetime of each dot sec
TaskParameters.GUIPanels.RandomDots = {'screenDistCm','screenWidthCm',...
    'apertureSizeWidth','apertureSizeHeight','drawRatio','circleArea',...
    'nDots','dotSizeInDegs','dotSpeedDegsPerSec','dotLifetimeSecs'};
% Grating orientation specific
TaskParameters.GUI.gaborSizeFactor = 1.0;
TaskParameters.GUI.phase = 0.5; % Phase of the wave, goes between 0 to 360
% Spatial Frequency (Cycles Per Pixel)
% One Cycle = Grey-Black-Grey-White-Grey i.e. One Black and One White Lobe
TaskParameters.GUI.numCycles = 5;
TaskParameters.GUI.sigmaDivFactor = 7; % Gamma and circle blurness around grating
TaskParameters.GUI.contrast = 0.8; % How blur is it between the lines, I've tried up to 100
TaskParameters.GUI.grey = 0.5;
TaskParameters.GUIMeta.runSyncTests.Style = 'checkbox';
TaskParameters.GUI.aspectRatio = 1.0;
% Build a procedural gabor texture (Note: to get a "standard" Gabor patch
% we set a grey background offset, disable normalisation, and set a
% pre-contrast multiplier of 0.5.
% For full details see:
% https://groups.yahoo.com/neo/groups/psychtoolbox/conversations/topics/9174
TaskParameters.GUI.backgroundOffsetR = 0.5;
TaskParameters.GUI.backgroundOffsetG = 0.5;
TaskParameters.GUI.backgroundOffsetB = 0.5;
TaskParameters.GUI.backgroundOffsetAlpha = 0.5;
TaskParameters.GUI.disableNorm = 1;
TaskParameters.GUI.preContrastMultiplier = 0.5;
TaskParameters.GUIPanels.Grating = {'gaborSizeFactor','phase','numCycles','sigmaDivFactor','contrast',...
    'grey','aspectRatio','backgroundOffsetR','backgroundOffsetG',...
    'backgroundOffsetB','backgroundOffsetAlpha','disableNorm',...
    'preContrastMultiplier'};
%% Plots
%Show Plots/
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
TaskParameters.GUITabs.Sampling = {'CurrentTrial','LightIntensity','Auditory','Sampling','StimulusSelection'};
TaskParameters.GUITabs.Visual = {'CurrentTrial','VisualGeneral','RandomDots','Grating'};
TaskParameters.GUITabs.Plots = {'ShowPlots','Vevaiometric'};
%%Non-GUI Parameters (but saved)
TaskParameters.Figures.OutcomePlot.Position = [200, 200, 1000, 400];
TaskParameters.Figures.ParameterGUI.Position =  [9, 454, 1474, 562];
TaskParameters.GUI.GUIVer = GUICurVer;
TaskParameters.GUI.ComputerName = 'Unassigned';
end

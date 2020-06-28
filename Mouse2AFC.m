function Mouse2AFC
% 2-AFC  auditory discrimination task implented for Bpod fork https://github.com/KepecsLab/bpod
% This project is available on https://github.com/KepecsLab/BpodProtocols_Olf2AFC/

global BpodSystem
addpath('Definitions');

% Check before overriding TaskParameters
BpodSystem.Data.Custom.IsHomeCage = isfield(BpodSystem.ProtocolSettings, 'HomeCage');
%% Task parameters
global TaskParameters
TaskParameters = BpodSystem.ProtocolSettings;
GUICurVer = 28;
if isempty(fieldnames(TaskParameters))
    TaskParameters = CreateTaskParameters(GUICurVer);
elseif ~isfield(TaskParameters.GUI, 'GUIVer')
    TaskParameters.GUI.GUIVer = 0;
end
if TaskParameters.GUI.GUIVer ~= GUICurVer
    Overwrite = true;
    WriteOnlyNew = ~Overwrite;
    DefaultTaskParameter = CreateTaskParameters(GUICurVer);
    if isfield(TaskParameters.GUI,'OmegaTable')
        TaskParameters.GUI.OmegaTable = ...
            UpdateStructVer(TaskParameters.GUI.OmegaTable,...
                            DefaultTaskParameter.GUI.OmegaTable,...
                            WriteOnlyNew);
    end
    [TaskParameters.GUI.OmegaTable,~] = orderfields(...
               TaskParameters.GUI.OmegaTable, {'Omega','RDK','OmegaProb'});
    TaskParameters.GUI = UpdateStructVer(TaskParameters.GUI,...
                                         DefaultTaskParameter.GUI,WriteOnlyNew);
    TaskParameters.GUIMeta = UpdateStructVer(TaskParameters.GUIMeta,...
                                         DefaultTaskParameter.GUIMeta,Overwrite);
    TaskParameters.GUIPanels = UpdateStructVer(TaskParameters.GUIPanels,...
                                         DefaultTaskParameter.GUIPanels,Overwrite);
    TaskParameters.Figures = UpdateStructVer(TaskParameters.Figures,...
                                         DefaultTaskParameter.Figures,Overwrite);
    % GUITabs are read only, user can't change nothing about them, so just
    % assign them
    TaskParameters.GUITabs = DefaultTaskParameter.GUITabs;
    TaskParameters.GUI.GUIVer = GUICurVer;
end
% Warn the user if the rig we are running on is not the same as the last
% one we ran on.
computerName = getenv('computername');
if strcmp(TaskParameters.GUI.ComputerName, 'Unassigned')
    disp('No computer rig is assigned to this animal. Won''t warn user.');
elseif ~strcmp(TaskParameters.GUI.ComputerName, computerName)
    Opt.Interpreter = 'tex';
    Opt.Default = 'Quit';
    msg = '\fontsize{12}This computer (\bf'+string(computerName)+'\rm) '...
        + 'is not the same last saved computer (\bf'...
        + string(TaskParameters.GUI.ComputerName)+'\rm) that this '...
        + 'animal (\bf'+string(BpodSystem.GUIData.SubjectName)+'\rm) '...
        + 'was running on with this configration (\bf'...
        + string(BpodSystem.GUIData.SettingsFileName)+'\rm).'...
        + '\newline\newline'...
        + 'Continue?';
    answer = questdlg(msg, 'Different training rig detected','Continue',...
        'Quit', Opt);
    if strcmp(answer, 'Quit')
        RunProtocol('Stop');
        return;
    end
end
% Set to nan so user might remember to set it
TaskParameters.GUI.MouseWeight = nan;
TaskParameters.GUI.ComputerName = computerName;
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
BpodSystem.Data.Custom.OptoEnabled_stimulus_delivery = false;
BpodSystem.Data.Custom.Rewarded = false(0);
BpodSystem.Data.Custom.RewardAfterMinSampling = false(0);
BpodSystem.Data.Custom.PreStimCntrReward = [];
BpodSystem.Data.Custom.LightIntensityLeft = [];
BpodSystem.Data.Custom.LightIntensityRight = [];
BpodSystem.Data.Custom.GratingOrientation = [];
% RewardMagnitude is an array of length 2
% TODO: Use an array of 1 and just assign it to the rewarding port
BpodSystem.Data.Custom.RewardMagnitude = TaskParameters.GUI.RewardAmount*[1,1];
BpodSystem.Data.Custom.CenterPortRewAmount =TaskParameters.GUI.CenterPortRewAmount;
BpodSystem.Data.Custom.TrialNumber = [];
BpodSystem.Data.Custom.ForcedLEDTrial = false;
BpodSystem.Data.Custom.CatchCount = zeros(1, 21);
BpodSystem.Data.Custom.LastSuccessCatchTial = 1;
% Setting StartTime to any value, it will be overwritten by the first poke
% in if we are in homecage
BpodSystem.ProtocolSettings.StartTime = posixtime(datetime('now'));

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
        case ExperimentType.GratingOrientation
            DV = CalcGratingOrientation(a);
        case ExperimentType.RandomDots
            DV = CalcDotsCoherence(a);
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
elseif TaskParameters.GUI.ExperimentType == ExperimentType.RandomDots || ...
       TaskParameters.GUI.ExperimentType == ExperimentType.GratingOrientation
        BpodSystem.Data.dotsMapped_file = createMMFile('c:\Bpoduser\', 'mmap_matlab_randomdot.dat', file_size);
        BpodSystem.Data.dotsMapped_file.Data(1:4) = typecast(uint32(0), 'uint8');
end


% Set current stimulus for next trial - set between -100 to +100
TaskParameters.GUI.CurrentStim = iff(BpodSystem.Data.Custom.DV(1) > 0, (BpodSystem.Data.Custom.DV(1) + 1)/0.02,(BpodSystem.Data.Custom.DV(1) - 1)/0.02);

%BpodNotebook('init');
iTrial=0;
sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI, [0]);

%% Main loop
SAVE_EVERY = 20;
shouldSave = false;
RunSession = true;
iTrial = 1;
sleepDur = 0;
trialEndTime = clock;
SettingsPath = BpodSystem.SettingsPath; % Needed later for unsaved changes
% The state-matrix is generated only once in each iteration, however some
% of the trials parameters are pre-generated and updated in the plots few
% iterations before.
tic;
while true
    BpodSystem.Data.Timer.startNewIter(iTrial) = toc; tic;
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    BpodSystem.Data.Timer.SyncGUI(iTrial) = toc; tic;
    sma = stateMatrix(iTrial);
    BpodSystem.Data.Timer.BuildStateMatrix(iTrial) = toc; tic;
    SendStateMatrix(sma);
    BpodSystem.Data.Timer.SendStateMatrix(iTrial) = toc;
    pauseTime = (trialEndTime + sleepDur) - clock();
    if pauseTime > 0
        pause(pauseTime);
    end
    TrialStartSysTime = clock; % Used to aproximate the start time of the
                               % so we can bind trial later to imaging data.
    RawEvents = RunStateMatrix;
    BpodSystem.Data.Custom.TrialStartSysTime(iTrial) = posixtime(...
                                              datetime(TrialStartSysTime));
    trialEndTime = clock;
    if ~isempty(fieldnames(RawEvents))
        tic;
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.TrialSettings(iTrial) = TaskParameters;
        BpodSystem.Data.Timer.AppendData(iTrial) = toc; tic;
    end
    CheckHomeCageStop(BpodSystem);
    if BpodSystem.BeingUsed == 0
        SavedTaskParameters = BpodSystem.ProtocolSettings;
        if ~BpodSystem.Data.Custom.IsHomeCage
            CheckUnsaved(TaskParameters, SavedTaskParameters,...
                         SettingsPath, BpodSystem);
        end
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
        SessionAnalysis(BpodSystem.DataPath);
        return
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    BpodSystem.Data.Timer.HandlePause(iTrial) = toc;
    startTimer = tic;
    updateCustomDataFields(iTrial);
    BpodSystem.Data.Timer.updateCustomDataFields(iTrial) = toc(startTimer); tic;
    sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI, BpodSystem.Data.TrialStartTimestamp);
    BpodSystem.Data.Timer.sendPlotData(iTrial) = toc; tic;
    % Saving takes a lot of time when the number of trial increases. To
    % keep the animal motivated, don't save if the animal got the last
    % trial correctly as they are usually eager to do more trials. Wait for
    % the first mistake where there will be probably a timeout punishment
    % and save.
    if mod(iTrial, SAVE_EVERY) == 0
        shouldSave = true;
    end
    if shouldSave && ~BpodSystem.Data.Custom.Rewarded(iTrial) && ...
       ~BpodSystem.Data.Custom.CatchTrial(iTrial)
        try
            SaveBpodSessionData;
            shouldSave = false;
        catch ME
            warning(datestr(datetime('now')) + ": Failed to save file: " + ME.message);
        end
    end
    BpodSystem.Data.Timer.SaveData(iTrial) = toc; tic;
    iTrial = iTrial + 1;
    if ~TaskParameters.GUI.PCTimeout
        BpodSystem.Data.Timer.calculateTimeout(iTrial-1) = toc;
        continue
    end
    sleepDur = 0;
    statesThisTrial = BpodSystem.Data.RawData.OriginalStateNamesByNumber{iTrial-1}(BpodSystem.Data.RawData.OriginalStateData{iTrial-1});
    if any(strcmp('broke_fixation',statesThisTrial))
        if TaskParameters.GUI.PlayNoiseforError
            if BpodSystem.EmulatorMode == 0
                OverrideMessage = ['VS' uint8(11)];
                BpodSerialWrite(OverrideMessage, 'uint8');
            else
                BpodSystem.VirtualManualOverrideBytes = OverrideMessage;
                BpodSystem.ManualOverrideFlag = 1;
            end
        end
        sleepDur = sleepDur + TaskParameters.GUI.TimeOutBrokeFixation;
    end
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
    BpodSystem.Data.Timer.calculateTimeout(iTrial-1) = toc;
end
sca;
end

function Mouse2AFC
% 2-AFC  auditory discrimination task implented for Bpod fork https://github.com/KepecsLab/bpod
% This project is available on https://github.com/KepecsLab/BpodProtocols_Olf2AFC/

global BpodSystem
addpath('Definitions');

% Save whether it's ver 1 or 2
BpodSystem.SystemSettings.IsVer2 = isprop(BpodSystem, 'FirmwareVersion');
% Check before overriding TaskParameters
BpodSystem.Data.Custom.IsHomeCage = isfield(BpodSystem.ProtocolSettings, 'HomeCage');
%% Task parameters
global TaskParameters
TaskParameters = BpodSystem.ProtocolSettings;
GUICurVer = 32;
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
        + 'animal (\bf'+string(SubjectName(BpodSystem))+'\rm) '...
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

%% Initializing data vectors
PREALLOC_TRIALS = 800;
[BpodSystem.Data.Custom.Trials,...
 BpodSystem.Data.TrialSettings,...
 BpodSystem.Data.Timer] = CreateOrAppendDataArray(PREALLOC_TRIALS,...
                                                  TaskParameters.GUI);

BpodSystem.Data.Custom.DVsAlreadyGenerated = 0;
BpodSystem.Data.Custom.CatchCount = zeros(1, 21);
BpodSystem.Data.Custom.LastSuccessCatchTial = 1;
% Setting StartTime to any value, it will be overwritten by the first poke
% in if we are in homecage
BpodSystem.ProtocolSettings.StartTime = posixtime(datetime('now'));

file_size = 120*1024*1024; % 40 MB mem-mapped file
mapped_file = createMMFile(tempdir, 'mmap_matlab_plot.dat', file_size);

% make auditory stimuli for first trials
for a = 1:Const.NUM_EASY_TRIALS
    if TaskParameters.GUI.StimulusSelectionCriteria == StimulusSelectionCriteria.BetaDistribution
        % This random value is between 0 and 1, the beta distribution
        % parameters makes it very likely to very close to zero or very
        % close to 1.
        BpodSystem.Data.Custom.Trials(a).StimulusOmega = betarnd(TaskParameters.GUI.BetaDistAlphaNBeta/4,TaskParameters.GUI.BetaDistAlphaNBeta/4,1,1);
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
    BpodSystem.Data.Custom.Trials(a).StimulusOmega = Intensity;

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
        BpodSystem.Data.Custom.Trials(a).LeftRewarded = 1;
    elseif DV < 0
        BpodSystem.Data.Custom.Trials(a).LeftRewarded = 0;
    else
        BpodSystem.Data.Custom.Trials(a).LeftRewarded = rand<0.5; % It's equal distribution
    end
    % cross-modality difficulty for plotting
    BpodSystem.Data.Custom.Trials(a).DV = DV;
    BpodSystem.Data.Custom.DVsAlreadyGenerated = ...
                            BpodSystem.Data.Custom.DVsAlreadyGenerated + 1;
end%for a+1:2
% Bpod will provide feedback that we can useto trigger pulse pal

BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

%server data
[~,BpodSystem.Data.Custom.Rig] = system('hostname');
BpodSystem.Data.Custom.Subject = SubjectName(BpodSystem);

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
        BpodSystem.SystemSettings.dotsMapped_file =...
            createMMFile('c:\Bpoduser\', 'mmap_matlab_randomdot.dat', file_size);
        BpodSystem.SystemSettings.dotsMapped_file.Data(1:4) =...
                                                    typecast(uint32(0), 'uint8');
end


% Set current stimulus for next trial - set between -100 to +100
TaskParameters.GUI.CurrentStim = iff(BpodSystem.Data.Custom.Trials(1).DV > 0, (BpodSystem.Data.Custom.Trials(1).DV + 1)/0.02,(BpodSystem.Data.Custom.Trials(1).DV - 1)/0.02);

%BpodNotebook('init');
iTrial=0;
dataPath = DataPath(BpodSystem);
%sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI,...
%[0], dataPath);

%% Main loop
SAVE_EVERY = 20;
shouldSave = false;
RunSession = true;
iTrial = 1;
sleepDur = 0;
trialEndTime = clock;
SettingsPath_ = SettingsPath(BpodSystem); % Needed later for unsaved changes
% The state-matrix is generated only once in each iteration, however some
% of the trials parameters are pre-generated and updated in the plots few
% iterations before.
load('C:\Users\hatem\OneDrive\Documents\py_matlab\Thy1-1_Mouse2AFC_Oct15_2020_Session2.mat');
TrialTotalTime = clock();
tic;
while true
    BpodSystem.Data.Timer(iTrial).startNewIter = toc; tic;
    TaskParameters = BpodParameterGUI('sync', TaskParameters);
    BpodSystem.Data.Timer(iTrial).SyncGUI = toc; tic;
    sma = stateMatrix(iTrial);
    BpodSystem.Data.Timer(iTrial).BuildStateMatrix = toc; tic;
    SendStateMatrix(sma);
    BpodSystem.Data.Timer(iTrial).SendStateMatrix = toc;
    pauseTime = sleepDur + seconds(datetime(trialEndTime) - datetime('now'));
    if pauseTime > 0
        pause(pauseTime);
    end
    BpodSystem.Data.Timer(iTrial).TrialTotalTime = seconds(datetime('now') - datetime(TrialTotalTime));
    TrialStartSysTime = clock; % Used to aproximate the start time of the
                               % so we can bind trial later to imaging data.
    RawEvents = SessionData.RawEvents.Trial(iTrial); %RawEvents = RunStateMatrix;
    TrialTotalTime = clock();
    BpodSystem.Data.Custom.Trials(iTrial).TrialStartSysTime = posixtime(...
                                              datetime(TrialStartSysTime));
    trialEndTime = clock;
    if true%~isempty(fieldnames(RawEvents))
        tic;
        % BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);
        BpodSystem.Data.RawEvents.Trial(iTrial) = SessionData.RawEvents.Trial(iTrial);
        BpodSystem.Data.RawData.OriginalStateNamesByNumber(iTrial) = SessionData.RawData.OriginalStateNamesByNumber(iTrial);
        BpodSystem.Data.RawData.OriginalStateData(iTrial) = SessionData.RawData.OriginalStateData(iTrial);
        BpodSystem.Data.RawData.OriginalEventData(iTrial) = SessionData.RawData.OriginalEventData(iTrial);
        BpodSystem.Data.RawData.OriginalStateTimestamps(iTrial) = SessionData.RawData.OriginalStateTimestamps(iTrial);
        BpodSystem.Data.RawData.OriginalEventTimestamps(iTrial) = SessionData.RawData.OriginalEventTimestamps(iTrial);
        BpodSystem.Data.TrialStartTimestamp(iTrial) = SessionData.TrialStartTimestamp(iTrial);
        if iTrial == SessionData.nTrials - 1
            if BpodSystem.SystemSettings.IsVer2
                BpodSystem.Status.BeingUsed = 0;
            else
                BpodSystem.BeingUsed = 0;
            end
        end
        TaskParameters = SessionData.TrialSettings(iTrial);
        BpodSystem.Data.TrialSettings(iTrial) = TaskParameters.GUI;
        BpodSystem.Data.Timer(iTrial).AppendData = toc; tic;
    end
    CheckHomeCageStop(BpodSystem);
    if BpodBeingUsed(BpodSystem) == 0
        SavedTaskParameters = BpodSystem.ProtocolSettings;
        if ~BpodSystem.Data.Custom.IsHomeCage
            CheckUnsaved(TaskParameters, SavedTaskParameters,...
                         SettingsPath_, BpodSystem);
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
        SessionAnalysis(dataPath);
        return
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    BpodSystem.Data.Timer(iTrial).HandlePause = toc;
    startTimer = tic;
    updateCustomDataFields(iTrial);
    BpodSystem.Data.Timer(iTrial).updateCustomDataFields = toc(startTimer); tic;
    sendPlotData(mapped_file, iTrial, BpodSystem.Data,...
                 BpodSystem.ProtocolSettings.StartTime, dataPath);
    BpodSystem.Data.Timer(iTrial).sendPlotData = toc; tic;
    % Saving takes a lot of time when the number of trial increases. To
    % keep the animal motivated, don't save if the animal got the last
    % trial correctly as they are usually eager to do more trials. Wait for
    % the first mistake where there will be probably a timeout punishment
    % and save.
    if mod(iTrial, SAVE_EVERY) == 0
        shouldSave = true;
    end
    if shouldSave && ~BpodSystem.Data.Custom.Trials(iTrial).Rewarded && ...
       ~BpodSystem.Data.Custom.Trials(iTrial).CatchTrial
        try
            % SaveBpodSessionData;
            shouldSave = false;
        catch ME
            warning(datestr(datetime('now')) + ": Failed to save file: " + ME.message);
        end
    end
    BpodSystem.Data.Timer(iTrial).SaveData = toc; tic;
    if iTrial + 10 > size(BpodSystem.Data.Custom.Trials, 2) % We can use the value of pregen, but just in case
        [Trials, TrialSettings, Timer] = CreateOrAppendDataArray(...
                                      PREALLOC_TRIALS, TaskParameters.GUI);
        BpodSystem.Data.Custom.Trials = [BpodSystem.Data.Custom.Trials, Trials];
        BpodSystem.Data.TrialSettings = [BpodSystem.Data.TrialSettings, TrialSettings];
        BpodSystem.Data.Timer = [BpodSystem.Data.Timer, Timer];
        clear Trials TrialSettings Timer;
    end
    iTrial = iTrial + 1;
    if ~TaskParameters.GUI.PCTimeout
        BpodSystem.Data.Timer(iTrial-1).calculateTimeout = toc;
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
    BpodSystem.Data.Timer(iTrial-1).calculateTimeout = toc;
end
sca;
end

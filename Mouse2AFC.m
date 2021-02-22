function Mouse2AFC
% 2-AFC  auditory discrimination task implented for Bpod fork https://github.com/KepecsLab/bpod
% This project is available on https://github.com/KepecsLab/BpodProtocols_Olf2AFC/

global BpodSystem
addpath('Definitions');

% Save whether it's ver 1 or 2
BpodSystem.SystemSettings.IsVer2 = isprop(BpodSystem, 'FirmwareVersion');
% Check before overriding TaskParameters
BpodSystem.Data.Custom.IsHomeCage = isfield(BpodSystem.ProtocolSettings, 'HomeCage');

% Temp hack to deploy 2 versions of Mouse2AFC (the second protocol name is
% Mouse2AFC2)
if BpodSystem.SystemSettings.IsVer2
    BpodSystem.Path.CurrentDataFile = strrep(BpodSystem.Path.CurrentDataFile,...
                                             'Mouse2AFC2', 'Mouse2AFC');
else
    BpodSystem.DataPath = strrep(BpodSystem.DataPath, 'Mouse2AFC2', 'Mouse2AFC');
end

dataPath = DataPath(BpodSystem);
%server data
[~,BpodSystem.Data.Custom.Rig] = system('hostname');
BpodSystem.Data.Custom.Subject = SubjectName(BpodSystem);
% Check if there are any unusaved data from the previous run.
Quit = CheclOldIncompleteSaves(SubjectName(BpodSystem), dataPath);
if Quit
    return
end
%% Task parameters
global TaskParameters
TaskParameters = BpodSystem.ProtocolSettings;
[TaskParameters, Quit] = InitTaskParameters(TaskParameters,...
            BpodSystem.Data.Custom.Subject, BpodSystem.GUIData.SettingsFileName);
if Quit
    return
end

%% Initializing data vectors
PREALLOC_TRIALS = 800;
[BpodSystem.Data.Custom.Trials,...
 BpodSystem.Data.TrialSettings,...
 BpodSystem.Data.Timer] = CreateOrAppendDataArray(PREALLOC_TRIALS,...
                                                  TaskParameters.GUI);

BpodSystem.Data.Custom.DVsAlreadyGenerated = 0;
BpodSystem.Data.Custom.CatchCount = zeros(1, 21);
BpodSystem.Data.Custom.LastSuccessCatchTial = 1;
BpodSystem.Data.Custom.BlocksInfo.CurBlkStart = 1;
BpodSystem.Data.Custom.BlocksInfo.NextSwitchAt = 0; % Force block calculation
% Setting StartTime to any value, it will be overwritten by the first poke
% in if we are in homecage
BpodSystem.ProtocolSettings.StartTime = posixtime(datetime('now'));

file_size = 120*1024*1024; % 40 MB mem-mapped file
mapped_file = createMMFile(tempdir, 'mmap_matlab_plot.dat', file_size);
% Setup the memory mapped file anyway for visual stimulus, even if it's not the
% primary stimulus, the user might set it up as the secondary stimulus later
BpodSystem.SystemSettings.dotsMapped_file =...
            createMMFile('c:\Bpoduser\', 'mmap_matlab_randomdot.dat', file_size);
% Should we always force initilization of screen to zero as we have here?
BpodSystem.SystemSettings.dotsMapped_file.Data(1:4) = typecast(uint32(0),...
                                                               'uint8');

%CurTimer.customPrepNewTrials = toc; tic;
StartFrom = 1;
[NextTrialBlockNum, LeftBias, ~, ~,BpodSystem.Data.Custom.BlocksInfo,...
 TaskParameters.GUI.Block] = CalcBlockInfo(TaskParameters.GUI, StartFrom,...
                                           BpodSystem.Data.Custom.Trials,...
                                           BpodSystem.Data.Custom.BlocksInfo);
NumTrialsToGenerate = 1;
[BpodSystem.Data.Custom.Trials,...
 BpodSystem.Data.Custom.DVsAlreadyGenerated] = AssignFutureTrials(...
    BpodSystem.Data.Custom.Trials, TaskParameters.GUI, StartFrom,...
    NumTrialsToGenerate, LeftBias);
IsLastTrialRewarded = false;
[BpodSystem.Data.Custom.Trials(1), TaskParameters.GUI,...
 BpodSystem.Data.Timer(1)] = GenNextTrial(BpodSystem.Data.Custom.Trials(1),...
            StartFrom,...
            TaskParameters.GUI, TaskParameters.GUI.ExperimentType,...
            TaskParameters.GUI.SecExperimentType, BpodSystem.Data.Timer(1),...
            BpodSystem.Data.Custom.LastSuccessCatchTial,...
            BpodSystem.Data.Custom.CatchCount, IsLastTrialRewarded,...
            NextTrialBlockNum);
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler';

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
TaskParameters.GUI.CurrentStim = iff(BpodSystem.Data.Custom.Trials(1).DV > 0, (BpodSystem.Data.Custom.Trials(1).DV + 1)/0.02,(BpodSystem.Data.Custom.Trials(1).DV - 1)/0.02);

%BpodNotebook('init');
iTrial=0;
%sendPlotData(mapped_file,iTrial,BpodSystem.Data.Custom,TaskParameters.GUI,...
%[0], dataPath);

%% Main loop
RunSession = true;
iTrial = 1;
sleepDur = 0;
trialEndTime = clock;
SettingsPath_ = SettingsPath(BpodSystem); % Needed later for unsaved changes
% The state-matrix is generated only once in each iteration, however some
% of the trials parameters are pre-generated and updated in the plots few
% iterations before.
load('C:\Users\hatem\OneDrive\Documents\py_matlab\HomeCageHabutate_Mouse2AFC_Jul24_2020_Session3.mat');
computerName = getenv('computername');
xTaskParameters = struct;
xTaskParameters.IgnoreInit = true;
xTaskParameters.GUIMeta = TaskParameters.GUIMeta;
xTaskParameters.GUIPanels = TaskParameters.GUIPanels;
xTaskParameters.Figures = TaskParameters.Figures;
OrigTrialSettings = BpodSystem.Data.TrialSettings;
for i = 1:length(SessionData.TrialSettings)
    xTaskParameters.GUI = SessionData.TrialSettings(i);
    xTaskParameters.GUI.ComputerName = computerName;
    xTaskParameters.GUI.OmegaTable = TaskParameters.GUI.OmegaTable;
    xTaskParameters = InitTaskParameters(xTaskParameters,...
        SessionData.Custom.Subject, SessionData.Filename);
    % This is necessary, otherwise assignment fails because they have
    % different lengths
    BpodSystem.Data.TrialSettings(i) = xTaskParameters.GUI;
end
SessionData.TrialSettings =...
              BpodSystem.Data.TrialSettings(1:length(SessionData.TrialSettings));
BpodSystem.Data.TrialSettings = OrigTrialSettings;
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
        TaskParameters.GUI = SessionData.TrialSettings(iTrial);
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

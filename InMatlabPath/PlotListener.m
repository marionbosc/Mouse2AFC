function PlotListener()
global BpodSystem % A hack to convince bpod save function to save
BpodSystem = struct;

PREALLOC_TRIALS = 800;
last_updateTime = 0;
last_SessStartTime = 0;
SaveEveryNumTrials = 5;
nextSaveAt = SaveEveryNumTrials; % Will be overridden on new sessions
nextExpandAt = PREALLOC_TRIALS; % Will be overridden on new session

file_size = 120*1024*1024; % 40 MB mem-mapped file
m_data = createMMFile(tempdir, 'mmap_matlab_plot.dat', file_size);
m_read = createMMFile(tempdir, 'mmap_matlab_plot_read.dat', 8+8+4+4);
m_read.Data(17:20) = typecast(uint32(0), 'uint8'); %iTrial
m_read.Data(21:24) = typecast(uint32(0), 'uint8'); %Flag not reading

should_initialize = false;
while true
    sessStartTime = typecast(m_data.Data(1:8), 'double');
    updateTime = typecast(m_data.Data(9:16), 'double');
    % Regardless of what happens, report our last check time as a heartbeat
    % for the other app.
    m_read.Data(1:8) = typecast(posixtime(datetime('now')), 'uint8');
    m_read.Data(9:16) = typecast(last_SessStartTime, 'uint8');
    if updateTime == last_updateTime
        pause(.1);
    else
        tic;
        last_updateTime = updateTime;
        m_read.Data(21:24) = typecast(uint32(1), 'uint8');
        try
            [next_data_start, newData] = loadSerializedData(m_data, 17);
            %[next_data_start, TaskParametersGUI] = loadSerializedData(m, next_data_start);
            %[next_data_start, TrialStartTimestamp] = loadSerializedData(m, next_data_start);
        catch ME
            warning(strcat("Error during last read: " + getReport(ME)));
        end
        m_read.Data(21:24) = typecast(uint32(0), 'uint8');
        deserialize_dur = toc;
        fprintf('Took %.3fs to deserialize string\n', deserialize_dur);
        if last_SessStartTime ~= sessStartTime
            if newData.startTrial ~= 1
                % Maybe it was remains of the last session?
                % Do nothing, wait for the server to send us from trial 1
                %last_check_time = posixtime(datetime('now'));
                %m_read.Data(1:8) = typecast(last_check_time, 'uint8');
                pause(.2);
                continue;
            end
            fprintf('Found New  session @trial: %d\n', newData.startTrial);
            last_SessStartTime = sessStartTime;
            SessionData = struct;
            TaskParameters_GUI = struct;
            TaskParameters_GUI.CenterPortRewAmount = NaN;
            TaskParameters_GUI.RewardAmount = NaN;
            [SessionData.Custom.Trials,...
             SessionData.TrialSettings,...
             SessionData.Timer] = CreateOrAppendDataArray(...
                                      PREALLOC_TRIALS, TaskParameters_GUI);
            % The handling of TaskParameters is a badhack, fix it properly
            SessionData = rmfield(SessionData,'TrialSettings'); 
            nextSaveAt = SaveEveryNumTrials;
            nextExpandAt = PREALLOC_TRIALS;
            should_initialize = true;
        end
        fprintf('Received start trial: %d\n', newData.startTrial);
        SessionData = recursiveAssign(SessionData, newData, newData.startTrial);
        iTrial = max([SessionData.Custom.Trials.TrialNumber]);

        if should_initialize % First run
            % TODO: We can just replicate here the unused slots of 
            % TaskParameters up to the PREALLOC_TRIALS with NaN values.
            % TODO: See if you need to disable the graphs again
            GUIHandles = initializeFigures();
            GUIHandles.OutcomePlot = MainPlot2(GUIHandles.OutcomePlot,'init',...
                SessionData.Custom, SessionData.TrialSettings(iTrial),...
                SessionData.TrialStartTimestamp(1:iTrial));
            should_initialize = false;
            SessionData.TrialSettings(iTrial+1:PREALLOC_TRIALS) =...
                                               SessionData.TrialSettings(iTrial);
            % if ~initialized_before and iTrial ~= 0, then the loop will
            % repeate again now and will go to the else part
        end
        
        GUIHandles.OutcomePlot = MainPlot2(GUIHandles.OutcomePlot,'update',...
            SessionData.Custom, SessionData.TrialSettings(iTrial),...
            SessionData.TrialStartTimestamp(1:iTrial), iTrial);
        drawnow;
        m_read.Data(17:20) = typecast(uint32(iTrial), 'uint8');
        fprintf('Last reported trial is %d at time %d\n', iTrial,...
            last_updateTime);
        if iTrial >= nextSaveAt
            fprintf('Saving at Trial #%d\n', iTrial);
            BpodSystem.Data = SessionData;
            % Assign twice for Bpod Gen1 & Gen2 save functions
            BpodSystem.DataPath = SessionData.DataPath;
            BpodSystem.Path.CurrentDataFile = SessionData.DataPath;
            BpodSystem.Data = rmfield(BpodSystem.Data,'startTrial');
            BpodSystem.Data = rmfield(BpodSystem.Data,'DataPath');
            SaveBpodSessionData;
            BpodSystem = struct;
            nextSaveAt = nextSaveAt + SaveEveryNumTrials;
        end
        if iTrial > nextExpandAt
            fprintf('Expanding arrays\n');
            [Trials, TrialSettings, Timer] = CreateOrAppendDataArray(...
                             PREALLOC_TRIALS, SessionData.TrialSettings(iTrial));
            SessionData.Custom.Trials = [SessionData.Custom.Trials, Trials];
            SessionData.TrialSettings = [SessionData.TrialSettings,...
                                         TrialSettings];
            SessionData.Timer = [SessionData.Timer, Timer];
            nextExpandAt = numel(SessionData.Custom.Trials);
            fprintf('Next expansion at: %d\n', nextExpandAt);
            clear Trials TrialSettings Timer;
        end 
    end
    %pause(0.01); % Give a chance to render
end
end

function GUIHandles = initializeFigures()
close all;
Figures.OutcomePlot.Position = [200, 200, 1000, 400];
Figures.ParameterGUI.Position =  [9, 454, 1474, 562];

ProtocolFigures.SideOutcomePlotFig = figure('Position', Figures.OutcomePlot.Position,'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
GUIHandles.OutcomePlot.HandleOutcome = axes('Position',    [  .055          .15 .91 .3]);
GUIHandles.OutcomePlot.HandlePsycStim = axes('Position',    [2*.05 + 1*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleTrialRate = axes('Position',  [3*.05 + 2*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleFix = axes('Position',        [4*.05 + 3*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleST = axes('Position',         [5*.05 + 4*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleFeedback = axes('Position',   [6*.05 + 5*.08   .6  .1  .3], 'Visible', 'off');
GUIHandles.OutcomePlot.HandleVevaiometric = axes('Position',   [7*.05 + 6*.08   .6  .1  .3], 'Visible', 'off');
end

function struct_dst = recursiveAssign(struct_dst, struct_src, start_cpy_idx)
fn_src = fieldnames(struct_src);
for k=1:numel(fn_src)
    this_fn_src = fn_src{k};
    if size(struct_dst, 2) > 1
        field_src = [struct_src.(this_fn_src)];
    else
        field_src = struct_src.(this_fn_src);
    end
    if ~isfield(struct_dst, this_fn_src)
        struct_dst.(this_fn_src) = field_src;
    else
        if size(struct_dst, 2) > 1
            field_dst = [struct_dst.(this_fn_src)];
            has_sz = true;
        else
            field_dst = struct_dst.(this_fn_src);
            has_sz = false;
        end
%         if isstruct(field_dst)
%             field_dst = field_dst{1};
%         end
%         dst_sz = size(field_dst);
        if isnumeric(field_dst) || iscell(field_dst)
            sz = size(field_src);
            if has_sz
                struct_dst(start_cpy_idx:start_cpy_idx+sz-1).(this_fn_src) = field_src;
            else
                if any(sz == 1) && any(sz > 1)
                    dm = sz > 1;
                    field_dst(start_cpy_idx:start_cpy_idx+sz(dm)-1) = field_src;
                else
                    field_dst = field_src;
                end
                struct_dst.(this_fn_src) = field_dst;
            end
        elseif isstruct(field_dst)
            % TODO: Here we also need to handle multi-dims
            if size(field_dst, 2) > 1
                sz_2 = size(field_src, 2);
                field_dst(start_cpy_idx:start_cpy_idx+sz_2-1) = field_src;
                struct_dst.(this_fn_src) = field_dst;
            else
                struct_dst.(this_fn_src) = recursiveAssign(field_dst,...
                                                 field_src, start_cpy_idx);
            end
        end
    end
end
end
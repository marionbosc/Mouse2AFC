function sendPlotData (mappedFile, iTrial, bpodData, sessStartTime, dataPath)
% The mapped file structure is as follows:
% byte 1 -> 4: iTrial number encoded as uint32
% byte 5 -> 8: Size of Bpod.Data.Custom struct encoded as uint32, call it x
% byte 9 -> 9 + x: the serialzed data of Bpod.Data.Custom
% let 9 + x + 1 = i
% byte i: i + 3: Size of TaskParameters.GUI, call it y
% byte i + 4: i + 4 + y: Serialized data of TaskParameters.GUI
% let i + y + 1 = j
% byte j -> j + 3: serialized TrialStartTimestamp array size, call it z
% byte j + 4 -> j + 4 + z: serialized TrialStartTimestamp array
    mappedFile.Data(1:8) = typecast(sessStartTime, 'uint8');

    waitMmapFile = createMMFile(tempdir, 'mmap_matlab_plot_read.dat', 8+8+4+4);
    lastCheck = typecast(waitMmapFile.Data(1:8),'double');
    if (isnan(lastCheck) || (posixtime(datetime('now')) - lastCheck > 10))...
       && iTrial ~= 1
       return
    end
    listenerCurSessTime = typecast(waitMmapFile.Data(9:16),'double');
    plottedTrial = typecast(waitMmapFile.Data(17:20),'uint32');
    fprintf('Listener originally reported: %d\n', plottedTrial);
    msg = struct;
    if listenerCurSessTime ~= sessStartTime || iTrial == 1 || plottedTrial <= 1
        plottedTrial = 1;
        first_send = true;
        msg.DataPath = dataPath;
    else
        first_send = false;
    end
%     msg = bpod_data;
%     msg = rmfield(msg, 'dotsMapped_file');
%     msg.Custom = rmfield(msg.Custom, 'CatchCount');
%     msg.Custom = rmfield(msg.Custom, 'drawParams');
    function struct_dst = recursiveCopy(struct_dst, struct_src, lvl)
    fn = fieldnames(struct_src);
    for k=1:numel(fn)
        this_fn = fn{k};
        % if lvl == 1
        %     fprintf('Processing:%s\n', this_fn);
        % end
        if strcmp(this_fn,'dotsMapped_file') || strcmp(this_fn,'CatchCount')...
           || strcmp(this_fn,'drawParams') || strcmp(this_fn,'BlocksInfo')
            continue;
        elseif ~first_send && (strcmp(this_fn,'Protocol') ||...
           strcmp(this_fn,'Subject') ||...
           strcmp(this_fn,'PulsePalParamFeedback') || strcmp(this_fn,'Rig'))
            continue
        elseif strcmp(this_fn,'PulsePalParamStimulus') && ...
           bpodData.TrialSettings(1).ExperimentType ~= ExperimentType.Auditory
            continue
        end
        field = struct_src.(this_fn);
        sz = size(field);
        % I don't know how to handle multi-dimension fields except to take
        % them as they are. The code should be adapted as needed.
        % If one dimension is bigger than one, either col-wise or row-wise
        if any(sz == 1) && any(sz > 1) && ~ischar(field) && ~isstring(field)
            dm = sz > 1;
            limit_max = min(sz(dm), bpodData.Custom.DVsAlreadyGenerated);
            field = field(plottedTrial:limit_max);
            struct_dst.(this_fn) = field;
        elseif isstruct(field)
            struct_dst.(this_fn) = struct;
            struct_dst.(this_fn) = recursiveCopy(struct_dst.(this_fn), field,...
                                                 lvl+1);
        else
            struct_dst.(this_fn) = field;
        end
    end
    end
    msg = recursiveCopy(msg, bpodData, 1); % i.e BpodSystem.Data

%     if ~(plottedTrial <= 1 || plottedTrial > iTrial) % Don't send old info
%        msg = rmfield(msg, 'Protocol');
       %msg = rmfield(msg, 'Filename'); % PlotListener needs this field
       %msg = rmfield(msg, 'TrialSettings');
%        msg.Custom = rmfield(msg.Custom, 'Rig');
%        msg.Custom = rmfield(msg.Custom, 'Subject');
%        msg.Custom = rmfield(msg.Custom, 'PulsePalParamFeedback');
%     else
%        plottedTrial = 1;
%     end
%     if bpod_data.TrialSettings(1).ExperimentType ~= ExperimentType.Auditory
%         msg.Custom = rmfield(msg.Custom, 'PulsePalParamStimulus');
% %     end
%     function struct_ = recurseLimit(struct_)
%     fn = fieldnames(struct_);
%     for k=1:numel(fn)
%         this_fn = fn{k};
%         field = struct_.(this_fn);
%         sz = size(field, 2);
%         if sz > 1 && ~ischar(field) && ~isstring(field)
%             limit_max = min(sz, msg.Custom.DVsAlreadyGenerated);
%             field = field(plottedTrial:limit_max);
%             struct_.(this_fn) = field;
%         elseif isstruct(field)
%             struct_.(this_fn) = recurseLimit(field);
%         end
%     end
%     end
    %msg = recurseLimit(msg);
    msg.startTrial = plottedTrial;
    fprintf('Sending from start trial: %d to iTrial: %d\n', msg.startTrial, iTrial);
    %bpod_data.Custom.Trials = bpod_data.Custom.Trials(1:bpod_data.Custom.DVsAlreadyGenerated);
    %bpod_data.Timer = bpod_data.Timer(1:iTrial); %TOOD: Use iTrial
    next_data_start = serializeAndWrite(mappedFile, 17, msg, waitMmapFile, 21);
    %next_data_start = serializeAndWrite(mapped_file, next_data_start,...
    %                                    task_parameters_gui, wait_mmap_file);
    %serializeAndWrite(mapped_file, next_data_start, trial_start_timestamp);
    % Write iTrial last so that only the listener would start reading the
    % data after we've processed it
    % mappedFile.Data(1:4) = typecast(uint32(iTrial), 'uint8')
    mappedFile.Data(9:16) = typecast(posixtime(datetime('now')), 'uint8');
end

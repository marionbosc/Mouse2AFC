function Quite = CheclOldIncompleteSaves(SubjectName, SessionDataPath)
% PlotListener saves mid-session states as temp_{normal session name).mat
% If this trial finished successfully on the last run, then the whole file
% would exist, and we should delete the temp file. If Bpod crashed for some
% reason, then we should convert the temp file to a full non-temp file.
[cur_dir, cur_file] = fileparts(SessionDataPath);
if ~endsWith(cur_file, ".mat")
    cur_file = strcat(cur_file, '.mat');
end
all_sessions = dir(strcat(cur_dir, filesep, SubjectName, '*.mat'));
complete_sessions_names = {all_sessions(:).name};
all_temp = dir(strcat(cur_dir, filesep, 'temp_', SubjectName, '*.mat'));
Quite = false;
for i = 1:length(all_temp)
    temp_sess_name = all_temp(i).name;
    orig_session_name = temp_sess_name(6:end);
    if strcmp(cur_file, orig_session_name)
        old_fp = strcat(all_temp(i).folder, filesep, temp_sess_name);
        new_fp = strcat(all_temp(i).folder, filesep, orig_session_name);
        fprintf('Found recent unrecovered session: %s\n', old_fp);
        fprintf('Renaming unrecovered session to: %s\n', new_fp);
        movefile(old_fp, new_fp);
        tex_escp = strrep(temp_sess_name,'_','\_');
        msg = sprintf(['\\fontsize{12}Found recent unrecovered session ',...
              '(\\bf%s\\rm) that was probably created due ',...
              'to previous session of this animal not terminating properly. ',...
              'That old session has been recovered, but to avoid this ',...
              'overwriting that old session, you should restart this ',...
              'protocol.\nWe will now quit this session, sorry...'], tex_escp);
        Opt.Interpreter = 'tex';
        Opt.WindowStyle = 'modal';
        msgbox(msg, 'Need to restart...', 'warn', Opt);
        RunProtocol('Stop');
        Quite = true;
        return
    end
    if any(ismember(complete_sessions_names, orig_session_name))
        fprintf('Complete session found for: %s\n', orig_session_name);
        fprintf('Deleting its old temp save: %s\n', temp_sess_name);
        delete(strcat(all_temp(i).folder, filesep, temp_sess_name));
    else
        old_fp = strcat(all_temp(i).folder, filesep, temp_sess_name);
        new_fp = strcat(all_temp(i).folder, filesep, orig_session_name);
        fprintf(['Renaming and using unfinalized session %s as final ',...
                'session %s\n'], old_fp, new_fp);
        movefile(old_fp, new_fp);
    end
end
end

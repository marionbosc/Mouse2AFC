function [TaskParameters, Quit] = InitTaskParameters(TaskParameters,...
                                                  SubjectName_, SettingsFileName)
GUICurVer = 35;
Quit = false;
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
    OldConfigName = strrep(SettingsFileName,'\','\\\\');
    msg = '\\fontsize{12}This computer (\\bf'+string(computerName)+'\\rm) '...
        + 'is not the same last saved computer (\\bf'...
        + string(TaskParameters.GUI.ComputerName)+'\\rm) that this '...
        + 'animal (\\bf'+string(SubjectName_)+'\\rm) '...
        + 'was running on with this configration (\\bf'+OldConfigName+'\\rm).'...
        + '\n\n'...
        + 'Continue?';
    answer = questdlg(sprintf(msg), 'Different training rig detected',...
        'Continue', 'Quit', Opt);
    if strcmp(answer, 'Quit')
        RunProtocol('Stop');
        Quit = true;
        return;
    end
end
% Set to nan so user might remember to set it
TaskParameters.GUI.MouseWeight = nan;
TaskParameters.GUI.ComputerName = computerName;
BpodParameterGUI('init', TaskParameters);
end

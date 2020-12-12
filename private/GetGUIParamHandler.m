function Handler = GetGUIParamHandler(TaskParameterGUIName)
% A helper function that gets the gui handler from the GUI name
% Usage e.g:
% GetGUIParamHandler('TaskParameters.GUI.Ports_LMR')
% Returns the gui handler for TaskParameters.GUI.Ports_LMR
global BpodSystem
LastName = strsplit(TaskParameterGUIName, '.');
LastName = LastName(end);
HandlerIdx = find(strcmp(BpodSystem.GUIData.ParameterGUI.ParamNames, LastName), 1);
if BpodSystem.SystemSettings.IsVer2
    Handler = BpodSystem.GUIHandles.ParameterGUI.Params(HandlerIdx);
else
    Handler = BpodSystem.GUIHandles.ParameterGUI.Params{HandlerIdx};
end
end
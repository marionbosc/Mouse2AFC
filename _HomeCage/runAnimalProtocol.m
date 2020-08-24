function runAnimalProtocol(SubjectName,ProtocolName,SettingsFileName,...
                           HomeCage)
global BpodSystem
%SubjectName = 'Dummy Subject'
%SettingsFileName = 'Default Settings';
% ProtocolName = 'Mouse2AFC';
BpodSystem.SystemSettings.IsVer2 = isprop(BpodSystem, 'FirmwareVersion');
if BpodSystem.SystemSettings.IsVer2
    BpodSystem.Status.CurrentProtocolName = ProtocolName;
    BpodUserPath = fileparts(fileparts(BpodSystem.Path.DataFolder));
else
    BpodSystem.CurrentProtocolName = ProtocolName;
    BpodUserPath = BpodSystem.BpodUserPath;
end

FormattedDate = [datestr(now, 3) datestr(now, 7) '_' datestr(now, 10)];
DataFolder = fullfile(BpodUserPath,'Data',SubjectName,ProtocolName,'Session Data');
Candidates = dir(DataFolder);
nSessionsToday = 0;
for x = 1:length(Candidates)
	if x > 2
		if strfind(Candidates(x).name, FormattedDate)
			nSessionsToday = nSessionsToday + 1;
		end
	end
end
DataPath = fullfile(BpodUserPath,'Data',SubjectName,ProtocolName,'Session Data',[SubjectName '_' ProtocolName '_' FormattedDate '_Session' num2str(nSessionsToday+1) '.mat']);
SettingsPath = fullfile(BpodUserPath,'Data',SubjectName,ProtocolName, 'Session Settings',[SettingsFileName '.mat']);
ProtocolPath = fullfile(BpodUserPath,'Protocols',ProtocolName,[ProtocolName '.m']);
if BpodSystem.SystemSettings.IsVer2
    BpodSystem.Path.CurrentDataFile = DataPath;
    BpodSystem.Path.Settings = SettingsPath;
else
    BpodSystem.DataPath = DataPath;
    BpodSystem.SettingsPath = SettingsPath;
    BpodSystem.Live = 1;
end
BpodSystem.GUIData.ProtocolName = ProtocolName;
BpodSystem.GUIData.SubjectName = SubjectName;
BpodSystem.GUIData.SettingsFileName = SettingsFileName;
SettingStruct = load(SettingsPath);
F = fieldnames(SettingStruct);
FieldName = F{1};
BpodSystem.ProtocolSettings = eval(['SettingStruct.' FieldName]);
BpodSystem.ProtocolSettings.HomeCage = HomeCage;
BpodSystem.Data = struct;
addpath(ProtocolPath);
if BpodSystem.SystemSettings.IsVer2
   set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
   BpodSystem.Status.BeingUsed = 1;
   figure(BpodSystem.GUIHandles.MainFig);
else
   set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.Graphics.PauseButton, 'TooltipString', 'Press to pause session');
   BpodSystem.BeingUsed = 1;
end
BpodSystem.ProtocolStartTime = now*100000;
run(ProtocolPath);
end
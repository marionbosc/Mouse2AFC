function runAnimalProtocol(SubjectName,ProtocolName,SettingsFileName,...
                           HomeCage)
global BpodSystem
%SubjectName = 'Dummy Subject'
%SettingsFileName = 'Default Settings';
% ProtocolName = 'Mouse2AFC';
BpodSystem.CurrentProtocolName = ProtocolName;

FormattedDate = [datestr(now, 3) datestr(now, 7) '_' datestr(now, 10)];
DataFolder = fullfile(BpodSystem.BpodUserPath,'Data',SubjectName,ProtocolName,'Session Data');
Candidates = dir(DataFolder);
nSessionsToday = 0;
for x = 1:length(Candidates)
	if x > 2
		if strfind(Candidates(x).name, FormattedDate)
			nSessionsToday = nSessionsToday + 1;
		end
	end
end
DataPath = fullfile(BpodSystem.BpodUserPath,'Data',SubjectName,ProtocolName,'Session Data',[SubjectName '_' ProtocolName '_' FormattedDate '_Session' num2str(nSessionsToday+1) '.mat']);
SettingsPath = fullfile(BpodSystem.BpodUserPath,'Data',SubjectName,ProtocolName, 'Session Settings',[SettingsFileName '.mat']);
BpodSystem.DataPath = DataPath;
BpodSystem.SettingsPath = SettingsPath;
ProtocolPath = fullfile(BpodSystem.BpodUserPath,'Protocols',ProtocolName,[ProtocolName '.m']);
BpodSystem.Live = 1;
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
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.Graphics.PauseButton, 'TooltipString', 'Press to pause session');
BpodSystem.BeingUsed = 1;
BpodSystem.ProtocolStartTime = BpodTime;
run(ProtocolPath);
end
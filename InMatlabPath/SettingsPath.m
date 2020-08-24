function Settings = SettingsPath(BpodSystem)
% Provides Bpod V1 & V2 compitability
if BpodSystem.SystemSettings.IsVer2
    Settings = BpodSystem.Path.Settings;
else
    Settings = BpodSystem.SettingsPath;
end
end


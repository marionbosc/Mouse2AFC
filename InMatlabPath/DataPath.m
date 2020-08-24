function Data = DataPath(BpodSystem)
% Provides Bpod V1 & V2 compitability
if BpodSystem.SystemSettings.IsVer2
    Data = BpodSystem.Path.CurrentDataFile;
else
    Data = BpodSystem.DataPath;
end
end


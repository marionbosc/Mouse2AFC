function Subject = SubjectName(BpodSystem)
% Provides Bpod V1 & V2 compitability
if BpodSystem.SystemSettings.IsVer2
    DataFile = BpodSystem.Path.CurrentDataFile;
else
    DataFile = BpodSystem.DataPath;
end
[~, Subject] = fileparts(fileparts(fileparts(fileparts(DataFile))));
end


function IsUsed = BpodBeingUsed(BpodSystem)
% Provides Bpod V1 & V2 compitability
if BpodSystem.SystemSettings.IsVer2
    IsUsed = BpodSystem.Status.BeingUsed;
else
    IsUsed = BpodSystem.BeingUsed;
end
end


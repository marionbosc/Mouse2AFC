function DV = CalcGratingOrientation(trialNum)
global BpodSystem;
% Calculate the value as an angle between 0 and 90
%BpodSystem.Data.Custom.GratingOrientation(trialNum) = round(BpodSystem.Data.Custom.StimulusOmega(trialNum) * 90);
DV = (BpodSystem.Data.Custom.StimulusOmega(trialNum) * 2) - 1;
end

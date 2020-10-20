function DV = CalcGratingOrientation(trialNum)
global BpodSystem;
% Calculate the value as an angle between 0 and 90
%BpodSystem.Data.Custom.Trials(trialNum).GratingOrientation = round(BpodSystem.Data.Custom(trialNum).StimulusOmega * 90);
DV = (BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 2) - 1;
end

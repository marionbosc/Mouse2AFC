function DV = CalcLightIntensity(trialNum)
global BpodSystem;

BpodSystem.Data.Custom.LightIntensityLeft(trialNum) = round(BpodSystem.Data.Custom.StimulusOmega(trialNum) * 100);
BpodSystem.Data.Custom.LightIntensityRight(trialNum) = round((1-BpodSystem.Data.Custom.StimulusOmega(trialNum)) * 100);

DV = (BpodSystem.Data.Custom.StimulusOmega(trialNum) * 2) - 1;
end
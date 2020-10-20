function DV = CalcLightIntensity(trialNum)
global BpodSystem;

BpodSystem.Data.Custom.Trials(trialNum).LightIntensityLeft = round(BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 100);
BpodSystem.Data.Custom.Trials(trialNum).LightIntensityRight = round((1-BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega) * 100);

DV = (BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 2) - 1;
end
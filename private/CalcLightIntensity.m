function DV = CalcLightIntensity(trialNum, StimulusOmega)
global BpodSystem;

BpodSystem.Data.Custom.Trials(trialNum).LightIntensityLeft = round(StimulusOmega * 100);
BpodSystem.Data.Custom.Trials(trialNum).LightIntensityRight = round((1-StimulusOmega) * 100);

DV = (StimulusOmega * 2) - 1;
end
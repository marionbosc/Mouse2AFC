function DV = CalcSoundIntensity(trialNum)
global BpodSystem;

BpodSystem.Data.Custom.Trials(trialNum).SoundIntensityLeft = round(BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 100);
BpodSystem.Data.Custom.Trials(trialNum).SoundIntensityRight = round((1-BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega) * 100);

DV = (BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 2) - 1;
end

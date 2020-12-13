function DV = CalcSoundIntensity(trialNum, StimulusOmega)
global BpodSystem;

BpodSystem.Data.Custom.Trials(trialNum).SoundIntensityLeft = round(StimulusOmega * 100);
BpodSystem.Data.Custom.Trials(trialNum).SoundIntensityRight = round((1-StimulusOmega) * 100);

DV = (StimulusOmega * 2) - 1;
end

function DV = CalcSoundDiscrimination(trialNum)
global BpodSystem;

BpodSystem.Data.Custom.SoundLeft(trialNum) = round(BpodSystem.Data.Custom.StimulusOmega(trialNum) * 100);
BpodSystem.Data.Custom.SoundRight(trialNum) = round((1-BpodSystem.Data.Custom.StimulusOmega(trialNum)) * 100);

DV = (BpodSystem.Data.Custom.StimulusOmega(trialNum) * 2) - 1;
end

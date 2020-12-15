function [Trial, DV] = CalcSoundIntensity(Trial, StimulusOmega)

Trial.SoundIntensityLeft = round(StimulusOmega * 100);
Trial.SoundIntensityRight = round((1-StimulusOmega) * 100);

DV = (StimulusOmega * 2) - 1;
end

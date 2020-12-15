function [Trial, DV] = CalcLightIntensity(Trial, StimulusOmega)

Trial.LightIntensityLeft = round(StimulusOmega * 100);
Trial.LightIntensityRight = round((1-StimulusOmega) * 100);

DV = (StimulusOmega * 2) - 1;
end

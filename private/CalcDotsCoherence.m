function DV = CalcDotsCoherence(trialNum, StimulusOmega)
global BpodSystem;
DV = (StimulusOmega * 2) - 1;
% Coherence value is a ratio between 0 and 1
BpodSystem.Data.Custom.Trials(trialNum).DotsCoherence = abs(DV);
end

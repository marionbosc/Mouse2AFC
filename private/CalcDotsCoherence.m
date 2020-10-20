function DV = CalcDotsCoherence(trialNum)
global BpodSystem;
DV = (BpodSystem.Data.Custom.Trials(trialNum).StimulusOmega * 2) - 1;
% Coherence value is a ratio between 0 and 1
BpodSystem.Data.Custom.DotsCoherence(trialNum) = abs(DV);
end

function [Trial, DV] = CalcDotsCoherence(Trial, StimulusOmega)
DV = (StimulusOmega * 2) - 1;
% Coherence value is a ratio between 0 and 1
Trial.DotsCoherence = abs(DV);
end

function Trial = GenSecExp(Trial, SecExpType, SecExpStimIntensity_,...
                           SecExpStimDir_, OmegaTable)
switch SecExpStimIntensity_
    case SecExpStimIntensity.SameAsOriginalIntensity
        SecStimulusOmega = Trial.StimulusOmega;
    case SecExpStimIntensity.HundredPercent
        SecStimulusOmega = 1;
    case SecExpStimIntensity.TableMaxEnabled
        index = find(OmegaTable.OmegaProb > 0, 1);
        SecStimulusOmega = OmegaTable.Omega(index)/100;
    case SecExpStimIntensity.TableRandom
        % Choose a value randomly given the each value probability
        SecStimulusOmega = randsample(OmegaTable.Omega,1,1,...
                                      OmegaTable.OmegaProb)/100;
    otherwise
        assert(false, 'Unexpected SecExpStimIntensity value');
end
switch SecExpStimDir_
    case SecExpStimDir.Random
        % Should we also do a controlled random here?
        SecLeftRewarded = rand(1, 1) > 0.5;
    case SecExpStimDir.SameAsPrimay
        SecLeftRewarded = Trial.LeftRewarded;
    otherwise
        assert(false, 'Unexpected SecExpStimDir value');
end
if (SecLeftRewarded && SecStimulusOmega < 0.5) ||...
   (~SecLeftRewarded && SecStimulusOmega >= 0.5)
    SecStimulusOmega = -SecStimulusOmega + 1;
end

[Trial, SecDV] = CalcTrialDV(Trial, SecExpType, SecStimulusOmega);
Trial.SecDV = SecDV;
end

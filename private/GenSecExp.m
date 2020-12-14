function SecDV = GenSecExp(SecExpType, SecExpStimIntensity_, SecExpStimDir_,...
                           TrialNum, OmegaTable, StimulusOmega, LeftRewarded)
switch SecExpStimIntensity_
    case SecExpStimIntensity.SameAsOriginalIntensity
        SecStimulusOmega = StimulusOmega;
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
        SecLeftRewarded = LeftRewarded;
    otherwise
        assert(false, 'Unexpected SecExpStimDir value');
end
if (SecLeftRewarded && SecStimulusOmega < 0.5) ||...
   (~SecLeftRewarded && SecStimulusOmega >= 0.5)
    SecStimulusOmega = -SecStimulusOmega + 1;
end
SecDV = CalcTrialDV(TrialNum, SecExpType, SecStimulusOmega);
end

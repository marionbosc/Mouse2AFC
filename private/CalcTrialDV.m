function DV = CalcTrialDV(TrialNum, ExpType, StimulusOmega)
switch ExpType
    case ExperimentType.Auditory
        DV = CalcAudClickTrain(TrialNum, StimulusOmega);
    case ExperimentType.LightIntensity
        DV = CalcLightIntensity(TrialNum, StimulusOmega);
    case ExperimentType.SoundIntensity
        DV = CalcSoundIntensity(TrialNum, StimulusOmega);
    case ExperimentType.GratingOrientation
        DV = CalcGratingOrientation(TrialNum, StimulusOmega);
    case ExperimentType.RandomDots
        DV = CalcDotsCoherence(TrialNum, StimulusOmega);
    otherwise
        assert(false, 'Unexpected ExperimentType');
end
end

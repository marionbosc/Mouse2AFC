function [Trial, DV] = CalcTrialDV(Trial, ExpType, StimulusOmega)
% Does DV differ depending on the ExperimentType? I think it should remain the
% same for all the experiments, as it should be dependent on stimulus omega.
switch ExpType
    case ExperimentType.Auditory
        [Trial, DV] = CalcAudClickTrain(Trial, StimulusOmega);
    case ExperimentType.LightIntensity
        [Trial, DV] = CalcLightIntensity(Trial, StimulusOmega);
    case ExperimentType.SoundIntensity
        [Trial, DV] = CalcSoundIntensity(Trial, StimulusOmega);
    case ExperimentType.GratingOrientation
        [Trial, DV] = CalcGratingOrientation(Trial, StimulusOmega);
    case ExperimentType.RandomDots
        [Trial, DV] = CalcDotsCoherence(Trial, StimulusOmega);
    otherwise
        assert(false, 'Unexpected ExperimentType');
end
end

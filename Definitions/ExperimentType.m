classdef ExperimentType
    properties (Constant)
        Auditory = 1;
        LightIntensity = 2;
        GratingOrientation = 3;
        RandomDots = 4;
        SoundIntensity = 5;
        NoStimulus = 6;
    end
    methods(Static)
        function string = String()
            string = properties(ExperimentType)';
        end
    end
end

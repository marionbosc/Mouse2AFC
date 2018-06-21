classdef ExperimentType
    properties (Constant)
        Auditory = 1;
        LightIntensity = 2;
    end
    methods(Static)
        function string = String()
            string = properties(ExperimentType)';
        end
    end
end

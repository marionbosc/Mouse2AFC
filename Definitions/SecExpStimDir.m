classdef SecExpStimDir
    properties (Constant)
        SameAsPrimay = 1;
        Random = 2;
    end
    methods(Static)
        function string = String()
            string = properties(SecExpStimDir)';
        end
    end
end

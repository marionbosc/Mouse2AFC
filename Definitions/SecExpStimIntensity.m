classdef SecExpStimIntensity
    properties (Constant)
        SameAsOriginalIntensity = 1;
        HundredPercent = 2;
        TableMaxEnabled = 3;
        TableRandom = 4;
    end
    methods(Static)
        function string = String()
            string = properties(SecExpStimIntensity)';
        end
    end
end

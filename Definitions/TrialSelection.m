classdef TrialSelection
    properties (Constant)
        Flat = 1;
        BiasCorrecting = 2;
        Manual = 3;
    end
    methods(Static)
        function string = String()
            string = properties(TrialSelection)';
        end
    end
end

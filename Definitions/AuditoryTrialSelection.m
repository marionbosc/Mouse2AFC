classdef AuditoryTrialSelection
    properties (Constant)
        BetaDistribution = 1;
        DiscretePairs = 2;
    end
    methods(Static)
        function string = String()
            string = properties(AuditoryTrialSelection)';
        end
    end
end

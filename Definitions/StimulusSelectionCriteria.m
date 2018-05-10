classdef StimulusSelectionCriteria
    properties (Constant)
        BetaDistribution = 1;
        DiscretePairs = 2;
    end
    methods(Static)
        function string = String()
            string = properties(StimulusSelectionCriteria)';
        end
    end
end

classdef BlkSwitchCond
    properties (Constant)
        TrialsRandCountWithinLimits = 1;
        PerfReached = 2;
    end
    methods(Static)
        function string = String()
            string = properties(BlkSwitchCond)';
        end
    end
end

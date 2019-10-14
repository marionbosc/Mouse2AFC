classdef MinSampleType
    properties (Constant)
        FixMin = 1;
        AutoIncr = 2;
        RandBetMinMax_DefIsMax = 3;
        RandNumIntervalsMinMax_DefIsMax = 4;
    end
    methods(Static)
        function string = String()
            string = properties(MinSampleType)';
        end
    end
end

classdef DrawStimType
    properties (Constant)
        RDK = 1;
        StaticGratings = 2;
        MovingGratings = 3;
    end
    methods(Static)
        function string = String()
            string = properties(DrawStimType)';
        end
    end
end

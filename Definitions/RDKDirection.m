classdef RDKDirection
    properties (Constant)
        Degrees0 = 1;
        Degrees45 = 2;
        Degrees90 = 3;
        Degrees135 = 4;
        Degrees180 = 5;
        Degrees225 = 6;
        Degrees270 = 7;
        Degrees315 = 8;
    end
    methods(Static)
        function string = String()
            string = properties(RDKDirection)';
        end
    end
    methods(Static)
        function degrees = getDegrees(variable_index)
            degrees = (variable_index-1)*45;
        end
    end
end

classdef BrainRegion
    properties (Constant)
        V1_L = 1;
        V1_R = 2;
        V1_Bi = 3;
        M2_L = 4;
        M2_R = 5;
        M2_Bi = 6;
    end
    methods(Static)
        function string = String()
            string = properties(BrainRegion)';
        end
    end
end

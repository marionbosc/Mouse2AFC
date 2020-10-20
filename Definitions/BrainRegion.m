classdef BrainRegion
    properties (Constant)
        V1_L = 1;
        V1_R = 2;
        V1_Bi = 3;
        M2_L = 4;
        M2_R = 5;
        M2_Bi = 6;
        PPC_L = 7;
        PPC_R = 8;
        PPC_Bi = 9;
        POR_L = 10;
        POR_R = 11;
        POR_Bi = 12;
        RealM2_L = 13;
        RealM2_R = 14;
        RealM2_Bi = 15;
        RSP_L = 16;
        RSP_R = 17;
        RSP_Bi = 18;
    end
    methods(Static)
        function string = String()
            string = properties(BrainRegion)';
        end
    end
end

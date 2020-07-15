classdef TTLWireUsage
    properties (Constant)
        Optogenetics = 1;
        TwoPhoton_Shutter = 2;
    end
    methods(Static)
        function string = String()
            string = properties(TTLWireUsage)';
        end
    end
end

classdef ITISignalType
    properties (Constant)
        None = 1;
        Beep = 2;
        PortLED = 3;
    end
    methods(Static)
        function string = String()
            string = properties(ITISignalType)';
        end
    end
end

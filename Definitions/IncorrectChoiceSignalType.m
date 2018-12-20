classdef IncorrectChoiceSignalType
    properties (Constant)
        None = 1;
        NoisePulsePal = 2;
        PortLED = 3;
    end
    methods(Static)
        function string = String()
            string = properties(IncorrectChoiceSignalType)';
        end
    end
end

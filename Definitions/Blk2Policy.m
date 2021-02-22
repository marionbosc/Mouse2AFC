classdef Blk2Policy
    properties (Constant)
        NotUsed = 1;
        ReverseBias = 2;
        SwapPrimSecExps = 3;
        % SecBias = 4;
    end
    methods(Static)
        function string = String()
            string = properties(Blk2Policy)';
        end
    end
end

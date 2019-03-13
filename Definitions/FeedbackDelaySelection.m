classdef FeedbackDelaySelection
    properties (Constant)
        Fix = 1;
        AutoIncr = 2;
        TruncExp = 3;
        None = 4;
    end
    methods(Static)
        function string = String()
            string = properties(FeedbackDelaySelection)';
        end
    end
end

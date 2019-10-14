classdef MouseState
    properties (Constant)
        FreelyMoving = 1;
        HeadFixed = 2;
    end
    methods(Static)
        function string = String()
            string = properties(MouseState)';
        end
    end
end

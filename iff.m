function result = iff(condition,yes_val,no_val)
% A short-hand one liner for:
% if condition
%   assign yes_val
% else
%   assign no_val
% e.g:
% evenOrOddString = iff(mod(x, 2) == 0, 'even', 'odd')
% Notice that the yes_val and no_val are evaluated regardless of whether
% they are returned or not, unfortunately MATLAB doesn't have lazy evaluation
    assert(nargin == 3, 'Wrong number of arguments - 3 required.');
    if condition
        result = yes_val;
    else
        result = no_val;
    end
end

% TruncatedExponential draws random numbers from an exponential distribution
% between a specified min and max value. Does not reset RNG!

% input(mandatory): min_value, max_value, alpha
% input (optional): [m,n] m rows and n columns, default m=1,n=1
% output random numbers in m x n matrix

% Torben Ott, July 2016

function Exp = TruncatedExponential(varargin)

% input values
min_value = varargin{1};
max_value = varargin{2};
if min_value >= max_value
    new_max_value = min_value + 0.01;
    fprintf(2, ['min_value=%.2f is bigger than or equal to max_value=%.2f.'...
        'max_value will been changed to %.2f\n'], min_value, max_value,...
        new_max_value);
    max_value = new_max_value;
end
tau = varargin{3};
if length(varargin)>3
    m = varargin{4}(1);n = varargin{4}(2);
else
    m=1;n=1;
end

% Initialize to a large value
Exp = max_value*ones(m*n,1)+1;

% sample until in range
while any(Exp > (max_value-min_value))
    Exp(Exp > (max_value-min_value)) = exprnd(tau,sum(Exp > (max_value-min_value)),1);
end

%add the offset
Exp = Exp + min_value;


%reshape
Exp = reshape(Exp,m,n);

end

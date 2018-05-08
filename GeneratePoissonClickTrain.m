function ClickTimes = GeneratePoissonClickTrain(ClickRate, Duration)
% ClickTimes = click time points in us
% ClickRate = mean click rate in Hz
% Duration = click train duration in seconds
% Poisson distribution is the probability that event occurs x times over an
% interval of times given that on average it occurs ? times. The probaility
% distrubition function is P(x; ?) = (pow(?, x) * exp(-?)) / x!
% https://en.wikipedia.org/wiki/Poisson_distribution
% https://www.youtube.com/watch?v=Fk02TW6reiA

SamplingRate = 1000000;
nSamples = Duration*SamplingRate; % Total number of sampling points for the whole duration
% Calculates mean of exponential distribution, i.e the average between each
% two time points.
ExponentialMean = round((1/ClickRate)*SamplingRate);
InvertedMean = ExponentialMean*-1;
% A large enough buffer that will hold the time points at which to trigger
% a tone.
PreallocateSize = round(ClickRate*Duration*2);
ClickTimes = zeros(1,PreallocateSize);
Pos = 0;
Time = 0;
Building = 1;
while Building == 1
    Pos = Pos + 1;
    % Why do we multiply by log?
    Interval = InvertedMean*log(rand)+100; % +100 ensures no duplicate timestamps at PulsePal resolution of 100us
    Time = Time + Interval;
    if Time > nSamples
        Building = 0;
    else
        ClickTimes(Pos) = Time;
    end
end
ClickTimes = ClickTimes(1:Pos-1); % Trim click train preallocation to length
ClickTimes = round(ClickTimes/100)/10000; % Make clicks multiples of 100us - necessary for pulse time programming
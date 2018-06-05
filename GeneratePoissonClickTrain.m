%% Create time points of clicks sampled from a Poisson distribution
%
%
% Input: 
%    - Click rate: [Auditory Omega * Sumrate] for LeftClicks and 1-[Auditory Omega * Sumrate] for RightClicks
% in Hz (click/sec)
%    - Duration in sec
%
% Output:
%    - ClickTimes : click time points in sec
%

function ClickTimes = GeneratePoissonClickTrain(ClickRate, Duration)

% Estimation of the number of clicks within the stimulus duration
nClicks = round(ClickRate*Duration);
    
if nClicks > 0
    
    % Comput of the number of sample at 0.001 sec resolution (PulsePal resolution)
    SamplingRate = 100; 
    nSamples = Duration*SamplingRate;

    % Computation of Lambda for the distribution (mean interval between
    % time points)
    interval_moyen = nSamples / nClicks;

    % Comput of a Poisson distrib 
    poisson = makedist('Poisson', 'lambda', interval_moyen);

    % Random sampling of nClicks points among the Poisson distribution
    interval_poisson = random(poisson,nClicks,1);

    % Calculation of the click times based on the interval sampled
    temps = [];
    last_time= 0;
    for i = 1:size(interval_poisson, 1)
        temps(i) = last_time + interval_poisson(i) + .01;
        last_time = temps(i);
    end

    % Conversion of the time points in sec
    ClickTimes = temps/100;

    % Test that last Click time is not after the end of the stimulus
    max_ClickTimes = max(ClickTimes);

    if max_ClickTimes > Duration % if so, rescaling of the whole timepoints vector
        scaling = Duration / max_ClickTimes;
        ClickTimes = ClickTimes*scaling;
        ClickTimes = round(ClickTimes,4); % to keep it as multiple of 0.0001 (PulsePal precision)      
    end
    
    % repeat last checking until all the time points are unique to make sure that there is not duplicated timepoint        
    while size(unique(ClickTimes),2) < size(ClickTimes,2)
        for i = 1:(size(ClickTimes,2)-1)
            if (ClickTimes(i+1) - ClickTimes(i)) < 0.0001
             ClickTimes(i+1) = ClickTimes(i+1)+ 0.0001;
            end
        end
    end
        
else % if frequency of click = 0 --> no click
    ClickTimes = [];
end

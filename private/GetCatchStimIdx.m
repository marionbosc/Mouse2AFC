function idx = GetCatchStimIdx (StimulusOmega)
    % StimulusOmega is between 0 and 1, we break it down to bins of 20
    idx = round(StimulusOmega * 20) + 1;
end

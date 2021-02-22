function Str = StimDirStr(ExpType, DV, SecExpType, SecDV)

function Str_ = SingleExp(ExpType_, DV_)
if ExpType_ == ExperimentType.RandomDots
    Str_ = strcat(num2str(abs(DV_/0.01)), iff(DV_ < 0,'%R cohr.', '%L cohr.'));
else
    % Set between -100 to +100
    StimIntensity = num2str(iff(DV_ > 0, (DV_+1)/0.02, (DV_-1)/-0.02));
    Str_ = strcat(StimIntensity, iff(DV_ < 0, '%R', '%L'));
end
end


Str = SingleExp(ExpType, DV);
if ~isnan(SecDV) && SecDV ~= ExperimentType.NoStimulus
    Str = sprintf('%s - Sec: %s', Str, SingleExp(SecExpType, SecDV));
end
end

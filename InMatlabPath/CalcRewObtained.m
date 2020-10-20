function RewardObtained = CalcRewObtained(DataCustom, iTrial)
Trials = DataCustom.Trials(1:iTrial);
CenterPortAmount = [Trials.CenterPortRewAmount];
RCP = sum(CenterPortAmount([Trials.RewardAfterMinSampling])); %ones(1,size(DataCustom.RewardMagnitude,1))*0.5;
R = [Trials.RewardMagnitude];
ndxRwd = [Trials.Rewarded];
C = zeros(size(R));
C([Trials.ChoiceLeft] == 1 & ndxRwd, 1) = 1;
C([Trials.ChoiceLeft] == 0 & ndxRwd, 2) = 1;
R = R.*C;
RewardObtained = sum([sum(R(:)) sum(RCP)]) + sum([Trials.PreStimCntrReward]);
end


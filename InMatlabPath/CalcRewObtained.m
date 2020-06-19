function RewardObtained = CalcRewObtained(DataCustom)
RCP = sum(DataCustom.CenterPortRewAmount(DataCustom.RewardAfterMinSampling)); %ones(1,size(DataCustom.RewardMagnitude,1))*0.5;
R = DataCustom.RewardMagnitude;
ndxRwd = DataCustom.Rewarded;
C = zeros(size(R)); C(DataCustom.ChoiceLeft==1&ndxRwd,1) = 1; C(DataCustom.ChoiceLeft==0&ndxRwd,2) = 1;
R = R.*C;
RewardObtained = sum([sum(R(:)) sum(RCP)]) + sum(DataCustom.PreStimCntrReward);
end


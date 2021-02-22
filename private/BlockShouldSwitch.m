function [shouldSwitch, BlocksInfo] = BlockShouldSwitch(GUI, CurTrialNum,...
                                                        trials, BlocksInfo)
if GUI.Blk2Policy == Blk2Policy.NotUsed
    shouldSwitch = false;
    return;
end

switch GUI.BlkSwitchCond
    case BlkSwitchCond.TrialsRandCountWithinLimits
        shouldSwitch = CurTrialNum >= BlocksInfo.NextSwitchAt;
        if shouldSwitch
            BlocksInfo.NextSwitchAt = round(BlocksInfo.NextSwitchAt + ...
                GUI.BlkSwitchLimitBot + (rand(1)*(GUI.BlkSwitchLimitTop-...
                                                  GUI.BlkSwitchLimitBot)));
        end
        return;
   case BlkSwitchCond.PerfReached
       if CurTrialNum - BlocksInfo.CurBlkStart <=...
          GUI.BlkSwitchPerfMinGoalNumTrials
           shouldSwitch = false;
           return;
       else
           relevantChoice =  [trials(CurTrialNum-...
                   GUI.BlkSwitchPerfMinGoalNumTrials:CurTrialNum).ChoiceCorrect];
           relevantChoice(isnan(relevantChoice)) = false; %TODO: Make sure that this is a slice
           fprintf('Num of nan trials is: %d\n', sum(isNan(trials(CurTrialNum-GUI.BlkSwitchPerfMinGoalNumTrials:CurTrialNum).ChoiceCorrect)));
           relevantPerf = 100 * sum(relevantChoice)/len(relevantChoice);
           shouldSwitch = relevantPerf > GUI.BlkSwitchPerfMinGoal;
           return;
       end
end

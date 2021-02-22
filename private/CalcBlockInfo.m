function [NextTrialBlockNum, NewLeftBias, NewExpType, NewSecExpType, ...
          BlocksInfo, BlockStr] = CalcBlockInfo(GUI, iTrial, Trials, BlocksInfo)
NewLeftBias = GUI.LeftBias;
NewExpType = GUI.ExperimentType;
NewSecExpType = GUI.SecExperimentType;

if GUI.Blk2Policy == Blk2Policy.NotUsed
    BlockStr = 'Not Used';
    NextTrialBlockNum = nan;
else
    [ShouldSwitchBlock, BlocksInfo] = BlockShouldSwitch(GUI, iTrial, Trials,...
                                                        BlocksInfo);
    CurTrialBlockNum = Trials(iTrial).BlockNum;
    if ShouldSwitchBlock
        if isnan(CurTrialBlockNum)
            CurTrialBlockNum = 0; % Set to zero so we conver it to 1
        end
        NextTrialBlockNum = mod(CurTrialBlockNum, 2) + 1;
        BlocksInfo.CurBlkStart = iTrial + 1;
    else
        NextTrialBlockNum = CurTrialBlockNum;
    end
    if NextTrialBlockNum == 2 % If we are in the second block
        switch GUI.Blk2Policy
            case Blk2Policy.ReverseBias
                NewLeftBias = 1 - NewLeftBias;
            case Blk2Policy.SwapPrimSecExps
                TmpExpType = NewExpType;
                NewExpType = NewSecExpType;
                NewSecExpType = TmpExpType;
        end
    end
    % Update the GUI
    BlockStr = sprintf('Block-%d', NextTrialBlockNum);
    if GUI.BlkSwitchCond == BlkSwitchCond.TrialsRandCountWithinLimits
        BlockStr = sprintf('%s - Switch @T:%d', BlockStr,...
                           BlocksInfo.NextSwitchAt);
    end
end

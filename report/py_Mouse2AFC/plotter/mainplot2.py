import numpy as np
import matplotlib.pyplot as plt

def mainplot2(AxesHandles, Action, DataCustom, TaskParametersGUI,
              TrialStartTimestamp, iTrial=None):

  nTrialsToShow = 90 #default number of trials to display
  if Action == 'init':
    from matplotlib.lines import Line2D
    def line(ax, *ln_args, **ln_kargs):
      _line = ax.plot(*ln_args, **ln_kargs)
      return _line[0]

    from matplotlib.text import Text
    def text(ax, *txt_args, **txt_kargs):
      txt = ax.text(*txt_args, **txt_kargs)
      return txt
    ## Outcome
    # initialize pokes plot

    # plot in specified axes
    AxesHandles.Stim = line(AxesHandles.HandleOutcome, [-1], [1], linestyle='none', marker='o', markeredgecolor=[.5,.5,.5], markerfacecolor=[.7,.7,.7], markersize=8)
    AxesHandles.DV = line(AxesHandles.HandleOutcome, np.arange(1, len(DataCustom.DV)+1),DataCustom.DV, linestyle='none', marker='o', markeredgecolor='b', markerfacecolor='b', markersize=6)
    AxesHandles.CurrentTrialCircle = line(AxesHandles.HandleOutcome, [1], [0], linestyle='none', marker='o', markeredgecolor='k', markerfacecolor=[1, 1, 1], markersize=6)
    AxesHandles.CurrentTrialCross = line(AxesHandles.HandleOutcome, [1], [0], linestyle='none', marker='+', markeredgecolor='k', markerfacecolor=[1, 1, 1], markersize=6)
    AxesHandles.CumRwd = text(AxesHandles.HandleOutcome, 1, 1,'0mL', verticalalignment='bottom', horizontalalignment='center')
    AxesHandles.Correct = line(AxesHandles.HandleOutcome, [-1], [1], linestyle='none', marker='o', markeredgecolor='g', markerfacecolor='g', markersize=6)
    AxesHandles.Incorrect = line(AxesHandles.HandleOutcome, [-1], [1], linestyle='none', marker='o', markeredgecolor='r', markerfacecolor='r', markersize=6)
    AxesHandles.BrokeFix = line(AxesHandles.HandleOutcome, [-1], [0], linestyle='none', marker='d', markeredgecolor='b', markerfacecolor=None, markersize=6)
    AxesHandles.EarlyWithdrawal = line(AxesHandles.HandleOutcome, [-1], [0], linestyle='none', marker='d', markeredgecolor=None, markerfacecolor='b', markersize=6)
    AxesHandles.NoFeedback = line(AxesHandles.HandleOutcome, [-1], [0], linestyle='none', marker='o', markeredgecolor=None, markerfacecolor='w', markersize=5)
    AxesHandles.NoResponse = line(AxesHandles.HandleOutcome, [-1, -1],[0, 1], linestyle='none', marker='x', markeredgecolor='w', markerfacecolor=None, markersize=6)
    AxesHandles.Catch = line(AxesHandles.HandleOutcome, [-1, -1], [0, 1], linestyle='none', marker='o', markeredgecolor=[0,0,0], markerfacecolor=[0,0,0], markersize=4)
    AxesHandles.HandleOutcome.tick_params(direction='out')
    AxesHandles.HandleOutcome.set_xlim(0, nTrialsToShow)
    AxesHandles.HandleOutcome.set_ylim(-1.25, 1.25)
    AxesHandles.HandleOutcome.set_yticks([-1, 1])
    AxesHandles.HandleOutcome.set_yticklabels(['Right','Left'], fontSize=13)
    AxesHandles.Stim.set_data(np.arange(1, len(DataCustom.DV) + 1), DataCustom.DV)
    AxesHandles.HandleOutcome.set_xlabel('Trial#', fontSize=14)
    #hold(AxesHandles.HandleOutcome, 'on')
    # Psyc Stimulus
    AxesHandles.PsycStim = line(AxesHandles.HandlePsycStim, [-1, 1],[.5, .5], linestyle='none', marker='o', markeredgecolor='k', markerfacecolor='k', markersize=6, visible=False)
    AxesHandles.PsycStimFit = line(AxesHandles.HandlePsycStim, [-1, 1],[.5, .5], color='k', visible=False)
    AxesHandles.PsycStimForced = line(AxesHandles.HandlePsycStim, [-1, 1],[.5, .5], linestyle='none', marker='o', markeredgecolor='g', markerfacecolor='g', markersize=6, visible=False)
    AxesHandles.PsycStimForcedFit = line(AxesHandles.HandlePsycStim, [-1, 1],[.5, .5], color='g', visible=False)
    AxesHandles.HandlePsycStim.set_ylim(-.05, 1.05)
    AxesHandles.HandlePsycStim.set_xlim(-1.05, 1.05)
    AxesHandles.HandlePsycStim.set_xlabel('DV') # FIGURE OUT UNIT
    AxesHandles.HandlePsycStim.set_ylabel('% left')
    AxesHandles.HandlePsycStim.set_title('Psychometric Stim')
    # Vevaiometric curve
    # hold(AxesHandles.HandleVevaiometric,'on')
    AxesHandles.VevaiometricCatch = line(AxesHandles.HandleVevaiometric,-2,-1, linestyle='-', color='g', visible=False, linewidth=2)
    AxesHandles.VevaiometricErr = line(AxesHandles.HandleVevaiometric,-2,-1, linestyle='-', color='r', visible=False, linewidth=2)
    AxesHandles.VevaiometricPointsErr = line(AxesHandles.HandleVevaiometric,-2,-1, linestyle='none', color='r', marker='o', markerfacecolor='r', markersize=2, visible=False, markeredgecolor='r')
    AxesHandles.VevaiometricPointsCatch = line(AxesHandles.HandleVevaiometric,-2,-1, linestyle='none', color='g', marker='o', markerfacecolor='g', markersize=2, visible=False, markeredgecolor='g')
    AxesHandles.HandleVevaiometric.set_ylim(0, 20)
    AxesHandles.HandleVevaiometric.set_xlim(-1.05, 1.05)
    AxesHandles.HandleVevaiometric.set_xlabel('DV')
    AxesHandles.HandleVevaiometric.set_ylabel('WT (s)')
    AxesHandles.HandleVevaiometric.set_title('Vevaiometric')
    # Trial rate
    # hold(AxesHandles.HandleTrialRate,'on')
    AxesHandles.TrialRate = line(AxesHandles.HandleTrialRate,[0],[0], linestyle='-', color='k', visible=False)
    AxesHandles.HandleTrialRate.set_xlabel('Time (min)') #% FIGURE OUT UNIT
    AxesHandles.HandleTrialRate.set_ylabel('nTrials')
    AxesHandles.HandleTrialRate.set_title('Trial rate')
    # Stimulus delay
    # hold(AxesHandles.HandleFix,'on')
    AxesHandles.HandleFix.set_xlabel('Time (ms)')
    AxesHandles.HandleFix.set_ylabel('trial counts')
    AxesHandles.HandleFix.set_title('Pre-stimulus delay')
    # ST histogram
    # hold(AxesHandles.HandleST,'on')
    AxesHandles.HandleST.set_xlabel('Time (ms)')
    AxesHandles.HandleST.set_ylabel('trial counts')
    AxesHandles.HandleST.set_title('Stim sampling time')
    # Feedback Delay histogram
    # hold(AxesHandles.HandleFeedback,'on')
    AxesHandles.HandleFeedback.set_xlabel('Time (ms)')
    AxesHandles.HandleFeedback.set_ylabel('trial counts')
    AxesHandles.HandleFeedback.set_title('Feedback delay')
    plt.draw()
  elif Action == 'update':
    # Reposition and hide/show axes
    ShowPlots = [TaskParametersGUI.ShowPsycStim,
                 TaskParametersGUI.ShowVevaiometric,
                 TaskParametersGUI.ShowTrialRate,
                 TaskParametersGUI.ShowFix,
                 TaskParametersGUI.ShowST,
                 TaskParametersGUI.ShowFeedback]
    NoPlots = np.sum(ShowPlots)
    NPlot = np.cumsum(ShowPlots)
    # TODO: Run in one loop and use directly showplot[x] value
    if ShowPlots[0]:
      AxesHandles.HandlePsycStim.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandlePsycStim.get_children()]
    else:
      AxesHandles.HandlePsycStim.set_visible(False)
      [child.set_visible(False) for child in AxesHandles.HandlePsycStim.get_children()]

    if ShowPlots[1]:
      AxesHandles.HandleVevaiometric.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandleVevaiometric.get_children()]
    else:
      [child.set_visible(False) for child in AxesHandles.HandleVevaiometric.get_children()]

    if ShowPlots[2]:
      AxesHandles.HandleTrialRate.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandleTrialRate.get_children()]
    else:
      AxesHandles.HandleTrialRate.set_visible(False)
      [child.set_visible(False) for child in AxesHandles.HandleTrialRate.get_children()]

    if ShowPlots[3]:
      AxesHandles.HandleFix.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandleFix.get_children()]
    else:
      AxesHandles.HandleFix.set_visible(False)
      [child.set_visible(False) for child in AxesHandles.HandleFix.get_children()]

    if ShowPlots[4]:
      AxesHandles.HandleST.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandleST.get_children()]
    else:
      AxesHandles.HandleST.set_visible(False)
      [child.set_visible(False) for child in AxesHandles.HandleST.get_children()]

    if ShowPlots[5]:
      AxesHandles.HandleFeedback.set_visible(True)
      [child.set_visible(True) for child in AxesHandles.HandleFeedback.get_children()]
    else:
      AxesHandles.HandleFeedback.set_visible(False)
      [child.set_visible(False) for child in AxesHandles.HandleFeedback.get_children()]

    # Outcome
    assert iTrial != None
    trials_ahead = iTrial + 15
    start_trial = max(1, trials_ahead - nTrialsToShow)
    if trials_ahead > nTrialsToShow:
      AxesHandles.HandleOutcome.set_xlim(start_trial, trials_ahead)

    AxesHandles.CurrentTrialCircle.set_data([iTrial+1], [0])
    AxesHandles.CurrentTrialCross.set_data([iTrial+1], [0])

    # plot modality background
    AxesHandles.Stim.set_data(np.arange(1, len(DataCustom.DV)+1), DataCustom.DV)
    # plot past&future trials
    AxesHandles.DV.set_data(np.arange(start_trial,len(DataCustom.DV)+1),
                           DataCustom.DV[start_trial-1:])

    # Plot past trial outcomes
    indxToPlot = np.arange(start_trial, iTrial+1) - 1 # Convert to python index
    # Cumulative Reward Amount
    R = DataCustom.RewardMagnitude
    #%ones(1,size(DataCustom.RewardMagnitude,1))*0.5
    RCP = np.sum(DataCustom.CenterPortRewAmount[DataCustom.RewardAfterMinSampling-1])
    ndxRwd = DataCustom.Rewarded
    C = np.zeros(R.shape)
    C[(DataCustom.ChoiceLeft==1&ndxRwd) - 1,0] = 1
    C[(DataCustom.ChoiceLeft==0&ndxRwd) - 1,1] = 1
    R = R * C
    RewardObtained = np.sum(R) + np.sum(RCP) + np.sum(DataCustom.PreStimCntrReward)
    AxesHandles.CumRwd.set_position((iTrial+1, 0.1))
    AxesHandles.CumRwd.set_text(str(RewardObtained/1000) + ' mL')
    AxesHandles.CumRwd.set_horizontalalignment('left')
    del R, C
    # Plot Rewarded
    for k in ["ChoiceLeft","ChoiceCorrect","DV","FixDur","FixBroke","ST",
              "EarlyWithdrawal","FeedbackTime","Feedback","CatchTrial"]:
      DataCustom[k] = np.atleast_1d(DataCustom[k])

    ndxCor = DataCustom.ChoiceCorrect[indxToPlot] == 1
    Xdata = indxToPlot[ndxCor] + 1
    Ydata = DataCustom.DV[indxToPlot]
    Ydata = Ydata[ndxCor]
    AxesHandles.Correct.set_data(Xdata, Ydata)
    # Plot Incorrect
    ndxInc = DataCustom.ChoiceCorrect[indxToPlot] == 0
    Xdata = indxToPlot[ndxInc] + 1
    Ydata = DataCustom.DV[indxToPlot]
    Ydata = Ydata[ndxInc]
    AxesHandles.Incorrect.set_data(Xdata, Ydata)
    # Plot Broken Fixation
    ndxBroke = DataCustom.FixBroke[indxToPlot]
    Xdata = indxToPlot[ndxBroke] + 1
    Ydata = np.zeros(np.sum(ndxBroke))#1,sum(ndxBroke))
    AxesHandles.BrokeFix.set_data(Xdata, Ydata)
    # Plot Early Withdrawal
    ndxEarly = DataCustom.EarlyWithdrawal[indxToPlot]
    Xdata = indxToPlot[ndxEarly] + 1
    Ydata = np.zeros(np.sum(ndxEarly))#1,sum(ndxEarly))
    AxesHandles.EarlyWithdrawal.set_data(Xdata, Ydata)
    # Plot missed choice trials
    ndxMiss = np.isnan(DataCustom.ChoiceLeft[indxToPlot]) & ~ndxBroke & ~ndxEarly
    Xdata = indxToPlot[ndxMiss] + 1
    Ydata = DataCustom.DV[indxToPlot]
    Ydata = Ydata[ndxMiss]
    AxesHandles.NoResponse.set_data(Xdata, Ydata)
    # Plot NoFeedback trials
    ndxNoFeedback = ~DataCustom.Feedback[indxToPlot]
    Xdata = indxToPlot[ndxNoFeedback&~ndxMiss] + 1
    Ydata = DataCustom.DV[indxToPlot]
    Ydata = Ydata[ndxNoFeedback&~ndxMiss]
    AxesHandles.NoFeedback.set_data(Xdata, Ydata)
    # Plot catch trials
    ndxCatch = DataCustom.CatchTrial[indxToPlot]
    Xdata = indxToPlot[ndxCatch&~ndxMiss] + 1
    Ydata = DataCustom.DV[indxToPlot]
    Ydata = Ydata[ndxCatch&~ndxMiss]
    AxesHandles.Catch.set_data(Xdata, Ydata)
    '''
    ## Psych Stim
    if TaskParametersGUI.ShowPsycStim
      ndxNan = np.isnan(DataCustom.ChoiceLeft)
      ndxChoice = DataCustom.ForcedLEDTrial[:len(DataCustom.ChoiceLeft)]==0
      ndxForced = DataCustom.ForcedLEDTrial[:len(DataCustom.ChoiceLeft)]==1
      StimDV = DataCustom.DV[:len(DataCustom.ChoiceLeft)]
      StimBin = 8
      # BinIdx = discretize(StimDV,linspace(min(StimDV),max(StimDV),StimBin+1))
      BinIdx = np.digitize(StimDV,np.linspace(min(StimDV),max(StimDV),StimBin+1))

      # Choice trials
      PsycY = grpstats(DataCustom.ChoiceLeft(~ndxNan&ndxChoice),BinIdx(~ndxNan&ndxChoice),'mean')
      PsycX = unique(BinIdx(~ndxNan&ndxChoice))/StimBin*2-1-1/StimBin
      AxesHandles.PsycStim.set_data(PsycX, PsycY)
      if np.sum(~ndxNan&ndxChoice) > 1:
        AxesHandles.PsycStimFit.XData = linspace(min(StimDV),max(StimDV),100)
        AxesHandles.PsycStimFit.YData = glmval(glmfit(StimDV(~ndxNan&ndxChoice),...
          DataCustom.ChoiceLeft(~ndxNan&ndxChoice)','binomial'),linspace(min(StimDV),max(StimDV),100),'logit')

      # Forced trials
      PsycY = grpstats(DataCustom.ChoiceLeft(~ndxNan&ndxForced),BinIdx(~ndxNan&ndxForced),'mean')
      PsycX = unique(BinIdx(~ndxNan&ndxForced))/StimBin*2-1-1/StimBin
      AxesHandles.PsycStimForced.set_data(PsycX, PsycY)
      if np.sum(~ndxNan&ndxForced) > 1
        AxesHandles.PsycStimForcedFit.XData = linspace(min(StimDV),max(StimDV),100)
        AxesHandles.PsycStimForcedFit.YData = glmval(glmfit(StimDV(~ndxNan&ndxForced),...
          DataCustom.ChoiceLeft(~ndxNan&ndxForced)','binomial'),linspace(min(StimDV),max(StimDV),100),'logit')


    # Vevaiometric
    if TaskParametersGUI.ShowVevaiometric
      AxesHandles.HandleVevaiometric.set_ylim(0, TaskParametersGUI.VevaiometricYLim)
      AxesHandles.HandleVevaiometric.set_ylim(0, TaskParametersGUI.VevaiometricYLim)
      ndxError = DataCustom.ChoiceCorrect[:iTrial] == 0  # all (completed) error trials (including catch errors)
      ndxCorrectCatch = DataCustom.CatchTrial[:iTrial] & DataCustom.ChoiceCorrect[:iTrial) == 1 # only correct catch trials
      ndxMinWT = DataCustom.FeedbackTime > TaskParametersGUI.VevaiometricMinWT
      DV = DataCustom.DV[iTrial]
      DVNBin = TaskParametersGUI.VevaiometricNBin
      BinIdx = discretize(DV,linspace(min(StimDV),max(StimDV),DVNBin+1))
      WTerr = grpstats(DataCustom.FeedbackTime(ndxError&ndxMinWT),BinIdx(ndxError&ndxMinWT),'mean')'
      WTcatch = grpstats(DataCustom.FeedbackTime(ndxCorrectCatch&ndxMinWT),BinIdx(ndxCorrectCatch&ndxMinWT),'mean')'
      Xerr = unique(BinIdx(ndxError&ndxMinWT))/DVNBin*2-1-1/DVNBin
      Xcatch = unique(BinIdx(ndxCorrectCatch&ndxMinWT))/DVNBin*2-1-1/DVNBin
      AxesHandles.VevaiometricErr.YData = WTerr
      AxesHandles.VevaiometricErr.XData = Xerr
      AxesHandles.VevaiometricCatch.YData = WTcatch
      AxesHandles.VevaiometricCatch.XData = Xcatch
      if TaskParametersGUI.VevaiometricShowPoints
        AxesHandles.VevaiometricPointsErr.YData = DataCustom.FeedbackTime(ndxError&ndxMinWT)
        AxesHandles.VevaiometricPointsErr.XData = DV(ndxError&ndxMinWT)
        AxesHandles.VevaiometricPointsCatch.YData = DataCustom.FeedbackTime(ndxCorrectCatch&ndxMinWT)
        AxesHandles.VevaiometricPointsCatch.XData = DV(ndxCorrectCatch&ndxMinWT)
      else
        AxesHandles.VevaiometricPointsErr.YData = -1
        AxesHandles.VevaiometricPointsErr.XData = 0
        AxesHandles.VevaiometricPointsCatch.YData = -1
        AxesHandles.VevaiometricPointsCatch.XData = 0
      end
    end
    '''
    ## Trial rate
    if TaskParametersGUI.ShowTrialRate:
      x = (TrialStartTimestamp-np.min(TrialStartTimestamp))/60
      y = np.arange(len(DataCustom.ChoiceLeft))
      AxesHandles.TrialRate.set_data(x, y)
      if len(x) > 1:
        AxesHandles.HandleTrialRate.set_xlim(0, x.max())
        AxesHandles.HandleTrialRate.set_ylim(0, y.max())

    if TaskParametersGUI.ShowFix:
      ## Stimulus delay
      clearAxesData(AxesHandles.HandleFix)
      x = DataCustom.FixDur[DataCustom.FixBroke]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min, x_max = histNumBins(x, 50)
      AxesHandles.HandleFix.hist(x, bins=num_bins, color='r', edgecolor='none')
      x = DataCustom.FixDur[~DataCustom.FixBroke]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min2, x_max2 = histNumBins(x, 50)
      AxesHandles.HandleFix.hist(x, bins=num_bins, color='b', edgecolor='none')
      AxesHandles.HandleFix.set_xlim(min(x_min, x_min2), max(x_max, x_max2))
      BreakP = np.mean(DataCustom.FixBroke)
      cornertext(AxesHandles.HandleFix, f"P={BreakP:.2f}")

    ## ST
    if TaskParametersGUI.ShowST:
      clearAxesData(AxesHandles.HandleST)
      x = DataCustom.ST[DataCustom.EarlyWithdrawal]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min, x_max = histNumBins(x, 50)
      AxesHandles.HandleST.hist(x, bins=num_bins, color='r', edgecolor='none')
      x = DataCustom.ST[~DataCustom.EarlyWithdrawal]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min2, x_max2 = histNumBins(x, 50)
      AxesHandles.HandleST.hist(x, bins=num_bins, color='b', edgecolor='none')
      AxesHandles.HandleST.set_xlim(min(x_min, x_min2), max(x_max, x_max2))
      EarlyP = np.sum(DataCustom.EarlyWithdrawal)/np.sum(~DataCustom.FixBroke)
      cornertext(AxesHandles.HandleST, f"P={EarlyP:.2f}")

    ## Feedback delay (exclude catch trials and error trials, if set on catch)
    if TaskParametersGUI.ShowFeedback:
      clearAxesData(AxesHandles.HandleFeedback)
      if TaskParametersGUI.CatchError:
        ndxExclude = DataCustom.ChoiceCorrect[iTrial] == 0 # exclude error trials if they are set on catch
      else:
        ndxExclude = np.atleast_1d(np.full((iTrial), False))

      x = DataCustom.FeedbackTime[~DataCustom.Feedback[:iTrial]&~DataCustom.CatchTrial[:iTrial]&~ndxExclude]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min, x_max = histNumBins(x, 100)
      AxesHandles.HandleFeedback.hist(x, bins=num_bins, color='r', edgecolor='none')
      # AxesHandles.HistNoFeed.Normalization = 'probability'
      x = DataCustom.FeedbackTime[DataCustom.Feedback[:iTrial]&~DataCustom.CatchTrial[:iTrial]&~ndxExclude]*1000
      x = x[~np.isnan(x)]
      num_bins, x_min2, x_max2 = histNumBins(x, 50)
      AxesHandles.HandleFeedback.hist(x, bins=num_bins, color='b', edgecolor='none')
      AxesHandles.HandleFeedback.set_xlim(min(x_min, x_min2), max(x_max, x_max2))
      # AxesHandles.HistFeed.Normalization = 'probability'
      ChoiceLeft = DataCustom.ChoiceLeft.astype(np.bool)
      denominator = sum(~DataCustom.CatchTrial[:iTrial]&~ndxExclude&ChoiceLeft[:iTrial]==1)
      denominator = max(1, denominator)
      LeftSkip = np.sum(~DataCustom.Feedback[:iTrial]&~DataCustom.CatchTrial[:iTrial]&~ndxExclude&ChoiceLeft[:iTrial]==1)/denominator
      denominator = sum(~DataCustom.CatchTrial[:iTrial]&~ndxExclude&ChoiceLeft[:iTrial]==0)
      denominator = max(1, denominator)
      RightSkip = np.sum(~DataCustom.Feedback[:iTrial]&~DataCustom.CatchTrial[:iTrial]&~ndxExclude&ChoiceLeft[:iTrial]==0)/denominator
      cornertext(AxesHandles.HandleFeedback, f"L={LeftSkip:.2f}",
                                             f"R={RightSkip:.2f}")

  return AxesHandles

def histNumBins(x, bins_width):
  #return np.ceil(x.max()/bins_width).astype(np.int) if len(x) else 1
  if len(x):
    return np.arange(0, max(x) + bins_width, bins_width), \
           max(0, x.min() - bins_width), x.max() + bins_width
  else:
    return None, 0, 1#[0, 1] # Try to mimic matlab

def clearAxesData(ax):
  for artist in (ax.lines + ax.collections):
    artist.remove()

'''
def rescaleX(AxesHandle, CurrentTrial, nTrialsToShow):
  FractionWindowStickpoint = .75 % After this fraction of visible trials, the trial position in the window "sticks" and the window begins to slide through trials.
  mn = max(round(CurrentTrial - FractionWindowStickpoint*nTrialsToShow),1)
  mx = mn + nTrialsToShow - 1
  set(AxesHandle,'XLim',[mn-1 mx+1])
  return mn, mx
'''

def cornertext(ax, *strs):
  for i, txt in enumerate(strs):
    ax.text(0.045,  1-((i+1)*0.05), txt, fontsize=8, va='top',
            transform=ax.transAxes, backgroundcolor=[1,1,1])
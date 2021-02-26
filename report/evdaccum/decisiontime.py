from enum import IntFlag, auto
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from report.definitions import MouseState
from report import analysis
from report.utils import grpBySess
from .evdutils import fltrSsns, plotSides, plotShortLongWT

class Plots(IntFlag):
  DecisionTimeHist = auto()
  DecisionTimePsych = auto()
  EWDVsDiff = auto()
  EWDVsDiffHist = auto()
  DecisionTimeVsDiff = auto()
  DecisionTimeVsDiffHist = auto()
  ShortLongDecisionTime = auto()
  MovementTimeVsDiff = auto()
  MovementTimeVsDiffHist = auto()

AllPlots = sum([plot for plot in Plots])
NoPlots = 0

def decisionTime(df, *, animal_plots, sess_plots, all_animals_plots,
                 min_easiest_perf, exp_type, **kargs):
  normalized_dfs = []
  save_prefix = kargs.pop("save_prefix") # We will need this args here
  cut_below_trial_num = kargs.pop("cut_below_trial_num")
  for animal_name, animal_df in df.groupby(df.Name):
    # Find the most common min-sampling period and use it
    if len(animal_df) < 400:
      continue
    fltrd_df = animal_df[animal_df.MinSample ==
                         animal_df.MinSample.mode().iloc[0]]
    print(f"Min sampling for {animal_name} = {fltrd_df.MinSample.unique()}")
    fltrd_df = fltrd_df[fltrd_df.GUI_StimAfterPokeOut == 0]
    fltrd_df = fltrd_df[(fltrd_df.OptoEnabled == 0) |
                        fltrd_df.OptoEnabled.isna()]
    fltrd_df = fltrd_df[fltrd_df.GUI_FeedbackDelaySelection.isin([1, 4])]
    fltrd_df = fltrd_df[fltrd_df.GUI_MouseState != MouseState.FreelyMoving]
    fltrd_df = fltrd_df[fltrd_df.TrialNumber >= cut_below_trial_num]
    if not len(fltrd_df):
      continue
    fltrd_df = grpBySess(fltrd_df).filter(fltrSsns,
                                          min_easiest_perf=min_easiest_perf,
                                          exp_type=exp_type)
    if not len(fltrd_df):
      continue
    altr_fltrd_df1 = fltrd_df[((fltrd_df.GUI_RewardAfterMinSampling == 0) |
                               (fltrd_df.CenterPortRewAmount == 0)) &
                              (fltrd_df.ST <= fltrd_df.MinSample)]
    altr_fltrd_df2 = fltrd_df[(fltrd_df.GUI_RewardAfterMinSampling == 1) &
                              (fltrd_df.CenterPortRewAmount ==
                               fltrd_df.CenterPortRewAmount.mode().iloc[0])]
    if len(altr_fltrd_df1) > len(altr_fltrd_df2):
      print(f"Using CenterReward = 0. No reward len: {len(altr_fltrd_df1)} - "
            f"With center-rwd len: {len(altr_fltrd_df2)}")
      fltrd_df = altr_fltrd_df1
    else:
      print(f"Using CenterReward = "
            f"{altr_fltrd_df2.CenterPortRewAmount.iloc[0]}. "
            f"With CenterReward len: {len(altr_fltrd_df2)} - With no "
            f"center-rwd len: {len(altr_fltrd_df1)}")
      fltrd_df = altr_fltrd_df2
    rt_df = fltrd_df
    #rt_df = fltrd_df[fltrd_df.calcReactionTime.notnull()]
    del fltrd_df # Blow up on any bugs that reference fltrd_df
    if len(rt_df[rt_df.ChoiceCorrect.notnull()]) < 200:
      print(f"Skipping: {animal_name} with num trials: {len(rt_df)} < 200")
      continue
    else:
      print(animal_name, "- Fltrd rt df len:", len(rt_df))
    _decisionTimePlots(animal_name=animal_name, rt_df=rt_df, plots=animal_plots,
                       is_normalized=False, save_prefix=save_prefix, **kargs)
    if sess_plots != NoPlots:
      for sess_info, sess_df in grpBySess(rt_df):
        print(animal_name, "Date", sess_info)
        name = f"{animal_name}_{sess_info[0]}_Sess{sess_info[1]}"
        print("Name:", name)
        new_save_prefix = save_prefix + f"/{animal_name}_sess/"
        print(f"Name: {name} - Session len: {sess_df}")
        _decisionTimePlots(animal_name=name, rt_df=sess_df, plots=sess_plots,
                           save_prefix=new_save_prefix, **kargs)

    rt_norm = rt_df.calcReactionTime / rt_df.calcReactionTime.max()
    mt_norm = rt_df.calcMovementTime / rt_df.calcMovementTime.max()
    rt_df["calcReactionTime"] = rt_norm
    rt_df["calcMovementTime"] = mt_norm
    normalized_dfs.append(rt_df)
    # if len(normalized_dfs) == 2:
    #   break

  if all_animals_plots != NoPlots:
    normalized_dfs = pd.concat(normalized_dfs)
    _decisionTimePlots(animal_name="All animals", rt_df=normalized_dfs,
                       plots=all_animals_plots, is_normalized=True,
                       save_prefix=save_prefix, **kargs)


def _decisionTimePlots(*, animal_name, rt_df, short_long_quantile,
                       quantile_top_bottom, grpby, periods, plots,
                       plot_only_all, save_figs, save_prefix, is_normalized):
    if plots & Plots.DecisionTimeHist:
      fig, ax_hist = plt.subplots(1,1)
      fig.set_size_inches(analysis.SAVE_FIG_SIZE[0], analysis.SAVE_FIG_SIZE[1])
      _decisionTimeDist(ax=ax_hist, df=rt_df, df_plot_quantile=False,
                        animal_name=animal_name)
      plt.show()

    if plots & Plots.DecisionTimePsych:
      PsycStim_axes = analysis.psychAxes(animal_name)
      analysis.psychAnimalSessions(rt_df, animal_name, PsycStim_axes,
                                   analysis.METHOD)
      if save_figs:
        analysis.savePlot(save_prefix + animal_name + "_sampling_data_psych")
      plt.show()

    if not is_normalized and plots & (Plots.EWDVsDiff | Plots.EWDVsDiffHist):
      ewd_df = rt_df[rt_df.EarlyWithdrawal == True]
      plotSides(ewd_df, col_name="ST", # Plot how long the animal stayed
                friendly_col_name="Sampling Time in Early-Widthdrawal Trials",
                periods=periods, grpby=grpby, plot_only_all=True,
                plot_vsDiff=plots & Plots.EWDVsDiff,
                plot_hist=plots & Plots.EWDVsDiffHist,
                animal_name=animal_name,
                y_label="Sampling Time",
                quantile_top_bottom=0,
                legend_loc="upper center", save_figs=save_figs,
                save_prefix=save_prefix, save_postfix="_ewd_vs_diff")

    if plots & (Plots.DecisionTimeVsDiff | Plots.DecisionTimeVsDiffHist):
      friendly_col_name = f"{'Norm. ' if is_normalized else ''}Decision Time"
      plotSides(rt_df, col_name="calcReactionTime",
                friendly_col_name=friendly_col_name,
                periods=periods, grpby=grpby, plot_only_all=plot_only_all,
                plot_vsDiff=plots & Plots.DecisionTimeVsDiff,
                plot_hist=plots & Plots.DecisionTimeVsDiffHist,
                animal_name=animal_name, y_label="Decision Time (S)",
                quantile_top_bottom=quantile_top_bottom,
                legend_loc="upper center",
                save_figs=save_figs, save_prefix=save_prefix,
                save_postfix="_reaction_vs_diff")

    if plots & Plots.ShortLongDecisionTime:
      friendly_col_name = f"{'Norm. ' if is_normalized else ''}Decision Time"
      plotShortLongWT(rt_df, col_name="calcReactionTime",
                      friendly_col_name=friendly_col_name, periods=periods,
                      animal_name=animal_name,
                      short_long_quantile=short_long_quantile,
                      save_figs=save_figs, save_prefix=save_prefix,
                      save_postfix="_reaction_short_long")

    if plots & (Plots.MovementTimeVsDiff | Plots.MovementTimeVsDiffHist):
      friendly_col_name = f"{'Norm. ' if is_normalized else ''}Movement Time"
      plotSides(rt_df, col_name="calcMovementTime",
                friendly_col_name=friendly_col_name,
                periods=periods, grpby=grpby, plot_only_all=plot_only_all,
                plot_vsDiff=plots & Plots.MovementTimeVsDiff,
                plot_hist=plots & Plots.MovementTimeVsDiffHist,
                animal_name=animal_name, y_label="Movement Time (S)",
                quantile_top_bottom=quantile_top_bottom,
                legend_loc="upper center",
                save_figs=save_figs, save_prefix=save_prefix,
                save_postfix="_decision_movement_vs_diff")

def _decisionTimeDist(*, ax, df, df_plot_quantile, animal_name):
  df = df[df.ChoiceCorrect.notnull()]
  df.loc[df.calcReactionTime > 10, "calcReactionTime"] = 10
  num_hist_bins = int(np.ceil(df.calcReactionTime.max()*4))
  print("Hist bins:", num_hist_bins)
  # Break each second to 4 bins
  df_correct = df[df.ChoiceCorrect == True].calcReactionTime
  df_incorrect = df[df.ChoiceCorrect == False].calcReactionTime
  ax.hist([df_correct, df_incorrect], bins=num_hist_bins,
          stacked=True, color=['lime', 'r'], label=["Correct", "Incorrect"])
  if df_plot_quantile:
    for quantile in [0.99]:#[0.75, 0.9, 0.95, 0.99]:
      quantile_val = df_plot_quantile.calcReactionTime.quantile(quantile)
      x = np.around(quantile_val*4)/4
      print(f"quantile {quantile} = {quantile_val} - X: {x}")
      ax.axvline(x, linestyle='dashed', label=f'{quantile} Quantile', color='k')
  ax.legend(loc='upper right')
  ax.set_title("Decision Time Dist - {}".format(animal_name))
  ax.set_xlim(xmin=0, xmax=10)

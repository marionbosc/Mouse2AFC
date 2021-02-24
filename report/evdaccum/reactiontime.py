from enum import IntFlag, auto
import numpy as np
import matplotlib.pyplot as plt
from report.definitions import MouseState, ExpType
from report import analysis
from .evdutils import GroupBy, plotSides, plotShortLongWT

class Plots(IntFlag):
  MinSampleDistHist = auto()
  ReactionTimeDistHist = auto()
  ReactionTimePsych = auto()
  ReactionTimeVsDiff = auto()
  ReactionTimeVsDiffHist = auto()
  ShortLongReactionTime = auto()
  MovementTimeVsDiff = auto()
  MovementTimeVsDiffHist = auto()

AllPlots = sum([plot for plot in Plots])
NoPlots = 0

def reactionTime(df, *, overall_plots, sess_plots, **kargs):
  cut_below_trial_num = kargs.pop("cut_below_trial_num")
  for animal_name, animal_df in df.groupby(df.Name):
    _processAnimal(animal_name, animal_df,
                   cut_below_trial_num=cut_below_trial_num,
                   overall_plots=overall_plots, sess_plots=sess_plots, **kargs)

def _processAnimal(animal_name, animal_df, *, cut_below_trial_num,
                   overall_plots, sess_plots, **kargs):
  STIMULUS_TIME_MIN = 2
  animal_df = animal_df[animal_df.GUI_StimAfterPokeOut == 0]
  animal_df = animal_df[animal_df.GUI_MouseState != MouseState.FreelyMoving]
  animal_df = animal_df[(animal_df.GUI_RewardAfterMinSampling == False) |
                        (animal_df.CenterPortRewAmount == 0)]
  # animal_df = animal_df[((animal_df.GUI_MinSampleType.isin([np.nan, 1])) &
  #                        (animal_df.GUI_MinSampleMax < 0.5)) |
  #                      ((animal_df.GUI_MinSampleType == 2) &
  #                       (animal_df.GUI_MinSampleMin < 0.5))]
  animal_df = animal_df[animal_df.MinSample < 0.75]
  animal_df = animal_df[animal_df.ST.notnull()]
  animal_df = animal_df[animal_df.GUI_StimulusTime >= STIMULUS_TIME_MIN]
  animal_df = animal_df[animal_df.TrialNumber >= cut_below_trial_num]
  if not len(animal_df) or animal_name in ["RDK_ThyF2", "N1"]:
    return
  print("Fonud: {} - Num trials: {:,}".format(animal_name, len(animal_df)))

  st_df = animal_df
  #st_df = st_df[(0.4 <= st_df.GUI_CalcLeftBias) & (st_df.GUI_CalcLeftBias <= 0.6)]
  #st_df = st_df[st_df.GUI_MinSampleType != 4]
  #st_df = st_df[st_df.SessionPerformance >= 70]
  from utils import grpBySess
  min_easiest_perf = kargs.pop("min_easiest_perf")
  exp_type = kargs.pop("exp_type")
  st_df = grpBySess(st_df).filter(_fltrSSn, exp_type=exp_type,
                                  min_easiest_perf=min_easiest_perf)
  if len(st_df) < 400:
    return

  save_prefix = kargs.pop("save_prefix")
  _reactionTimePerDF(animal_name=animal_name, df=st_df, plots=overall_plots,
                     save_prefix=save_prefix, **kargs)
  if sess_plots != NoPlots: # Don't process at all and save time if not needed
    for sess_info, sess_df in grpBySess(st_df):
      print(animal_name, "Date", sess_info)
      name = f"{animal_name}_{sess_info[0]}_Sess{sess_info[1]}"
      print("Name:", name)
      new_save_prefix = save_prefix + f"/{animal_name}_sess/"
      _reactionTimePerDF(animal_name=name, df=sess_df, plots=sess_plots,
                         save_prefix=new_save_prefix, **kargs)

def _fltrSSn(sess_df, exp_type, min_easiest_perf):
  sess_df = sess_df[sess_df.GUI_ExperimentType == exp_type]
  df_choice = sess_df[sess_df.ChoiceCorrect.notnull()]
  df_choice = df_choice[df_choice.Difficulty3.notnull()]
  if len(df_choice) < 50:
    print(f"Insufficient trials ({len(df_choice)}) for "
          f"{sess_df.Date.iloc[0]}-Sess{sess_df.SessionNum.iloc[0]}")
    return False
  trial_difficulty_col = df_choice.DV.abs() * 100
  if exp_type != ExpType.RDK:
    trial_difficulty_col = (trial_difficulty_col/2)+50
  easiest_diff = df_choice[trial_difficulty_col == df_choice.Difficulty1]
  if len(easiest_diff):
    easiest_perf = \
      len(easiest_diff[easiest_diff.ChoiceCorrect == 1]) / len(easiest_diff)
  else:
    easiest_perf = -1
  easiest_perf *= 100
  if easiest_perf < min_easiest_perf:
    print(f"Bad performance ({easiest_perf:.2f}%) for "
          f"{sess_df.Date.iloc[0]}-Sess{sess_df.SessionNum.iloc[0]} - "
          f"Len: {len(df_choice)}")
  return easiest_perf >= min_easiest_perf

def _reactionTimePerDF(animal_name, df, *, plots, quantile_top_bottom, grpby,
                       short_long_quantile, plot_only_all, save_figs,
                       save_prefix):
  if plots == NoPlots:
    return

  df_valid_st = df[df.ST.notnull()]
  del df # We don't need it from this point it, raise an error if it was used
  # Overstaying is when the maximum time sampling time is reached but the animal
  # didn't do a decision yet. In such case, we calculate how long the animal
  # took to move from begging of sampling by adding both the stimulus time and
  # the animal's reaction time.
  # Subtract 5ms, as sometimes Bpod might give a little bit earlier time than
  # expected
  df_overstay = df_valid_st[df_valid_st.ST >=
                            df_valid_st.GUI_StimulusTime - 0.005]
  df_accepted = df_valid_st[~df_valid_st.index.isin(df_overstay.index)]
  print("Reaction time len:", len(df_accepted),
        "- MinSamplingMax dist:", df_valid_st.GUI_MinSampleMax.value_counts())

  FILTER_QUANTILE = False # 0.99
  df_plot_quantile = df_valid_st if FILTER_QUANTILE else None

  if plots & (Plots.MinSampleDistHist | Plots.ReactionTimeDistHist):
    ROWS = 1
    cols = 0 # initially
    if plots & Plots.MinSampleDistHist: cols += 1
    if plots & Plots.ReactionTimeDistHist: cols += 1
    fig, axs = plt.subplots(ROWS,cols)
    fig.set_size_inches(cols*analysis.SAVE_FIG_SIZE[0],
                        ROWS*analysis.SAVE_FIG_SIZE[1])
    if cols == 1: axs = [axs]
    if plots & Plots.MinSampleDistHist:
      _minSampleDist(ax=axs[0], df=df_valid_st, animal_name=animal_name)
    if plots & Plots.ReactionTimeDistHist:
      _reactionTimeDist(ax=axs[-1], df=df_accepted, df_overstay=df_overstay,
                        df_plot_quantile=df_plot_quantile,
                        animal_name=animal_name)
    if save_figs:
      analysis.savePlot(save_prefix + animal_name + "_sampling_hist")
    plt.show()

  if FILTER_QUANTILE:
    df_accepted = df_valid_st[df_valid_st.ST <=
                              df_valid_st.ST.quantile(FILTER_QUANTILE)]
  if plots & Plots.ReactionTimePsych:
    PsycStim_axes = analysis.psychAxes(animal_name)
    analysis.psychAnimalSessions(df_accepted, animal_name, PsycStim_axes,
                                analysis.METHOD)
    if save_figs:
      analysis.savePlot(save_prefix + animal_name + "_sampling_data_psych")
    plt.show()

  if plots & (Plots.ReactionTimeVsDiff | Plots.ReactionTimeVsDiffHist):
    plotSides(df_accepted, col_name="ST", friendly_col_name="Sampling Time",
              animal_name=animal_name, y_label="Sampling Time (S)",
              quantile_top_bottom=quantile_top_bottom, grpby=grpby,
              plot_vsDiff=plots & Plots.ReactionTimeVsDiff,
              plot_only_all=plot_only_all,
              plot_hist=plots & Plots.ReactionTimeVsDiffHist,
              save_figs=save_figs, save_prefix=save_prefix,
              save_postfix="_sampling_vs_diff")

  if plots & Plots.ShortLongReactionTime:
    plotShortLongWT(df_accepted, col_name="ST",
                    friendly_col_name="Sampling Time",
                    animal_name=animal_name,
                    save_postfix="_sampling_short_long",
                    short_long_quantile=short_long_quantile,
                    save_figs=save_figs, save_prefix=save_prefix)

  if plots & (Plots.MovementTimeVsDiff | Plots.MovementTimeVsDiffHist):
    plotSides(df_accepted, col_name="calcMovementTime",
              friendly_col_name="Movement Time",
              animal_name=animal_name, y_label="Movement Time (S)",
              quantile_top_bottom=quantile_top_bottom, grpby=grpby,
              plot_vsDiff=plots & Plots.MovementTimeVsDiff,
              plot_hist=plots & Plots.MovementTimeVsDiffHist,
              legend_loc="upper center", plot_only_all=plot_only_all,
              save_figs=save_figs, save_prefix=save_prefix,
              save_postfix="_sampling_movement_vs_diff")

def _minSampleDist(*, ax, df, animal_name):
  # Break each second to 20 bins
  ax.hist(df.MinSample, bins=int(np.ceil(df.MinSample.max() * 20)))
  ax.set_title("Min. Sampling Dist - {}".format(animal_name))
  ax.set_xlim(xmin=0, xmax=2)

def _reactionTimeDist(*, ax, df, df_overstay, df_plot_quantile, animal_name):
  # Break each second to 4 bins
  overstay = df_overstay.ST + df_overstay.calcReactionTime
  overstay[overstay > 10] = 10
  max_st = overstay.max() if len(overstay) else df.ST.max()
  num_hist_bins = int(np.ceil(max_st*4))
  print("Hist bins:", num_hist_bins)
  accepted_correct = df[df.ChoiceCorrect == True].ST
  accepted_incorrect = df[df.ChoiceCorrect == False].ST
  ax.hist([accepted_correct, accepted_incorrect, overstay], bins=num_hist_bins,
          stacked=True, color=['lime', 'r', 'k'],
          label=["Correct", "Incorrect", "Overstay"])
  if df_plot_quantile:
    for quantile in [0.99]:#[0.75, 0.9, 0.95, 0.99]:
      quantile_val = df_plot_quantile.ST.quantile(quantile)
      x = np.around(quantile_val*4)/4
      print(f"quantile {quantile} = {quantile_val} - X: {x}")
      ax.axvline(x, linestyle='dashed', label=f'{quantile} Quantile', color='k')
  ax.legend(loc='upper right')
  ax.set_title("Reaction Time Dist - {}".format(animal_name))
  ax.set_xlim(xmin=0, xmax=10)

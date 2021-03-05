from enum import IntFlag, auto
import numpy as np
import matplotlib.pyplot as plt
from report.definitions import MouseState
from report import analysis
from report.utils import grpBySess
from .evdutils import plotSides, plotShortLongWT, fltrSsns, splitByBins, timeHist

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
  dv_bins_edges = kargs.pop("dv_bins_edges")
  for animal_name, animal_df in df.groupby(df.Name):
    _processAnimal(animal_name, animal_df, dv_bins_edges=dv_bins_edges,
                   cut_below_trial_num=cut_below_trial_num,
                   overall_plots=overall_plots, sess_plots=sess_plots, **kargs)

def _processAnimal(animal_name, animal_df, *, cut_below_trial_num,
                   overall_plots, sess_plots, min_total_num_pts_per_animal,
                   dv_bins_edges, **kargs):
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
  if not len(animal_df):# or animal_name in ["RDK_ThyF2", "N1"]:
    return
  print("Fonud: {} - Num trials: {:,}".format(animal_name, len(animal_df)))

  st_df = animal_df
  #st_df = st_df[(0.4 <= st_df.GUI_CalcLeftBias) & (st_df.GUI_CalcLeftBias <= 0.6)]
  #st_df = st_df[st_df.GUI_MinSampleType != 4]
  #st_df = st_df[st_df.SessionPerformance >= 70]
  min_easiest_perf = kargs.pop("min_easiest_perf")
  exp_type = kargs.pop("exp_type")
  st_df = grpBySess(st_df).filter(fltrSsns, exp_type=exp_type,
                                  min_easiest_perf=min_easiest_perf)
  if len(st_df) < min_total_num_pts_per_animal:
    return

  save_prefix = kargs.pop("save_prefix")
  _loopDVBins(df=st_df, dv_bins_edges=dv_bins_edges, animal_name=animal_name,
              plots=overall_plots, save_prefix=save_prefix, **kargs)
  if sess_plots != NoPlots: # Don't process at all and save time if not needed
    for sess_info, sess_df in grpBySess(st_df):
      print(animal_name, "Date", sess_info)
      name = f"{animal_name}_{sess_info[0]}_Sess{sess_info[1.01]}"
      print("Name:", name)
      new_save_prefix = save_prefix + f"/{animal_name}_sess/"
      _loopDVBins(df=st_df, dv_bins_edges=dv_bins_edges,
                  animal_name=animal_name, plots=sess_plots,
                  save_prefix=new_save_prefix, **kargs)

def _loopDVBins(df, dv_bins_edges, animal_name, **kargs):
  if len(dv_bins_edges):
    dv_bins_edges = [0] + dv_bins_edges + [1]
    for dv_rng, _, dv_df in splitByBins(df, dv_bins_edges, combine_sides=True):
      new_animal_name = f"{animal_name} — DV={dv_rng.left}-{dv_rng.right}"
      _reactionTimePerDF(dv_df, animal_name=new_animal_name, **kargs)

  else:
    _reactionTimePerDF(df, animal_name=animal_name, **kargs)

def _reactionTimePerDF(df, *, animal_name, plots, periods, quantile_top_bottom,
                       grpby, short_long_quantile, plot_only_all, save_figs,
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
      overstay_col = df_overstay.ST + df_overstay.calcReactionTime
      timeHist(ax=axs[-1], df=df_accepted, col_name="ST", normalized=False,
              friendly_col_name="Reaktionszeit", overstay_col=overstay_col,
              gauss_fit=False, max_x_lim=10, bins_per_sec=4, plot_only_all=False,
              stacked=True, quantiles_to_plot=None,
              quantiles_to_plot_per_group=None,
              animal_name=animal_name, legend_loc='upper right')
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
    plotSides(df_accepted, col_name="ST", friendly_col_name="Reaktionszeit",
              periods=periods, animal_name=animal_name,
              y_label="Reaktionszeit (Sekunden)",
              quantile_top_bottom=quantile_top_bottom, grpby=grpby,
              plot_vsDiff=plots & Plots.ReactionTimeVsDiff,
              plot_only_all=plot_only_all,
              plot_hist=plots & Plots.ReactionTimeVsDiffHist,
              save_figs=save_figs, save_prefix=save_prefix,
              save_postfix="_sampling_vs_diff")

  if plots & Plots.ShortLongReactionTime:
    plotShortLongWT(df_accepted, col_name="ST",
                    friendly_col_name="Reaction Time", periods=periods,
                    animal_name=animal_name,
                    save_postfix="_sampling_short_long",
                    short_long_quantile=short_long_quantile,
                    save_figs=save_figs, save_prefix=save_prefix)

  if plots & (Plots.MovementTimeVsDiff | Plots.MovementTimeVsDiffHist):
    plotSides(df_accepted, col_name="calcMovementTime",
              friendly_col_name="Movement Time", periods=periods,
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

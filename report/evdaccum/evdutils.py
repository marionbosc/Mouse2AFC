from enum import Flag, auto
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from report import analysis
from report.clr import Choice, Difficulty as DifficultyClr

class GroupBy(Flag):
  Difficulty = auto()
  EqualSize = auto()

def plotSides(df, *, col_name, friendly_col_name, animal_name, grpby,
              quantile_top_bottom, y_label, plot_vsDiff, plot_hist, save_figs,
              save_prefix, save_postfix, legend_loc=None, plot_only_all=False):
  if not plot_vsDiff and not plot_hist:
    return
  df = df[df.ChoiceCorrect.notnull()]
  REVERSED, NOT_REVERSED=True, False
  # THe next part is a bad hack to group direction together, sorry about this...
  df_incorrect = df[df.ChoiceCorrect == 0]
  df_all = df.copy()
  df_all.loc[df_incorrect.index, 'DV'] = -df_incorrect.DV
  iter_list =    [(df_all, Choice.All, "All", NOT_REVERSED)]
  if not plot_only_all:
    iter_list += [
          (df[df.ChoiceCorrect == 1], Choice.Correct,  "Correct", NOT_REVERSED),
          (df_incorrect, Choice.Incorrect,"Incorrect", REVERSED)]

  COLS = 2
  rows = 0
  if plot_vsDiff: rows += 1
  if plot_hist: rows += 1
  fig, axs = plt.subplots(rows, COLS)
  fig.set_size_inches(COLS*analysis.SAVE_FIG_SIZE[0],
                      rows*analysis.SAVE_FIG_SIZE[1])
  if rows == 1:
    axs = [axs]
  if plot_vsDiff:
    top_row_axs = axs[0]
  if plot_hist:
    bottom_row_axs = axs[-1]

  if grpby == GroupBy.Difficulty:
    bins_2sided, bins_1sided = None, None
  else:
    assert grpby == GroupBy.EqualSize
    bins_2sided = rngByQuantile(df_all, periods=3, separate_zero=False)
    bins_1sided = rngByQuantile(df_all, periods=3, separate_zero=False,
                                combine_sides=True)
  for side_df, color, label, li_is_reversed in iter_list:
    kargs = Kargs(df=side_df, col_name=col_name, friendly_name=friendly_col_name,
                  color=color, label=label,
                  quantile_top_bottom=quantile_top_bottom,
                  y_label=y_label, animal_name=animal_name)
    for ax_idx, overlap_sides in enumerate([False, True]):
      is_reversed = li_is_reversed and not overlap_sides
      quantile_bins = bins_1sided if overlap_sides else bins_2sided
      if plot_vsDiff:
        metricVsDiff(axes=top_row_axs[ax_idx], bins=quantile_bins,
                     overlap_sides=overlap_sides, is_reversed=is_reversed,
                     **kargs)

  if plot_vsDiff and legend_loc:
    top_row_axs[0].legend(loc=legend_loc,prop={'size':'x-small'})
    top_row_axs[1].legend(loc=legend_loc,prop={'size':'x-small'})

  if plot_hist:
    plotHist(axs=bottom_row_axs, df=df_all, col_name=col_name,
             bins_1sided=bins_1sided, bins_2sided=bins_2sided,
             quantile_top_bottom=quantile_top_bottom, animal_name=animal_name,
             plot_only_all=plot_only_all)

  if save_figs:
    analysis.savePlot(save_prefix + animal_name + save_postfix)
  plt.show()

def plotHist(*, axs, df, col_name, bins_1sided, bins_2sided,
             quantile_top_bottom, animal_name, plot_only_all):
  for ax_idx, overlap_sides in enumerate([False, True]):
    quantile_bins = bins_1sided if overlap_sides else bins_2sided
    xs = []
    if plot_only_all:
      x_count = []
    else:
      x_correct_count, x_incorrect_count = [], []
    # We assumed the incorrect trials are already reversed here bu the calling
    # function.
    for dv_single, dv_df in _loopDfByDV(df, col_name=col_name,
                                        bins=quantile_bins,
                                        overlap_sides=overlap_sides,
                                        is_reversed=False,
                                       quantile_top_bottom=quantile_top_bottom):
      xs.append(dv_single)
      if plot_only_all:
        x_count.append(len(dv_df))
      else:
        x_correct_count.append(len(dv_df[dv_df.ChoiceCorrect == True]))
        x_incorrect_count.append(len(dv_df[dv_df.ChoiceCorrect == False]))
    BAR_WIDTH=0.06 * 100 # Convert to coherence
    xs = np.array(xs) * 100
    xs = np.around(xs)
    if plot_only_all:
      bars = [x_count]
      colors = [Choice.All]
      labels = ["All"]
    else:
      bars = [x_correct_count, x_incorrect_count]
      colors = [Choice.Correct, Choice.Incorrect]
      labels = ["Correct",
                "Incorect" + (" (Reversed)"  if not overlap_sides else "")]
    last_bottom = 0
    for bar, color, label in zip(bars, colors, labels):
      axs[ax_idx].bar(xs, bar, color=color, width=BAR_WIDTH, label=label,
                      bottom=last_bottom, edgecolor='k')
      last_bottom = bar
    axs[ax_idx].legend(prop={'size':'x-small'})
    axs[ax_idx].set_title("Norm. Difficulties Dist. - {}".format(animal_name))
    axs[ax_idx].set_xlabel("Coherence %")
    axs[ax_idx].set_ylabel("Trials Count (Norm. per Difficulty")

def fltrQuantile(df_or_col, quantile_top_bottom, col_name_if_df=None):
  if isinstance(df_or_col, pd.DataFrame):
    assert col_name_if_df is not None
    col_vals = df_or_col[col_name_if_df]
  else:
    col_vals = df_or_col
  return df_or_col[(col_vals.quantile(quantile_top_bottom) < col_vals) &
                   (col_vals < col_vals.quantile(1 - quantile_top_bottom))]

def shortLongWT(*, short_df, long_df, label, quantile, animal_name, axes):
  #animal_name = " ".join(short_df.Name.unique()).strip()
  axes_title = animal_name + " (Short-{} < {} quantile)".format(label, quantile)
  PsycStim_axes = analysis.psychAxes(axes_title, axes=axes)
  for data, color, title in [(short_df,'purple',"Short-{}".format(label)),
                             (long_df,'blue',"Long-{}".format(label))]:
    title += (f" - {len(data):,} pts ("
              f"correct: {len(data[data.ChoiceCorrect==1]):,}, "
              f"incorrect: {len(data[data.ChoiceCorrect==0]):,})")
    LINE_SIZE=2
    analysis._psych(data, PsycStim_axes, color, LINE_SIZE, title,
                    plot_points=False, SEM=True)
  PsycStim_axes.legend(prop={'size':'x-small'},loc='upper left')

def plotShortLongWT(df, col_name, short_long_quantile, friendly_col_name,
                    animal_name, save_figs, save_prefix, save_postfix):
  ax = plt.axes()
  short_df = df[df[col_name] <= df[col_name].quantile(short_long_quantile)]
  long_df = df[df[col_name] > df[col_name].quantile(short_long_quantile)]
  shortLongWT(short_df=short_df, long_df=long_df, label=friendly_col_name,
              animal_name=animal_name, quantile=short_long_quantile, axes=ax)
  if save_figs:
    analysis.savePlot(save_prefix + animal_name + save_postfix)
  plt.show()

def Kargs(**kargs):
  return kargs

def rngByQuantile(df, combine_sides=False, periods=3, separate_zero=True):
  _, bins = pd.qcut(df.DV.abs(), periods, retbins=True, duplicates='drop')
  bins[-1] = 1.01
  if not combine_sides:
    if separate_zero:
      bins[0] = 0.01
      _min = bins[::-1]
    else:
      bins[0] = 0
      _min = -bins[::-1][:-1] # WHat would be a cleaner syntax?
    bins = np.concatenate([_min, bins])
  else:
    if not separate_zero:
      bins[0] = 0
    else:
      bin_offset_idx = 0 if bins[0] != 0 else 1
      bins = np.concatenate([[0, 0.01], bins[bin_offset_idx:]])
  return bins

def splitByBins(df, bins, combine_sides=False):
  DV = df.DV if not combine_sides else df.DV.abs()
  groups = []
  for (left, right) in zip(bins, bins[1:]):
    if left >= 0:
      group_df = df[(left <= DV) & (DV < right)]
    else:
      group_df = df[(left < DV) & (df.DV <= right)]
    df = df[~df.index.isin(group_df.index)] # Remove already included items
    entry = pd.Interval(left=left, right=right), (left+right)/2, group_df
    groups.append(entry)
  return groups

def metricVsDiff(df, *, col_name, friendly_name, axes, overlap_sides,
                 quantile_top_bottom, animal_name, is_reversed=False, bins=None,
                 color=None, label="", y_label=None):
  x_data = []
  y_data = []
  y_data_sem = []
  count_pts = 0
  for dv_single, dv_df in _loopDfByDV(df, col_name=col_name, bins=bins,
                                      overlap_sides=overlap_sides,
                                      is_reversed=is_reversed,
                                      quantile_top_bottom=quantile_top_bottom):
    cohr = round(dv_single*100)
    # print("Cohr:", cohr, "Cohr len:", len(metric_fltrd), col_name, "mean:",
    #       metric_fltrd.mean())
    x_data.append(cohr)
    y_data.append(dv_df[col_name].mean())
    y_data_sem.append(dv_df[col_name].sem())
    count_pts += len(dv_df)

  # print("X data:", x_data)
  # print("y_data:", y_data)
  # print("y_sem:", y_data_sem)
  rvrsd_lbl = "(Reversed) " if is_reversed else ""
  label = f"{friendly_name} {label} {rvrsd_lbl}({count_pts:,} pts)"
  axes.errorbar(x_data, y_data, yerr=y_data_sem, color=color, label=label)
  axes.set_title(f"{friendly_name} vs Difficulty - {animal_name}")
  axes.set_xlabel("Coherence %")
  if y_label is None: y_label = friendly_name
  axes.set_ylabel(y_label)
  axes.legend(loc="lower left", prop={'size': 'small'})

def _loopDfByDV(df, *, col_name, overlap_sides, bins, is_reversed,
                quantile_top_bottom):
  if bins is None:
    loop_tups = analysis.splitByDV(df, combine_sides=overlap_sides,
                                   periods=3, separate_zero=False)
  else:
    loop_tups = splitByBins(df, bins, combine_sides=overlap_sides)
  groups = []
  for _, dv_single, dv_df in loop_tups:
    if is_reversed:
      dv_single *= -1
    if quantile_top_bottom:
      df_fltrd = fltrQuantile(dv_df, quantile_top_bottom=quantile_top_bottom,
                              col_name_if_df=col_name)
    else:
      df_fltrd = dv_df
    groups.append((dv_single, df_fltrd))
  return groups

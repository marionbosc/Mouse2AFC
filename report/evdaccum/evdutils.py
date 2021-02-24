import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from report import analysis
from report.clr import Choice, Difficulty as DifficultyClr

def plotSides(df, *, col_name, friendly_col_name, animal_name,
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

  for bar_idx, (side_df, color, label, li_is_reversed) in enumerate(iter_list):
    kargs = Kargs(df=side_df, col_name=col_name, friendly_name=friendly_col_name,
                  color=color, label=label,
                  quantile_top_bottom=quantile_top_bottom,
                  y_label=y_label, animal_name=animal_name)
    for ax_idx, overlap_sides in enumerate([False, True]):
      is_reversed = li_is_reversed and not overlap_sides
      if plot_vsDiff:
        dv_count = metricVsDiff(axes=top_row_axs[ax_idx],
                                overlap_sides=overlap_sides,
                                is_reversed=is_reversed, **kargs)
      if plot_hist:
        #TODO: dv_count is not calculated unless plot_vsDiff is enabled
        BAR_WIDTH=0.06 * 100 # Convert to coherence
        xs = np.array(list(dv_count.keys())) * 100
        xs = np.around(xs)
        # -1 depends on number of combinations to center bars
        xs += BAR_WIDTH*(bar_idx-1)
        # Normalze Ys
        ys = np.array(list(dv_count.values()), dtype=np.float64)
        ys /= ys.max()
        label += " (Reversed)" if is_reversed else ""
        bottom_row_axs[ax_idx].bar(xs, ys, color=color, width=BAR_WIDTH,
                                   label=label)

  if plot_vsDiff and legend_loc:
    top_row_axs[0].legend(loc=legend_loc,prop={'size':'x-small'})
    top_row_axs[1].legend(loc=legend_loc,prop={'size':'x-small'})

  if plot_hist:
    for ax in bottom_row_axs:
      ax.legend(prop={'size':'x-small'})
      ax.set_title("Norm. Difficulties Dist. - {}".format(animal_name))
      ax.set_xlabel("Coherence %")
      ax.set_ylabel("Trials Count (Norm. per Difficulty")

  if save_figs:
    analysis.savePlot(save_prefix + animal_name + save_postfix)
  plt.show()

def grpByDifficulty(df, overlap_sides, is_reversed=False, emit_colors=False):
  if is_reversed: assert overlap_sides == False
  groupby_on = df.DV.abs() if overlap_sides else df.DV
  dv_bins = np.linspace(0, 1, 4) if overlap_sides else np.linspace(-1, 1, 7)
  colors =    [DifficultyClr.Hard, DifficultyClr.Med, DifficultyClr.Easy]
  if overlap_sides:
    colors += [DifficultyClr.Easy, DifficultyClr.Med, DifficultyClr.Hard]
  grp_by_bins = pd.cut(groupby_on, dv_bins, include_lowest=not overlap_sides)
  for color_idx, (dv_interval, dv_df) in enumerate(df.groupby(grp_by_bins)):
    dv_val = dv_interval.left if dv_interval.left < 0 else dv_interval.right
    if is_reversed: dv_val *= -1
    yield (colors[color_idx], dv_val, dv_df) if emit_colors else (dv_val, dv_df)

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

def metricVsDiff(df, *, col_name, friendly_name, axes, overlap_sides,
                 quantile_top_bottom, animal_name, is_reversed=False,
                 color=None, label="", y_label=None):
  x_data = []
  y_data = []
  y_data_sem = []
  count_pts = 0
  dv_count = {}
  for _, dv_single, dv_df in analysis.splitByDV(df, combine_sides=overlap_sides,
                                                periods=3):
    if is_reversed:
      dv_single *= -1
    cohr = round(dv_single*100)
    if quantile_top_bottom:
      metric_fltrd = fltrQuantile(dv_df[col_name],
                                  quantile_top_bottom=quantile_top_bottom)
    else:
      metric_fltrd = dv_df[col_name]
    # print("Cohr:", cohr, "Cohr len:", len(dv_df), col_name, "mean:",
    #       metric_fltrd.mean())
    x_data.append(cohr)
    y_data.append(metric_fltrd.mean())
    y_data_sem.append(metric_fltrd.sem())
    count_pts += len(metric_fltrd)
    dv_count[dv_single] = len(metric_fltrd)

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
  return dv_count

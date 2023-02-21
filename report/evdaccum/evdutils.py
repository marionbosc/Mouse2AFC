from enum import Flag, auto

from pandas.core.indexes import multi
import numpy as np
import pandas as pd
from scipy.stats import gaussian_kde
import matplotlib.pyplot as plt
import matplotlib.ticker as plticker
from matplotlib.ticker import FuncFormatter
from report import analysis
from report.definitions import ExpType
from report.clr import Choice

class GroupBy(Flag):
  Difficulty = auto()
  EqualSize = auto()
  Performance = auto()

def plotSides(df, *, col_name, friendly_col_name, animal_name, periods, grpby,
              quantile_top_bottom, y_label, plot_vsDiff, plot_hist, save_figs,
              save_prefix, save_postfix, legend_loc=None, plot_only_all=False):
  if not plot_vsDiff and not plot_hist:
    return
  df_only_choice = df[df.ChoiceCorrect.notnull()]
  # Only filter if we have valid trials, otherwise it's an invalid based df, e.g
  # EarlyWithdrawals df.
  if len(df_only_choice):
    df =  df_only_choice
  else:
    print("Keeping unfiltered")
  del df_only_choice # We no longer need this
  REVERSED, NOT_REVERSED=True, False
  # THe next part is a bad hack to group direction together, sorry about this...
  df_incorrect = df[df.ChoiceCorrect == 0]
  df_all = df.copy()
  df_all.loc[df_incorrect.index, 'DV'] = -df_incorrect.DV
  iter_list =    [(df_all, Choice.All, "Alle", NOT_REVERSED)]
  if not plot_only_all:
    iter_list += [
          (df[df.ChoiceCorrect == 1], Choice.Correct,  "Korrekt", NOT_REVERSED),
          (df_incorrect, Choice.Incorrect,"Falsch", REVERSED)]

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
  elif grpby == GroupBy.Performance:
    # Do the correction on the original df, not the inverted df here
    bins_2sided = rngByPerf(df, periods=periods, separate_zero=False,
                            fit_fn_periods=10, combine_sides=False)
    bins_1sided = rngByPerf(df, periods=periods, separate_zero=False,
                            fit_fn_periods=10, combine_sides=True)
  else:
    assert grpby == GroupBy.EqualSize
    bins_2sided = rngByQuantile(df_all, periods=periods, separate_zero=False)
    bins_1sided = rngByQuantile(df_all, periods=periods, separate_zero=False,
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
        metricVsDiff(axes=top_row_axs[ax_idx], periods=periods,
                     bins=quantile_bins, overlap_sides=overlap_sides,
                     is_reversed=is_reversed, **kargs)

  if plot_vsDiff and legend_loc:
    top_row_axs[0].legend(loc=legend_loc,prop={'size':'x-small'})
    top_row_axs[1].legend(loc=legend_loc,prop={'size':'x-small'})

  if plot_hist:
    plotHist(axs=bottom_row_axs, df=df_all, col_name=col_name, periods=periods,
             bins_1sided=bins_1sided, bins_2sided=bins_2sided,
             quantile_top_bottom=quantile_top_bottom, animal_name=animal_name,
             plot_only_all=plot_only_all)

  if save_figs:
    analysis.savePlot(save_prefix + animal_name + save_postfix)
  plt.show()

def plotHist(*, axs, df, col_name, periods, bins_1sided, bins_2sided,
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
    for dv_single, dv_df in _loopDfByDV(df, periods=periods, col_name=col_name,
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
      labels = ["Alle"]
    else:
      bars = [x_correct_count, x_incorrect_count]
      colors = [Choice.Correct, Choice.Incorrect]
      labels = ["Korrekt",
                "Falsch"]
    last_bottom = 0
    for bar, color, label in zip(bars, colors, labels):
      axs[ax_idx].bar(xs, bar, color=color, width=BAR_WIDTH, label=label,
                      bottom=last_bottom, edgecolor='k')
      last_bottom = bar
    axs[ax_idx].legend(loc='lower center', prop={'size':'x-small'})
    axs[ax_idx].set_title(f"Schwierigkeitsverteilung - {animal_name}")
    axs[ax_idx].set_xlabel("Kohärenz %")
    axs[ax_idx].xaxis.set_major_formatter(
      FuncFormatter(lambda x, _: f"{int(abs(x))}%" + ("" if overlap_sides else
                              (f"{'L' if x > 0 else ('R' if x < 0 else '')}"))))
    axs[ax_idx].set_ylabel("Versuche Zählen")

def fltrQuantile(df_or_col, quantile_top_bottom, col_name_if_df=None):
  if isinstance(df_or_col, pd.DataFrame):
    assert col_name_if_df is not None
    col_vals = df_or_col[col_name_if_df]
  else:
    col_vals = df_or_col
  return df_or_col[(col_vals.quantile(quantile_top_bottom) < col_vals) &
                   (col_vals < col_vals.quantile(1 - quantile_top_bottom))]

def shortLongWT(*, short_df, long_df, periods, label, quantile, animal_name,
                axes):
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
                    plot_points=False, SEM=True, periods=periods)
  PsycStim_axes.legend(prop={'size':'x-small'},loc='upper left')

def plotShortLongWT(df, col_name, short_long_quantile, periods,
                    friendly_col_name, animal_name, save_figs, save_prefix,
                    save_postfix):
  ax = plt.axes()
  short_df = df[df[col_name] <= df[col_name].quantile(short_long_quantile)]
  long_df = df[df[col_name] > df[col_name].quantile(short_long_quantile)]
  shortLongWT(short_df=short_df, long_df=long_df, periods=periods,
              label=friendly_col_name, animal_name=animal_name,
              quantile=short_long_quantile, axes=ax)
  if save_figs:
    analysis.savePlot(save_prefix + animal_name + save_postfix)
  plt.show()

def Kargs(**kargs):
  return kargs

def rngByPerf(df, periods, fit_fn_periods, combine_sides, separate_zero=True):
  df = df[df.ChoiceLeft.notnull()]
  stims, stim_count, stim_ratio_correct = [], [], []
  for _, _, dv_df in analysis.splitByDV(df, periods=fit_fn_periods,
                                        combine_sides=combine_sides):
    if not len(dv_df):
      continue
    DV = dv_df.DV
    if combine_sides:
      DV = DV.abs()
    stims.append(DV.mean())
    stim_count.append(len(dv_df))
    perf_col = dv_df.ChoiceCorrect if combine_sides else dv_df.ChoiceLeft
    stim_ratio_correct.append(perf_col.mean())
  pars, fitFn = analysis.psychFitBasic(stims=stims, stim_count=stim_count,
                                       nfits=200,
                                       stim_ratio_correct=stim_ratio_correct)
  if combine_sides:
    possible_dvs = np.linspace(0,1,101)
  else:
    possible_dvs = np.linspace(-1,1,201)
  fits = fitFn(possible_dvs)
  min_perf = fits[0] if combine_sides else fits[possible_dvs == 0]
  max_perf_l, max_perf_r = fits[0], fits[-1]
  bins = [0]
  if separate_zero:
    if not combine_sides:
      bins = [-0.01] + bins
    bins += [0.01]
  cut_offs_perf = []
  def curBin(i, periods, is_neg):
    # If periods == 2, and we want to get 66.667% and 83.334%, then in ideal
    # case min_perf is 50% and max perf is 100%.
    max_perf = max_perf_r if not is_neg else max_perf_l
    cutoff_perf = min_perf + (max_perf-min_perf)*i/periods
    cutoff_idx = np.argmin(np.abs(fits-cutoff_perf))
    new_bin = possible_dvs[cutoff_idx]
    mult = 1 if not is_neg else -1
    # Do we need to handle close to zero cases here?
    if new_bin >= 1:
      new_bin = 1
      mult = -1*(periods-i)
    elif new_bin <= -1:
      new_bin = -1
      mult = periods-i
    while new_bin in bins:
      new_bin += 0.01*mult
    if not is_neg:
      bins.append(new_bin)
      cut_offs_perf.append(fits[cutoff_idx])
    else:
      bins.insert(0, new_bin)
      cut_offs_perf.insert(0, fits[cutoff_idx])

  for i in range(1, periods):
    curBin(i, periods, is_neg=False)
    if not combine_sides:
      curBin(i, periods, is_neg=True)
  bins += [1.01]
  if not combine_sides:
    bins = [-1.01] + bins
  # print("Closest dvs are: ", bins, "at perfms:", cut_offs_perf,
  #       "with min. perf:", min_perf, "and max perf L/R:", max_perf_l,
  #       max_perf_r)
  return bins

def rngByQuantile(df, *, periods, combine_sides=False, separate_zero=True):
  #_, bins = pd.qcut(df.DV.abs().rank(method='first'), periods, retbins=True)
  _, bins = pd.qcut(df.DV.abs(), periods, retbins=True, duplicates='drop')
  # print("Len:", bins)
  bins[-1] = 1.01
  if not combine_sides:
    if separate_zero:
      bins[0] = 0.01
      _min = bins[::-1]
    else:
      bins[0] = 0
      _min = -bins[::-1][:-1] # What would be a cleaner syntax?
    bins = np.concatenate([_min, bins])
  else:
    if not separate_zero:
      bins[0] = 0
    else:
      bin_offset_idx = 0 if bins[0] != 0 else 1
      bins = np.concatenate([[0, 0.01], bins[bin_offset_idx:]])
  # print("Returning bins:", bins)
  return bins

def splitByBins(df, bins, combine_sides=False):
  groups = []
  DV = df.DV.abs() if combine_sides else df.DV
  for dv_rng, dv_df in df.groupby(pd.cut(DV, bins, include_lowest=True)):
    # We add zero to avoid having -0.0 printed
    dv_rng = pd.Interval(np.around(dv_rng.left, 2) + 0, dv_rng.right)
    entry = dv_rng, (dv_rng.left+dv_rng.right)/2, dv_df
    groups.append(entry)
  return groups

def metricVsDiff(df, *, col_name, periods, friendly_name, axes, overlap_sides,
                 quantile_top_bottom, animal_name, is_reversed=False, bins=None,
                 color=None, label="", y_label=None):
  x_data = []
  y_data = []
  y_data_sem = []
  count_pts = 0
  for dv_single, dv_df in _loopDfByDV(df, periods=periods, col_name=col_name,
                                      bins=bins, overlap_sides=overlap_sides,
                                      is_reversed=is_reversed,
                                      quantile_top_bottom=quantile_top_bottom):
    if not len(dv_df):
      continue
    cohr = round(dv_single*100)
    # print("Cohr:", cohr, "Cohr len:", len(metric_fltrd), col_name, "mean:",
    #       metric_fltrd.mean())
    x_data.append(cohr)
    y_data.append(dv_df[col_name].mean()) #TODO: Add option for median
    y_data_sem.append(dv_df[col_name].sem())
    count_pts += len(dv_df)

  # print("X data:", x_data)
  # print("y_data:", y_data)
  # print("y_sem:", y_data_sem)
  rvrsd_lbl = "(Umgekehrt) " if is_reversed else ""
  label = f"{friendly_name} {label} {rvrsd_lbl}({count_pts:,} pts)"
  axes.errorbar(x_data, y_data, yerr=y_data_sem, color=color, label=label)
  axes.set_title(f"{friendly_name} vs Schwierigkeit - {animal_name}")
  axes.set_xlabel("Kohärenz %")
  axes.xaxis.set_major_formatter(
      FuncFormatter(lambda x, _: f"{int(abs(x))}%" + ("" if overlap_sides else
                                 f"{'L' if x > 0 else 'R' if x < 0 else ''}")))
  if y_label is None: y_label = friendly_name
  axes.set_ylabel(y_label)
  axes.legend(loc="lower left", prop={'size': 'small'})

def _loopDfByDV(df, *, col_name, overlap_sides, periods, bins, is_reversed,
                quantile_top_bottom):
  if bins is None:
    loop_tups = analysis.splitByDV(df, combine_sides=overlap_sides,
                                   periods=periods, separate_zero=False)
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

def fltrSsns(sess_df, exp_type, min_easiest_perf):
  sess_df = sess_df[sess_df.GUI_ExperimentType == exp_type]
  df_choice = sess_df[sess_df.ChoiceCorrect.notnull()]
  df_choice = df_choice[df_choice.Difficulty3.notnull()]
  if len(df_choice) and len(df_choice) < 50:
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
  if len(easiest_diff) and easiest_perf < min_easiest_perf:
    print(f"Bad performance ({easiest_perf:.2f}%) for "
          f"{sess_df.Date.iloc[0]}-Sess{sess_df.SessionNum.iloc[0]} - "
          f"Len: {len(df_choice)}")
  return easiest_perf >= min_easiest_perf


def timeHist(*, ax, df, col_name, friendly_col_name, overstay_col, max_x_lim,
             animal_name, bins_per_sec, plot_only_all, stacked, normalized,
             gauss_fit,  quantiles_to_plot, quantiles_to_plot_per_group,
             legend_loc):
  if overstay_col is not None:
    overstay_col[overstay_col > max_x_lim] = max_x_lim
  else:
    overstay_col = []
  max_x = np.amax(overstay_col) if len(overstay_col) else df[col_name].max()
  # Break each second to n bins
  bins = np.arange(0, int(np.ceil(max_x*bins_per_sec)), 1/bins_per_sec)
  if plot_only_all:
    data = [df[col_name]]
    colors = [Choice.All]
    labels = ["Alle"]
  else:
    data = [df.loc[df.ChoiceCorrect == True, col_name],
            df.loc[df.ChoiceCorrect == False, col_name]]
    colors = [Choice.Correct, Choice.Incorrect]
    labels = ["Korrekt", "Falsch"]
  if len(overstay_col):
    data += [overstay_col] # Should we do overstay per group?
    colors += ['k']
    labels += ["Länger Bleiben"]
  # [0] = histogram, ignore bins edges returned value
  counts = [np.histogram(data_grp,bins=bins)[0].astype(np.float)
          for data_grp in data]
  if normalized:
    counts = [counts_per_bin/counts_per_bin.max() for counts_per_bin in counts]
    # counts = [counts_per_bin for counts_per_bin in counts]
    labels = [f"{label} Norm." for label in labels]
  labels = [f"{label} ({len(data_grp):,} Versuche)"
            for label, data_grp in zip(labels, data)]
  last_bottom = 0
  is_bar = stacked or len(counts) == 1
  x = 0
  for count, label, color, data_grp in zip(counts, labels, colors, data):
    if len(data_grp) < 2:
      continue
    this_bins = (bins[:-1] + bins[1:])/2
    plt_label = label if not gauss_fit else None
    alpha = 1 if not gauss_fit else 0.2
    if is_bar:
      ax.bar(this_bins, count, width=1/bins_per_sec, align='center',
             bottom=last_bottom, label=plt_label, color=color, alpha=alpha)
      last_bottom += count if stacked else 0
    else:
      ax.step(this_bins+x, count, label=plt_label, color=color,
              alpha=alpha, where='mid')
      x += 0.05
    if gauss_fit:
      histGaussianFit(ax=ax, col=data_grp, col_count=count, color=color,
                      label=label, bandwith=1/bins_per_sec)

  if quantiles_to_plot:
    plotHistQuantile(ax=ax, col=df[col_name], quantiles=quantiles_to_plot,
                     color=Choice.All, bins_per_unit=bins_per_sec)
  if quantiles_to_plot_per_group:
    plotHistQuantile(ax=ax, col=df.loc[df.ChoiceCorrect == True, col_name],
                     quantiles=quantiles_to_plot_per_group,
                     color=Choice.Correct, bins_per_unit=bins_per_sec)
    plotHistQuantile(ax=ax, col=df.loc[df.ChoiceCorrect == False, col_name],
                     quantiles=quantiles_to_plot_per_group,
                     color=Choice.Incorrect, bins_per_unit=bins_per_sec)
  ax.legend(loc=legend_loc,prop={'size':'x-small'})
  ax.set_title(f"{friendly_col_name} Histogramm - {animal_name}")
  ax.set_xlim(xmin=0, xmax=max_x_lim)
  ax.set_xlabel("Sekunden")
  ax.set_ylabel("Versuche Zählen")
  loc = plticker.MultipleLocator(base=1)
  ax.xaxis.set_major_locator(loc)
  loc = plticker.MultipleLocator(base=1/bins_per_sec)
  ax.xaxis.set_minor_locator(loc)
  return ax


def histGaussianFit(*, ax, col, col_count, color, label, bandwith):
  col = col[col.notnull()]
  # col.plot.kde(ax=ax, color=color) # For a quick test without scaling
  xs = np.linspace(col.min()-2, col.max() + 2, 10000)
  density = gaussian_kde(col)
  density.covariance_factor = lambda : bandwith
  density._compute_covariance()
  y_data = density(xs)
  y_data *= col_count.max() / y_data.max() # Find a good scaling point
  ax.plot(xs, y_data, color=color, label=label)

def plotHistQuantile(*, ax, col, quantiles, color, bins_per_unit):
  for quantile in quantiles:
    quantile_val = col.quantile(quantile)
    x = np.around(quantile_val*bins_per_unit)/bins_per_unit
    # print(f"quantile {quantile} = {quantile_val} - X: {x}")
    ax.axvline(x, linestyle='dashed', label=f'{quantile} Quantile', color=color)

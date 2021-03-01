from enum import IntFlag, auto
import pandas as pd
import matplotlib.pyplot as plt
from report import analysis
from report.utils import grpBySess
from report.clr import Difficulty as DifficultyClr
from .evdutils import fltrSsns, GroupBy, rngByPerf, rngByQuantile

class Plots(IntFlag):
  Chronometry = auto()
  ChronoPsych = auto()

AllPlots = sum([plot for plot in Plots])
NoPlots = 0


def chronometry(df, **kargs):
  for animal_name, animal_df in df.groupby(df.Name):
    _processAnimal(animal_name, animal_df, **kargs)

def _processAnimal(animal_name, animal_df, *, plots, min_easiest_perf, exp_type,
                   fitkargs, grpby, save_figs, save_prefix):
  animal_df = grpBySess(animal_df).filter(
                                  lambda ssn:(ssn.GUI_MinSampleType == 4).any())
  animal_df = grpBySess(animal_df).filter(fltrSsns,
                                          min_easiest_perf=min_easiest_perf,
                                          exp_type=exp_type)
  animal_df = animal_df[animal_df.Difficulty3.notnull()]
  if len(animal_df) < 200:
    if len(animal_df) > 10:
      print(f"Skipping {animal_name} with just {len(animal_df)} trials")
    return
  # print(animal_df.GUI_MinSampleType.unique())
  # chron_df = grpBySess(chron_df).filter(
  #   lambda sess:sess.MinSample.min() == 0.3 and  sess.MinSample.max() == 1.2)
  print(f"Subjext: {animal_name} - Chrone data max trial: "
        f"{animal_df.MaxTrial.unique()}")
  if plots & Plots.Chronometry:
    chron_df = animal_df.groupby(animal_df.MinSample).filter(
                                                       lambda grp:len(grp) > 30)
    min_sampling_pts = sorted(chron_df.MinSample.unique())
    fig, axes = plt.subplots(1,1)
    fig.set_size_inches(analysis.SAVE_FIG_SIZE[0], analysis.SAVE_FIG_SIZE[1])
    print("Min sampling points:", min_sampling_pts)
    _chronPlot(chron_df, axes, min_sampling_pts=min_sampling_pts, grpby=grpby)
    if save_figs:
      analysis.savePlot(f"{save_prefix}{animal_name}_chrono")
    plt.show()

  if plots & Plots.ChronoPsych:
    PsycStim_axes = analysis.psychAxes(animal_name)
    analysis.psychAnimalSessions(animal_df, animal_name, PsycStim_axes,
                                 analysis.METHOD, fitkargs=fitkargs)
    if save_figs:
      analysis.savePlot(f"{save_prefix}{animal_name}_psych_chrono")
    plt.show()


def _chronPlot(df, axes, min_sampling_pts, grpby):
  # min_sampling_pts = [0.3, 0.6, 0.9, 1.2, 1.5]
  #df = df[(df.MinSample <= 1.2) | (df.MinSample == 1.5)]
  df = df[df.ChoiceCorrect.notnull()]

  df['DVabs'] = df.DV.abs()
  colors = [DifficultyClr.Hard, DifficultyClr.Med, DifficultyClr.Easy]

  all_x_points = set()
  if not len(df.DVabs.unique()):
    return

  if grpby == GroupBy.Difficulty:
    bins = 3
  elif grpby == GroupBy.Performance:
    bins = rngByPerf(df, periods=3, separate_zero=False,  combine_sides=True,
                      fit_fn_periods=10)
  else:
    assert grpby == GroupBy.EqualSize
    bins = rngByQuantile(df, periods=3, separate_zero=False, combine_sides=True)

  for idx, (rng, DV_data) in reversed(list(enumerate(
                                           df.groupby(pd.cut(df.DVabs,bins))))):
    x_data = []
    y_data = []
    y_data_sem = []
    num_points = 0
    #for min_sampling, ms_data in DV_data.groupby(DV_data.MinSample):
    for min_sampling in min_sampling_pts:
      ms_data = DV_data[DV_data.MinSample.between(min_sampling - 0.001,
                                                  min_sampling + 0.001)]
      if not len(ms_data):
        continue
      x_data.append(min_sampling)
      num_points += len(ms_data.ChoiceCorrect)
      y_data.append(ms_data.ChoiceCorrect.mean()*100)
      y_data_sem.append(ms_data.ChoiceCorrect.sem()*100)
    all_x_points.update(x_data)
    color=colors[idx]
    # First DV is 1.01, which would give 101% cohr.
    left,right = int(rng.left*100), 100 if rng.right > 1 else int(rng.right*100)
    axes.errorbar(x_data, y_data, yerr=y_data_sem, color=color,
                  label=f"{left}%-{right}% Coherence ({num_points:,} trials)")
  axes.set_title("Chronometry - {}".format(" ".join(df.Name.unique())))
  axes.set_xlabel("Sampling Duration (s)")
  axes.set_ylabel("Performance %")
  axes.set_xticks(sorted(list(all_x_points)))
  axes.legend(loc="upper left", prop={'size': 'x-small'})

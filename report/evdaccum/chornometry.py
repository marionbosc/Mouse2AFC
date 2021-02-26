from enum import IntFlag, auto
import matplotlib.pyplot as plt
from report import analysis
from report.utils import grpBySess
from .evdutils import fltrSsns

class Plots(IntFlag):
  Chronometry = auto()
  ChronoPsych = auto()

AllPlots = sum([plot for plot in Plots])
NoPlots = 0

def chronometry(df, **kargs):
  for animal_name, animal_df in df.groupby(df.Name):
    _processAnimal(animal_name, animal_df, **kargs)

def _processAnimal(animal_name, animal_df, *, plots, min_easiest_perf, exp_type,
                   save_figs, save_prefix):
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
  print(animal_df.GUI_MinSampleType.unique())
  # chron_df = grpBySess(chron_df).filter(
  #   lambda sess:sess.MinSample.min() == 0.3 and  sess.MinSample.max() == 1.2)
  print(f"Animal: {animal_name} - Chrone data max trial: "
        f"{animal_df.MaxTrial.unique()}")
  if plots & Plots.Chronometry:
    axes = plt.axes() # TODO: Set fig size
    analysis.chronometry(animal_df, axes)
    if save_figs:
      analysis.savePlot(f"{save_prefix}{animal_name}_chrono")
    plt.show()

  if plots & Plots.ChronoPsych:
    PsycStim_axes = analysis.psychAxes(animal_name)
    analysis.psychAnimalSessions(animal_df, animal_name, PsycStim_axes,
                                 analysis.METHOD)
    if save_figs:
      analysis.savePlot(f"{save_prefix}{animal_name}_psych_chrono")
    plt.show()

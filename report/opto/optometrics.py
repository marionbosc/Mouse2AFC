import numpy as np
import matplotlib.pyplot as plt
import analysis
from clr import BrainRegion as BRC, adjustColorLightness
from .optoutil import ChainedGrpBy

_SECOND, _PERCENT = "Seconds", "%"

def processAnimalMetric(animal_name, df_col_name, display_name, unit,
                        opto_chain, *, save_figs, save_prefix):
  STEP=1
  BAR_WIDTH=0.5
  ax = plt.axes()
  Xs = []
  Ys = []
  Yerr = []
  colors = []
  x_ticks_labels = []
  x_ticks_pos = []
  cur_x_pos = 0

  for brain_region, df in opto_chain.byBrainRegion():
    cur_x_pos += STEP
    color = BRC[brain_region]
    color_by_type = {"Opto": adjustColorLightness(color, 1.4),
                     "Control": adjustColorLightness(color, 0.6)}

    for start_state, br_df in ChainedGrpBy(df).byState():
      len_control, len_opto = 0, 0
      for trial_type, trials_df in ChainedGrpBy(br_df).byOptoTrials():
        Xs +=   [cur_x_pos]
        Ys +=   [trials_df[df_col_name].mean()]
        Yerr += [trials_df[df_col_name].sem()]
        colors += [color_by_type[trial_type]]
        # if unit == percent:
        #   grps_control_mean = grpBySess(control_trials)[df_col_name].mean()
        #   grps_opto_mean = grpBySess(control_trials)[df_col_name].mean()
        #   Ys_means_mean += [grps_control_mean.mean(), grps_opto_mean.mean()]
        #   Yerr += [grps_control_mean.sem(), grps_opto_mean.sem()]
        cur_x_pos += BAR_WIDTH
        if trial_type == "Opto":
          len_control = len(trials_df)
        else:
          len_opto = len(trials_df)
      # Should write, e.g: V1Bi - Stimulus_deliver (305 C/135 Opto trials)
      tick_label = (f"{brain_region}"
                    f" - {start_state}" if start_state else "")
      x_ticks_labels.append(r"%s (%d $\bf{C}$/%d $\bf{Opto}$ trials)" % (
                            tick_label, len_control, len_opto))
      x_ticks_pos.append(cur_x_pos-BAR_WIDTH)
      #print(f"expr_id: {expr_id} - Xs: {Xs[-2:]} - Ys: {Ys[-2:]} - Color: {colors[-2:]}")

  if unit == _PERCENT:
    Ys = np.array(Ys) * 100

  ax.bar(Xs, Ys, width=BAR_WIDTH, yerr=Yerr, color=colors)
  ax.set_xticks(x_ticks_pos)
  ax.set_xticklabels(x_ticks_labels, ha='right', rotation=25)
  ax.tick_params(axis='x', which='major', labelsize=10)
  ax.set_title(f"{animal_name} - {display_name} Optogentics Trials")
  ax.set_ylabel(f"Mean {display_name} ({unit})")
  from matplotlib.lines import Line2D
  custom_lines = [
        Line2D([0],[0], color=adjustColorLightness("gray", amount=0.6), lw=4),
        Line2D([0],[0], color=adjustColorLightness("gray", amount=1.4), lw=4)]
  ax.legend(custom_lines,
            ['Control Trials (dark shade)', 'Opto Trials (light shade)'],
            loc='lower right')
  if save_figs:
    analysis.savePlot(save_prefix + f"{animal_name}_{display_name}")
  plt.show()

def animalOptoMetrics(animal_name, opto_chain, *, save_figs, save_prefix):
  for _df_col_name, _display_name, _unit in [
                        ("calcReactionTime","Reaction Time", _SECOND),
                        ("calcMovementTime", "Movement Time", _SECOND),
                        ("EarlyWithdrawal", "Early-Withdrawal", _PERCENT),
                        ("ChoiceCorrect", "Overall Performance", _PERCENT)]:
    processAnimalMetric(animal_name, _df_col_name, _display_name, _unit,
                        opto_chain, save_figs=save_figs, save_prefix=save_prefix)

def optoMetrics(opto_chain, *, save_figs, save_prefix):
  animalOptoMetrics("All animals", opto_chain,
                    save_figs=save_figs, save_prefix=save_prefix)
  for animal_name, animal_opto_chain in opto_chain.byAnimal():
    animalOptoMetrics(animal_name, opto_chain, save_figs=save_figs,
                      save_prefix=save_prefix)



import os
import time
from tempfile import gettempdir
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from common.attrdict import AttrDict
from common.createMMFile import createMMFile
from common.loadSerializedData import loadSerializedData
from .mainplot2 import mainplot2

def main():
  tmp_fp = os.path.join(gettempdir(), 'mmap_matlab_plot.dat')
  file_size = 40*1024*1024; # 40 MB mem-mapped file
  print("Full path:", tmp_fp)
  m = createMMFile(tmp_fp, file_size)
  last_iTrial = -1
  initialized_before = False
  mpl.rcParams['toolbar'] = 'None'
  keep_running = True
  fig = None
  def figCloseEvent(evt):
    nonlocal keep_running
    keep_running = False
    plt.close()

  while keep_running:
    iTrial = np.frombuffer(m[:4], dtype=np.uint32)[0]
    if iTrial == last_iTrial:
      plt.pause(.1)
    else:
      if last_iTrial + 1 != iTrial:
        print("Last iTrial:",last_iTrial, "doesn't precede current iTrial:",
              iTrial)
      else:
        print("Processing iTrial: ", iTrial)
      deserialize_start = time.time()
      next_data_start, DataCustom = loadSerializedData(m, 4)
      next_data_start, TaskParametersGUI = loadSerializedData(m, next_data_start)
      next_data_start, TrialStartTimestamp = loadSerializedData(m, next_data_start)
      deserialize_dur = time.time() - deserialize_start
      print("Took {:.2}s to deserialize string".format(deserialize_dur))

      if iTrial == 0 or not initialized_before: # % First run
        # TODO: See if you need to disable the graphs again
        fig, GUIHandles = initializeFigures(fig)
        fig.canvas.mpl_connect('close_event', figCloseEvent)
        GUIHandles.OutcomePlot = mainplot2(GUIHandles.OutcomePlot,
                                           'init', DataCustom,
                                           TaskParametersGUI,
                                           TrialStartTimestamp)
        initialized_before = True
        # if not initialized_before and iTrial != 0, then the loop will
        # repeat again now and will go to the else part
      if iTrial > 0:
        GUIHandles.OutcomePlot = mainplot2(GUIHandles.OutcomePlot,'update',
                                           DataCustom,
                                           TaskParametersGUI,
                                           TrialStartTimestamp,iTrial)

      last_iTrial = iTrial



def initializeFigures(old_fig):
  if old_fig:
    old_fig.clear()
    fig = old_fig
    print("Calling clear")
  else:
    fig = plt.figure(figsize=(14,6), num='Outcome plot',
                     constrained_layout=False)
  gs = fig.add_gridspec(2, 6)
  HandleOutcome =      fig.add_subplot(gs[1, :])
  HandlePsycStim =     fig.add_subplot(gs[0, 0], visible=False)
  HandleVevaiometric = fig.add_subplot(gs[0, 1], visible=False)
  HandleTrialRate =    fig.add_subplot(gs[0, 2], visible=False)
  HandleFix =          fig.add_subplot(gs[0, 3], visible=False)
  HandleST =           fig.add_subplot(gs[0, 4], visible=False)
  HandleFeedback =     fig.add_subplot(gs[0, 5], visible=False)
  GUIHandles = AttrDict(OutcomePlot=AttrDict(HandleOutcome=HandleOutcome,
    HandlePsycStim=HandlePsycStim, HandleTrialRate=HandleTrialRate,
    HandleFix=HandleFix, HandleST=HandleST, HandleFeedback=HandleFeedback,
    HandleVevaiometric=HandleVevaiometric))
  fig.tight_layout(pad=4)
  plt.show(block=False)
  if "Qt" in plt.get_backend() and "Agg" in plt.get_backend():
    win = fig.canvas.window()
    win.setFixedSize(win.size())
  return fig, GUIHandles

if __name__ == "__main__":
    main()
from enum import Enum, auto
import numpy as np

class Ports(Enum):
  Left = auto()
  Center = auto()
  Right = auto()

class PortAction(Enum):
  In = "In"
  Out = "Out"

def _getTrialsPorts(trials_settings, is_new_format):
  if not is_new_format:
    trials_settings = [setting.GUI for setting in trials_settings]
  if hasattr(trials_settings[0], "Ports_LMRAir"):
    trials_ports = [setting.Ports_LMRAir//10 for setting in trials_settings]
  else:
    trials_ports = [setting.Ports_LMRAudLRAir//1000
                    for setting in trials_settings]
  trials_ports = [tuple([(ports//div)%10 for div in (100, 10, 1)])
                                         for ports in trials_ports]
  return trials_ports

def _extractTrialsPortsEvents(raw_events_li, trials_settings, is_new_format):
  trials_ports = _getTrialsPorts(trials_settings, is_new_format)

  def getTrialsEvents(raw_events_li_):
    # Sometimes trial 0 has no events, I don't know why
    if not hasattr(raw_events_li_[0], "Events"):
      raw_events_li_[0].Events = {}
    trials_events_ = [trial.Events for trial in raw_events_li_]
    return trials_events_
  trials_events = getTrialsEvents(raw_events_li)

  def makePortsListOfDicts(num_trials):
    SingleTrialPorts = dict([((port, action), []) for port in Ports
                                                  for action in PortAction])
    trials_ports_events_ = [SingleTrialPorts.copy() for i in range(num_trials)]
    return trials_ports_events_
  NUM_TRIALS = len(raw_events_li)
  trials_ports_events = makePortsListOfDicts(NUM_TRIALS)

  nan_array = np.array([np.nan])
  def processTrial(trial_events, trial_ports, dst_trial_dict):
    l_port, c_port, r_port = trial_ports
    for (mapped, real) in [(Ports.Left, l_port),
                           (Ports.Center, c_port),
                           (Ports.Right, r_port)]:
      for action in PortAction:
        dst_trial_dict[(mapped, action)] = \
                    getattr(this_trial_events, f"Port{real}{action}", nan_array)

  for this_trial_events, this_trials_ports_events, this_trial_ports in \
                          zip(trials_events, trials_ports_events, trials_ports):
    processTrial(this_trial_events, this_trial_ports, this_trials_ports_events)

  return trials_ports_events

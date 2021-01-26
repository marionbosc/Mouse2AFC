# A modified version from the code found in:
# http://www.mbfys.ru.nl/~robvdw/DGCN22/PRACTICUM_2011/LABS_2011/ALTERNATIVE_LABS/Lesson_2.html#18
import sys
import time
import numpy as np
from psychopy import prefs
prefs.general['winType'] = "glfw"
from psychopy import visual
from psychopy import monitors
from common.definitions import DrawStimType
from common.loadSerializedData import loadSerializedData
from . import drawdots, gabor
from .checkclose import checkClose

def availableScreensIds():
  from pyglet.canvas import get_display
  screens = get_display().get_screens()
  print("Found screens:", screens)
  return np.arange(len(screens)) + 1


def createWindow(screen_id):
  #cur_win_ptr, cur_win_rect = PsychImaging('OpenWindow', cur_screen_id,
  #    BLACK_COLOR, cur_win_rect, 32, 2, [], [],  kPsychNeed32BPCFloat)
  win = visual.Window(screen=screen_id, wintype="glfw", fullscr=True,
                      bpc=32, depthBits=32, waitBlanking=True,
                      color='black', allowGUI=False,
                      # We will do it later more extensively
                      checkTiming=False)
                      # Should we add also stencil bits = 32?
  # win.mouseVisible = False
  return win

def mousePos(pos=None):
  # This only works on windows
  import win32api
  if pos:
    try:
      win32api.SetCursorPos(pos)
    except:
      pass
  else:
    pos = win32api.GetCursorPos()
  # print("Pos:", pos)
  return pos

def setup():
  import sys
  if len(sys.argv) == 1:
    # Set the screen number to the external secondary monitor if there is one
    # connected
    screens_ids = [max(availableScreensIds())]
  else:
    screens_ids = [int(screen_id) for screen_id in sys.argv[1:]]
  screens_ids = np.array(screens_ids)

  from common.createMMFile import createMMFile
  FILE_SIZE = 512*1024 # 512 kb mem-mapped file
  mm_file = createMMFile(r"c:\Bpoduser\mmap_matlab_randomdot.dat", FILE_SIZE)

  wins_ptrs = []
  fill_rects = []
  photo_diode_boxes = []
  # Open the screens
  print("Screens ids:", screens_ids)
  for cur_screen_id in screens_ids:
    print("Opening screen:", cur_screen_id)
    cur_win_ptr = createWindow(cur_screen_id)
    # Disable alpha blending just in case it was still enabled by a previous
    # run that crashed. # Can this happen?
    cur_win_ptr.blendMode = "avg"
    wins_ptrs.append(cur_win_ptr)
  wins_ptrs = np.array(wins_ptrs)

  monitors_names = monitors.getAllMonitors()
  # Assume it's the only one setup
  cur_monitor = monitors.Monitor(monitors_names[0])
  # Query maximum useable priority_level on this system:
  #priority_level = MaxPriority(cur_screen_id)
  return mm_file, wins_ptrs, cur_monitor

def main():
  cur_mouse_pos = mousePos()
  mm_file, wins_ptrs, monitor = setup()
  mousePos(cur_mouse_pos)

  PHOTO_DIODE_POS_NORM = (0.925, 0.925)
  PHOTO_DIODE_SIZE_NORM = (0.3, 0.15)
  # For verbosity, the same windows rect is valid for all screens as all
  # the screens should have the same resolution
  win_size = np.array((wins_ptrs[0].viewport[2] - wins_ptrs[0].viewport[0],
                       wins_ptrs[0].viewport[3] - wins_ptrs[0].viewport[1]))
  # For the next parts, we assume that all the screens has the same dimension,
  # so just use wins_ptrs[0] as it should hold the sane parameters for all the
  # windows.
  for i in range(1, 6):
    print(f"Measuring screen frame rate at {i}ms std. threshold")
    frame_rate = wins_ptrs[0].getActualFrameRate(nMaxFrames=200, threshold=i,
                                                 nWarmUpFrames=30)
    if frame_rate is not None:
      break
    else:
      print(f"Failed to get good measurements at {i}ms std.")
  else:
    print("Failed to get measure frame rate. Using monitor referesh rate value")
    frame_rate = 1/wins_ptrs[0].monitorFramePeriod
  print("Using frame rate:", frame_rate)

  draw_dots = drawdots.DrawDots(wins_ptrs, win_size, PHOTO_DIODE_SIZE_NORM,
                                PHOTO_DIODE_POS_NORM, frame_rate, monitor)
  gabor_stim = gabor.Gabor(wins_ptrs, win_size, PHOTO_DIODE_SIZE_NORM,
                           PHOTO_DIODE_POS_NORM, frame_rate, monitor)
  # Commands
  # 0 = Stop running
  # 1 = Load new stim info
  # 2 = Start running or keep running
  cur_cmd = 0
  while True:
    while cur_cmd == 0:
      time.sleep(0.01) # Sleep until the next command
      checkClose(wins_ptrs)
      cur_cmd = np.frombuffer(mm_file[:4], dtype=np.uint32)[0]
    # Load the the drawing parameters
    _, drawParams = loadSerializedData(mm_file, 4)
    if drawParams.stimType == DrawStimType.RDK:
      cur_cmd, draw_params = draw_dots.loop(cur_cmd, mm_file)
    elif drawParams.stimType == DrawStimType.StaticGratings or \
         drawParams.stimType == DrawStimType.DriftingGratings:
      cur_cmd, draw_params = gabor_stim.loop(cur_cmd, mm_file)
    else:
      print("Unknown command:", drawParams.stimType)
      continue

if __name__ == "__main__":
  main()

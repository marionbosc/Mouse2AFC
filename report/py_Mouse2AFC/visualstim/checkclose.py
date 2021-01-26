import sys
import glfw

def checkClose(wins_ptrs):
  glfw.poll_events()
  for cur_win_ptr in wins_ptrs:
    if glfw.window_should_close(cur_win_ptr.winHandle):
      print("User asked to quit")
      sys.exit(0)

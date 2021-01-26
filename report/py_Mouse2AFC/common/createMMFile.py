import mmap
import os

def createMMFile(fpath, fsize):
  '''Opens or creates a memory mapped file fpath with size of fsize. '''
  # Create the communications file if it is not already there.
  craete_buf = not os.path.exists(fpath)
  f = open(fpath, "r+b")
  if craete_buf:
    f.write([0]*fsize).flush()
    f.seek(0)
  # memory-map the file, size 0 means whole file
  m = mmap.mmap(f.fileno(), 0)
  return m

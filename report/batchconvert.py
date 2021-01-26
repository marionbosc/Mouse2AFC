import click
import copy
import glob
import subprocess
import os
import sys
import time
import pandas as pd

DEFAULT_DIR=r"C:\BpodUser\Data"

def spawnProcess(session_data_dir, only, exclude):
  animal_name, protocol_name = session_data_dir.split(os.path.sep)[-3:-1]
  if "dummy" in animal_name.lower():
    return None
  if protocol_name != "Mouse2AFC":
    return None
  mat_files = os.path.join(session_data_dir, "*.mat")
  files = glob.glob(mat_files)
  sub_files = files
  if only:
    sub_files = list(filter(lambda f: any([word in f for word in only]),
                            sub_files))
  if exclude:
    sub_files = list(filter(lambda f: not all([word in f for word in exclude]),
                            exclude))
  print("Animal name:", animal_name, "- Match:", mat_files)
  append_df_arg = []
  for fp in glob.glob(f"{animal_name}*.dump"):
    append_df_arg = ["--apend-df", fp]
    break
  few_trials_file = f"few_trials/{animal_name}.txt"
  if ps.path.exists(few_trials_file):
    few_trials_load_arg = ["--few-trials-load", few_trials_file]
  else:
    few_trials_load_arg = []
  p = subprocess.Popen(args=["python", "mat_reader.py", "-o", animal_name,
                       "-i", mat_files, "--few-trials-save", few_trials_file] +\
                       few_trials_load_arg + append_df_arg,
                       shell=False)
  return p

def concatDfs():
  from mat_reader import reduceTypes, MIN_DF_COLS_DROP
  all_df = []
  for file_path in os.listdir():
    if os.path.isfile(file_path) and file_path.endswith(".dump"):
      print("Loading", file_path, "dataframe")
      all_df.append(pd.read_pickle(file_path))
  # Suppress concat() warning and disable sort, we will sort later
  all_df = pd.concat(all_df, ignore_index=True, sort=False)
  print("Reassigning dataframe types to reduce memory usage...")
  all_df = reduceTypes(all_df, debug=True)
  print("Extra filtering resulting df...")
  cols_to_keep = list(filter(lambda col:col not in MIN_DF_COLS_DROP,
                             all_df.columns))
  dropped_cols = set(all_df.columns) - set(cols_to_keep)
  print("Dropping", dropped_cols, "columns. Remaining cols:", len(cols_to_keep))
  all_df = all_df[cols_to_keep]
  output_path="all_animals.pkl"
  print("all_df.info:")
  all_df.info()
  all_df.sort_values(["Name","Date","SessionNum","TrialNumber"], inplace=True)
  all_df.reset_index(drop=True)
  print("Saving to a single dataframe:", output_path)
  all_df.to_pickle(output_path)



def batchConvert(dir_path, only, exclude, is_root=True):
  sub_processes = []
  for entry in os.listdir(dir_path):
    entry = os.fsdecode(entry)
    entry = os.path.join(dir_path, entry)
    if any([word in entry for word in exclude]):
      continue
    #print("Entry:", entry)
    if os.path.isdir(entry):
      if entry.endswith("Session Data"):
        #print("Handling dir:", entry)
        p = spawnProcess(entry, only, exclude)
        if p is not None: sub_processes.append(p)
      else:
        sub_sub_processes = batchConvert(entry, only, exclude, is_root=False)
        sub_processes += sub_sub_processes
  if not is_root:
    return sub_processes
  else:
    assert is_root == True
    while len(sub_processes):
      for p in copy.copy(sub_processes):
        if p.poll() is not None: sub_processes.remove(p)
      print("{} processes remaining...".format(len(sub_processes)))
      time.sleep(1)
    concatDfs()

@click.command()
@click.option('--dir', '-d', type=click.Path(exists=True), default=DEFAULT_DIR,
              help="The directory containing the sessions files")
@click.option('--only', '-i', multiple=True,
              help="If specified, then only paths contains that string will be",
                   "included")
@click.option('--exclude', '-x', multiple=True,
              help="Paths containing such string(s) will be excluded")
def main(dir, only, exclude):
  #concatDfs()
  if only is None: only = []
  if exclude is None: exclude = []
  batchConvert(dir, only, exclude)

if __name__ == "__main__":
  main()
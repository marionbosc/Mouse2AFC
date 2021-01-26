
def createClass(key_, struct, *, tabs):
  #print("Val:", struct)
  from scipy.io.matlab.mio5_params import mat_struct
  from scipy.io.matlab.mio5_params import MatlabFunction
  if isinstance(struct, mat_struct):
    output = "{}class {}:\n".format(" "*tabs, key_)
    wrote_nothing = True
    for key in dir(struct):#._fieldnames:
      if key.startswith("__") or key == "_fieldnames":
        continue
      val = getattr(struct, key)
      output += createClass(key, val, tabs = tabs + 2)
      wrote_nothing = False
    if wrote_nothing:
      output += "{}pass\n".format(" "*(tabs+2))
    output += '\n'
  else:
    output = ""
    import numpy as np
    if isinstance(struct, str):
      str_struct = f"'{struct}'"
    elif isinstance(struct, (int, float)):
      str_struct = str(struct)
      if str_struct == 'nan':
        str_struct = 'np.nan'
    elif isinstance(struct, MatlabFunction):
      str_struct = 'None'
    elif isinstance(struct, np.ndarray):
      arr_str = np.array2string(struct, separator=', ', max_line_width=150)
      #print("Struct:", struct)
      #arr_str = 'np.array(['
      #for elm in struct:
      #  res = createClass('', elm, tabs=tabs+2)
      #  arr_str += res + ','
      #arr_str += '])'
      #str_struct = arr_str
      str_struct = f"np.array({arr_str})"
    else:
      print("Unhandled type:", key_, type(struct))
      str_struct = str(struct)
    output += "{}{} = {}\n".format(" "*tabs, key_, str_struct)
    #print("Type:", key_, type(struct))
  return output

def main(filepath, output_fp):
  from scipy.io import loadmat
  mat_obj = loadmat(filepath, struct_as_record=False, squeeze_me=True)
  out = "import numpy as np\n"
  for key, val in mat_obj.items():
    if isinstance(key, str) and key.startswith("__"):
      continue
    out += createClass(str(key), val, tabs=0)
  print(out, end='')
  with open(output_fp, 'w') as f:
    f.write(out)

if __name__ == "__main__":
  import sys
  main(sys.argv[1], sys.argv[2])
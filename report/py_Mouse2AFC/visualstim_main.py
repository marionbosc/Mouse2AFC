import sys
import encodings
print("Running with sys.argv:", sys.argv )
print("Running with sys.path:", sys.path )
try:
  from visualstim.visualstim import main
except Exception as e:
  print("Didn't manage to import main due to:", str(e))
print("Imported main")

if __name__ == "__main__":
  print("Calling main now")
  main()
  print("Finished run")
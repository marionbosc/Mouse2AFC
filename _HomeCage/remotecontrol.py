import socket
from Tk_gui import _Status
from pick import pick

def main():
  options = list(_Status)
  options += ["_get_status"]
  option, index = pick(options, "Choose a status to set:")#, indicator='*',)
  print("Options:", option)
  #s = socket.socket()
  #s.connect(('127.0.0.1', 50001))


if __name__ == "__main__":
    main()

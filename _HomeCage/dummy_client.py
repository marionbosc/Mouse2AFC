import socket
import time

# Connect to Matlab server
s = socket.socket()
s.connect(('127.0.0.1', 30000))

# As a mock example, keep sending
while True:
  s.send('DummySubject 0.2\n'.encode())
  s.settimeout(1)
  count = 0
  while count < 2:
    try:
      msg = s.recv(32000).decode()
      if msg == "pulsecheck":
        print("Received pulse-check message")
        continue
      else:
        print('message no. {}: {}'.format(count+1, msg))
    except Exception:
      continue
    else:
      count += 1

  print("Making a new request in 10 seconds")
  print("")
  time.sleep(10)

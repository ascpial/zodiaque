-- A simple program that show everything that is happening on channel 300.

local modem = peripheral.wrap('top')
modem.open(300)

while 1 do
  _, _, _, _, message, _ = os.pullEvent('modem_message')
  print(message)
end

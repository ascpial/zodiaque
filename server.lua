-- A demo server which listens for connections, displays them, and respond with pong if the message
-- was ping else bad request.
-- Run generateKeys before trying this out.

local utils = require("zodiaque.utils")
local api = require("zodiaque.api")

utils.initRandom()

local sk = fs.open("secure/server.sk", 'r').readAll()
if sk == nil then
  print("Did you ran generateKeys?")
  os.exit(300)
end
local server = api.Api:new(300, 'top', sk)

--- @param peer PeerStorage
--- @param content string
local function handler(peer, content)
  print(content)
  if content == "ping" then
    peer:send("pong")
  else
    peer:send("bad request")
  end
end

server:serve(handler)

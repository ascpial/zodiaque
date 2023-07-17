local utils = require("utils")
local storage = require("storage")
local network = require("network")

utils.initRandom()

local modem = peripheral.wrap("top")

if modem == nil then
  print("cépété")
  os.exit(1)
end

modem.open(300)

local sk = fs.open("secure/server.sk", 'r').readAll()
local pk = fs.open("secure/server.pk", 'r').readAll()

if sk == nil or pk == nil then
  print("Did you ran generateKeys?")
  os.exit(300)
end

local peers = storage.Peers:new(pk, sk)

--- Use this to listen to requests of other peers and initiate connection.
--- Encrypted requests will be forwarded to the specified function.
--- Use as a coroutine.
--- @param channel number The channel to listen
--- @param modem table The modem used to transmit information
--- @param peers Peers The peers object used for authentication
--- @param requests function The function to call when encrypted requests are catch
--- @param[opt=false] allowHandshake boolean Whether to initiate handshake requested by other peers (default to false)
local function serve(channel, modem, peers, requests, allowHandshake)
  allowHandshake = allowHandshake or false
  modem.open(channel)
  local requestChannel, message
  while 1 do
    _, _, requestChannel, _, message, _ = os.pullEvent("modem_message")
    print(message)
    if requestChannel == channel then
      local success, request = pcall(utils.unserialize, message)
      if success and request["to"] == peers.pk and network.verify(request) then
        if request["type"] ~= "s.message" then
          print("ok")
          local response = peers:update(request, allowHandshake)
          if response ~= nil then
            modem.transmit(channel, channel, utils.serialize(response))
          end
        else
          local peer = peers:getPeer(request['from'])
          if peer ~= nil then
            local valid, content = peer:decrypt(request)
            if valid then
              requests(peer, content)
            end
          end
        end
      end
    end
  end
end

local function request(peer, content)
  print(content)
end

serve(
  300,
  modem,
  peers,
  request
)


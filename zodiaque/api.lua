local utils = require("zodiaque.utils")
local network = require("zodiaque.network")
local storage = require("zodiaque.storage")
local ed = require("ccryptolib.ed25519")

--- Forward a message to the queue
--- @param peer PeerStorage
--- @param content string
local function forwardEvent(peer, content)
  os.queueEvent("s.message", peer.pk, content)
end

--- Wait for a peer to be ready
--- @param peer PeerStorage
local function waitForReady(peer)
  if peer.ready == false then
    local pk
    repeat
      _, pk = os.pullEvent("s.peer_ready")
    until pk == peer.pk
  else
    return
  end
end

--- Wait for a message from the peer and return the message
--- @param peer PeerStorage
--- @return string
local function waitForMessage(peer)
  local pk, content
  repeat
    _, pk, content = os.pullEvent("s.message")
  until pk == peer.pk
  return content
end

--- Class used to manage in a cleaner way modems, peers and server
--- @class Api
--- @field allowHandshake boolean Wether to accept incoming handshake requests or not, defaults to false
--- @field sk string The local 32-byte secrete key of the local peer
--- @field pk string The local 32-byte public key of the local peer derived from the secrete key
--- @field channel number The channel to listen for communications
--- @field modem Modem The modem used to communicate
--- @field peers Peers Stores the other peers
--- @field running boolean Wether we are watching for new events or not
local Api = {}

--- Create a new API object
--- @param channel number The channel to listen for communications
--- @param side string The modem to use
--- @param sk string The local 32-byte secrete key of the local peer (public key is generated from it)
--- @param allowHandshake? boolean Wether to accept incoming handshake requests or not, defaults to false
--- @return Api
function Api:new(channel, side, sk, allowHandshake)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.sk = sk
  o.pk = ed.publicKey(o.sk)
  o.channel = channel
  o.allowHandshake = allowHandshake or false
  o.running = false

  local modem = peripheral.wrap(side)
  if modem == nil then
    error(string.format("The modem {} could not be found", side))
  end
  o.modem = modem

  o.peers = storage.Peers:new(o.pk, o.sk)

  o.modem.open(channel)

  return o
end

--- Send a request using the already open modem
--- @param request table The request to send
function Api:sendRequest(request)
  self.modem.transmit(self.channel, self.channel, utils.serialize(request))
end

--- Return a peer object and connect the peer if needed
--- @param pk string The 32-byte public key of the remote peer
function Api:getPeer(pk)
  local storagePeer = self.peers:getPeer(pk)
  if storagePeer == nil then
    return self:connect(pk)
  else
    storagePeer.api = self
    return storagePeer
  end
end

--- Send a handshake request to the specified peer and returns the peer
--- @param pk string The 32-byte public key of the remote peer
--- @return PeerStorage peer The remote peer object
function Api:connect(pk)
  self:sendRequest(self.peers:askHandshake(pk))
  return self:getPeer(pk)
end

--- Run a function in parallel of the server, usefull to listen to request while displaying things
--- on screen or managing logic
--- @param parallelFunc function The function to start in parallel of the server, Should yield often
function Api:run(parallelFunc)
  parallel.waitForAny(function () self:serve(forwardEvent) end, parallelFunc)
end

--- Launch the server and sends message to the specified function
--- @param handler function The function called with the peer and the message
function Api:serve(handler)
  self.running = true
  while self.running do
    local _, _, requestChannel, _, message, _ = os.pullEvent("modem_message")
    if requestChannel == self.channel then
      local success, request = pcall(utils.unserialize, message)
      if success and request["to"] == self.pk and network.verify(request) then
        if request["type"] ~= "s.message" then
          local response = self.peers:update(request, self.allowHandshake)
          if response ~= nil then
            self.modem.transmit(self.channel, self.channel, utils.serialize(response))
          end
        else
          local peer = self:getPeer(request['from'])
          if peer ~= nil then
            local valid, content = peer:decrypt(request)
            if valid then
              handler(peer, content)
            end
          end
        end
      end
    end
  end
end

return {
  waitForReady=waitForReady,
  waitForMessage=waitForMessage,
  Api=Api,
}

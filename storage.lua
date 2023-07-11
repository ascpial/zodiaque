local random = require("ccryptolib.random")
local network = require('network')
local dh = require("ccryptolib.x25519")

Peers = {}

--- Creates a new client buffer
--- @param sk string The connection secrete key
--- @param pk string The connection public key
function Peers:new(sk, pk)
  local o = {
    sk=sk,
    pk=pk,
    peers={},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- Updates a peer from a request and return the next request to send to the peer or nil.
--- Does no check the validity of the request!
--- @param r table The request sent by the peer to update
--- @param allowHandshake boolean Whether to allow handshake request or not
--- @return table response The next request to send to the other peer or nil if the connection ended
function Peers:update(r, allowHandshake)
  allowHandshake = allowHandshake or true
  local request
  if r['type'] == "s.handshake_request" and allowHandshake then
    local sender = r["from"]
    if self.peers[sender] == nil then
      local next_challenge = random.random(64)
      local dhsk = random.random(32)
      local dhpk = dh.publicKey(dhsk)
      request = network.beginHandshakeRequest(
        sender,
        self.pk,
        self.sk,
        r["next_challenge"],
        next_challenge,
        dhpk
      )
      self.peers[sender] = {
        next_challenge=next_challenge,
        dhsk=dhsk,
      }
    end
  elseif r['type'] == "s.begin_handshake" then
    local sender = r["from"]
    if self.peers[sender] ~= nil then
      local peer = self.peers[sender]
      if peer["next_challenge"] == r["challenge"] then
        local dhsk = random.random(32)
        local dhpk = dh.publicKey(dhsk)
        request = network.terminateHandshakeRequest(
          sender,
          self.pk,
          self.sk,
          r["next_challenge"],
          dhpk
        )
        peer["next_challenge"] = nil
        peer["shared_key"] = dh.exchange(dhsk, r["dh_key"])
      end
    end
  elseif r['type'] == "s.terminate_handshake" then
    local sender = r["from"]
    if self.peers[sender] ~= nil then
      local peer = self.peers[sender]
      if peer["next_challenge"] == r["challenge"] then
        peer["shared_key"] = dh.exchange(peer["dhsk"], r["dh_key"])
        peer["next_challenge"] = nil
        peer["dhsk"] = nil
      end
    end
  end
  return request
end

--- Return true if handshake has been finished with the specified peer.
--- @param pk string The publickey of the peer
--- @return boolean ready Whether the peer is ready or not
function Peers:isReady(pk)
  return self.peers[pk]["shared_key"] ~= nil
end

--- Waits until the specified peer is ready, or the timeout occured.
--- @param pk string The publickey of the peer
--- @param timeout number Time in millisecond to wait for
--- @return boolean ready true if the peer is ready, false if timeout
function Peers:waitForReady(pk, timeout)
  local start = os.epoch("utc")
  while os.epoch("utc") < start + timeout and not self:isReady(pk) do
    sleep()
  end
  return self:isReady(pk)
end

--- Creates a request to begin a handshake with an other peer.
--- Warning: does reset previous connection with the specified peer.
--- @param pk string The public key of the peer to begin a handshake with
--- @return table request The request to send to the peer
function Peers:askHandshake(pk)
  local next_challenge = random.random(64)
  local request = network.makeHandshakeRequest(
    pk,
    self.pk,
    self.sk,
    next_challenge
  )
  self.peers[pk] = {
    next_challenge=next_challenge,
  }
  return request
end


--- Update client data from a request
--- @param clients table The clients table to update
--- @param r table The request used to update the data
local function updateClients(clients, r)
  if r['type'] == "s.hanshake_request" then
    local sender = r['from']
    if clients[sender] == nil then
      clients[sender] = {
        next_challenge=r['next_challenge'],
      }
    end
  elseif r['type'] == "s.begin_handshake" then
    local sender = r['from']
    if clients[sender] ~= nil then
      clients[sender]["next_challenge"] = r["next_challenge"]
      clients[sender]["dhpk"] = r["dhpk"]
    end
  end
end

return {
  Peers=Peers,
}

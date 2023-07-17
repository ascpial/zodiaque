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
        peer['nonces'] = {}
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
        peer['nonces'] = {}
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

--- Check if a payload coming from the given peer is valid.
--- @param pk string The remote peer public key
--- @param payload table The decrypted request payload
--- @return boolean valid Wether the request is valid or not
function Peers:verifyPayload(pk, payload)
  local nonce = payload['nonce']
  local timestamp = payload['timestamp']
  local peer = self.peers[pk]
  return nonce > peer['remote_nonce'] and os.epoch() - timestamp < 1000 -- accept up to 1 second difference
end

--- Encrypts a message
--- @param to string The 32-bits public key of the other peer
--- @param content string The content to encrypt
--- @return table request The request which can be send to the other peer
function Peers:encrypt(to, content)
  return network.encrypt(
    self.pk,
    to,
    self.peers[to]['shared_key'],
    random.random(12),
    content
  )
end

function Peers:cleanNonces(sender)
  local peer = self.peers[sender]
  local now = os.epoch("utc")
  local to_remove = {}
  for old_nonce, date in pairs(peer['nonces']) do
    if date < now - 1000 then
      table.insert(to_remove, old_nonce)
    end
  end
  for _, nonce in ipairs(to_remove) do
    peer['nonces'][nonce] = nil
  end
end

--- Checks and decrypts a request.
--- When the request is decrypted, the nonce is added in the internal table,
--- so this function can only be called once with each request.
--- @param request table The request to decrypt
--- @return boolean valid Whether the request is valid or not
--- @return string ?content The content of the request or nil if invalid
function Peers:decrypt(request)
  local sender = request['from']
  local peer = self.peers[sender]
  local key = peer['shared_key']
  local nonce = request['nonce']
  if peer['nonces'][nonce] ~= nil then
    return false, nil
  end
  local valid, content = network.decrypt(key, request)
  if valid then
    peer['nonces'][nonce] = os.epoch('utc')
    self:cleanNonces(sender)
    return true, content
  else
    return false, nil
  end
end

return {
  Peers=Peers,
}

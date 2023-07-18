local random = require("ccryptolib.random")
local network = require('network')
local dh = require("ccryptolib.x25519")

--- The class used to store a single peer and process things with it.
--- @class PeerStorage
--- @field localpk string The public key of the local peer
--- @field pk string The public key of the remote peer
--- @field next_challenge? string The next challenge used for handshake
--- @field dhsk? string Your Diffie-Hellman secrete key used for key exchange
--- @field shared_key? string The shared key used for data encryption
--- @field nonces? table The already seen nonces used to prevent replay attacks
--- @field ready boolean Whether the peer is ready or not
local Peer = {}

--- Creates a new peer
--- @param pk string The public key of the peer
--- @return PeerStorage
function Peer:new(localpk, pk)
  local o = {
    localpk=localpk,
    pk=pk,
    ready=false,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

--- Returns local secrete key used for Diffie-Hellman key exchange or generate ones.
--- @return string key
function Peer:getExchangeKey()
  if self.dhsk == nil then
    self.dhsk = random.random(32)
  end
  return self.dhsk
end

--- Computes a shared key from the other peer public key
--- @param pk string The other peer public key for Diffie-Hellman exchange
function Peer:computeSharedKey(pk)
  self.shared_key = dh.exchange(self.dhsk, pk)
  self.dhsk = nil
  self.ready = true
  os.queueEvent("s.peer_ready", self.pk)
end

--- Checks wether a nonce has already be used or not
--- @param nonce string The nonce to check
--- @return boolean
function Peer:nonceUsed(nonce)
  return self.nonces[nonce] ~= nil
end

--- Remember the specified nonce used now
--- @param nonce string
function Peer:useNonce(nonce)
  self.nonces[nonce] = os.epoch('utc')
end

--- Cleans up the nonce table
function Peer:cleanNonces()
  local toRemove = {}
  local minAge = os.epoch('utc') - 1000
  for nonce, time in ipairs(self.nonces) do
    if time < minAge then
      table.insert(toRemove, nonce)
    end
  end
  for _ ,nonce in ipairs(toRemove) do
    self.nonces[nonce] = nil
  end
end

--- Encrypts a message
--- @param message string The message to send
--- @return table request The request to send
function Peer:encrypt(message)
  return network.encrypt(self.localpk, self.pk, self.shared_key, random.random(12), message)
end

--- Decrypts a message and store the nonce if applicable
--- @param request table The request to decrypt
--- @return boolean valid Wether the request is valid or not
--- @return string? content If decrypted, the content of the request
function Peer:decrypt(request)
  local nonce = request['nonce']
  if self:nonceUsed(nonce) then
    return false, nil
  else
    local valid, content = network.decrypt(self.shared_key, request)
    if valid then
      self:useNonce(nonce)
      self:cleanNonces()
      return true, content
    else
      return false, nil
    end
  end
end

--- Sends a message to the remote peer.
--- This should only be used when the peer has been setup using the API object.
--- @param message string The message to send
function Peer:send(message)
  self.api:sendRequest(self:encrypt(message))
end


--- The class used to store every peer connected to the local peer and manage transactions.
--- @class Peers
--- @field sk string The private key used by the local peer
--- @field pk string The public key used by the local peer
local Peers = {}

--- Creates a new peers object to store and manage remote peer connections
--- @param sk string The local secrete key
--- @param pk string The local public key
--- @return Peers peers
function Peers:new(pk, sk)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  o.pk = pk
  o.sk = sk
  return o
end

--- Returns the peer linked to the specified public key.
--- @param pk string The public key of the remote peer
--- @return PeerStorage? peer
function Peers:getPeer(pk)
  return self[pk]
end

--- Updates a peer from a request and return the next request to send to the peer or nil.
--- @param request table The request sent by the peer to update
--- @param allowHandshake? boolean Whether to allow handshake request or not
--- @return table response The next request to send to the other peer or nil if the connection ended
function Peers:update(request, allowHandshake)
  allowHandshake = allowHandshake or true
  local response
  if request['type'] == "s.handshake_request" and allowHandshake then
    local sender = request["from"]
    if self[sender] == nil then
      local peer = Peer:new(self.pk, sender)
      self[sender] = peer
      local dhsk = peer:getExchangeKey()
      local dhpk = dh.publicKey(dhsk)
      peer.next_challenge = random.random(64)
      response = network.beginHandshakeRequest(
        sender,
        self.pk,
        self.sk,
        request["next_challenge"],
        peer.next_challenge,
        dhpk
      )
    end
  elseif request['type'] == "s.begin_handshake" then
    local sender = request["from"]
    if self[sender] ~= nil then
      local peer = self:getPeer(sender)
      if peer ~= nil and not peer.ready and peer.next_challenge == request["challenge"] then
        local dhsk = peer:getExchangeKey()
        local dhpk = dh.publicKey(dhsk)
        response = network.terminateHandshakeRequest(
          sender,
          self.pk,
          self.sk,
          request["next_challenge"],
          dhpk
        )
        peer.next_challenge = nil
        peer:computeSharedKey(request["dh_key"])
        peer.nonces = {}
      end
    end
  elseif request['type'] == "s.terminate_handshake" then
    local sender = request["from"]
    if self[sender] ~= nil then
      local peer = self:getPeer(sender)
      if peer ~= nil and peer.next_challenge == request["challenge"] then
        peer:computeSharedKey(request["dh_key"])
        peer.next_challenge = nil
        peer.nonces = {}
      end
    end
  end
  return response
end

--- Creates a request to begin a handshake with an other peer.
--- Warning: does forget previous connection with the specified peer.
--- @param pk string The public key of the peer to begin a handshake with
--- @return table request The request to send to the peer
function Peers:askHandshake(pk)
  local next_challenge = random.random(64)
  local peer = Peer:new(self.pk, pk)
  peer.next_challenge = next_challenge
  self[pk] = peer
  local request = network.makeHandshakeRequest(
    pk,
    self.pk,
    self.sk,
    next_challenge
  )
  return request
end

return {
  Peer=Peer,
  Peers=Peers,
}

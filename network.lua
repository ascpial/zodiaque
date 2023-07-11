local utils = require("utils")
local crypto = require("crypto")
local random = require("ccryptolib.random")

--- Creates a handshake request.
--- @param to string The server 32-bits public key
--- @param pk string The local 32-bits public key
--- @param sk string The local 32-bits secrete key
--- @param next_challenge string The challenge to request to the other peer
--- @return table request The request to broadcast
local function makeHandshakeRequest(to, pk, sk, next_challenge)
  local request = {
    type="s.handshake_request",
    from=pk,
    to=to,
    next_challenge=next_challenge,
  }
  crypto.sign(sk, pk, request)
  return request
end

--- Creates a request to begin a handshake.
--- @param to string The client 32-bits public key
--- @param pk string The local 32-bits public key
--- @param sk string The local 32-bits secrete key
--- @param challenge string The previous challenge to sign
--- @param next_challenge string The next challenge to request
--- @param dhpk string The public key used for Diffie-Hellman exhange
--- @return table request The request to send to the other peer
local function beginHandshakeRequest(to, pk, sk, challenge, next_challenge, dhpk)
  local request = {
    type="s.begin_handshake",
    from=pk,
    to=to,
    challenge=challenge,
    next_challenge=next_challenge,
    dh_key=dhpk,
  }
  crypto.sign(sk, pk, request)
  return request
end

--- Creates a request to terminate a handshake.
--- @param to string The client 32-bits public key
--- @param pk string The local 32-bits public key
--- @param sk string The local 32-bits secrete key
--- @param challenge string The previous challenge to sign
--- @param dhpk string The public key used for Diffie-Hellman exhange
--- @return table request The request to send to the other peer
local function terminateHandshakeRequest(to, pk, sk, challenge, dhpk)
  local request = {
    type="s.terminate_handshake",
    from=pk,
    to=to,
    challenge=challenge,
    dh_key=dhpk,
  }
  crypto.sign(sk, pk, request)
  return request
end

--- Use this to listen to requests of other peers and initiate connection.
--- Encrypted requests will be forwarded to the specified function.
--- Use as a coroutine.
--- @param channel number The channel to listen
--- @param modem table The modem used to transmit information
--- @param peers table The peers object used for authentication
--- @param requests function The function to call when encrypted requests are catch
--- @param[opt=false] allowHandshake boolean Whether to initiate handshake requested by other peers (default to false)
local function serve(channel, modem, peers, requests, allowHandshake)
  allowHandshake = allowHandshake or false
  modem.open(channel)
  local requestChannel, message
  while 1 do
    _, _, requestChannel, _, message, _ = os.pullEvent("modem_message")
    if requestChannel == channel then
      local success, request = pcall(utils.unserialize, message)
      if success and request["to"] == peers.pk and crypto.verify(request) then
        if request["type"] ~= "s.message" then
          local response = peers:update(request, allowHandshake)
          if response ~= nil then
            modem.transmit(channel, channel, utils.serialize(response))
          end
          print(textutils.serialize(peers.peers))
        else
          print(request)
        end
      end
    end
  end
end

return {
  makeHandshakeRequest=makeHandshakeRequest,
  beginHandshakeRequest=beginHandshakeRequest,
  terminateHandshakeRequest=terminateHandshakeRequest,
  serve=serve,
}

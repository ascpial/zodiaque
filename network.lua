local crypto = require("crypto")
local aead = require("ccryptolib.aead")

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

--- Encrypt data and return the associated request
--- @param pk string The 32-bits publickey of the sender
--- @param to string The 32-bits publickey of the receiver
--- @param key string The 32-bits encryption key used for communication
--- @param nonce string The 12-bits nonce to use in this request
--- @param message string The message to encrypt and wrap into a request
--- @return table request The request to send to the other peer
local function encrypt(pk, to, key, nonce, message)
  local now = os.epoch("utc")
  local request = {
    type="s.message",
    from=pk,
    to=to,
    nonce=nonce,
    timestamp=now,
  }
  local cipher, tag = aead.encrypt(key, nonce, message, tostring(now), 8)
  request['ciphertext'] = cipher
  request['auth_tag'] = tag
  return request
end

--- Decrypts a request
--- @param key string The 32-bits key that should be used in this communication
--- @param request table The request to decrypt
--- @return boolean valid Whether the request could be decrypted or not
--- @return string ?content The content of the request or nil
local function decrypt(key, request)
  local content = aead.decrypt(key, request['nonce'], request['auth_tag'], request['ciphertext'], tostring(request['timestamp']), 8)
  if content == nil then
    return false, nil
  else
    return true, content
  end
end

local function string_with_length(value, length)
  return type(value) == "string" and #value == length
end

--- Verify that a the request content contains the excepted values and that signatures are valid
--- @param request table The request to verify
--- @return boolean valid Whether the request is valid or not
local function verify(request)
  if not string_with_length(request['from'], 32)
    or not string_with_length(request['to'], 32)
  then
    return false
  end

  if request['type'] == "s.handshake_request" then
    if type(request['next_challenge']) ~= "string" or #request["next_challenge"] < 16
       or not string_with_length(request['signature'], 64)
    then
      return false
    end
    return crypto.verify(request)
  elseif request['type'] == "s.begin_handshake" then
    if type(request['challenge']) ~= "string"
      or type(request['next_challenge']) ~= "string" or #request['next_challenge'] < 16
      or not string_with_length(request['signature'], 64)
      or not string_with_length(request['dh_key'], 32)
    then
      return false
    end
    return crypto.verify(request)
  elseif request['type'] == "s.terminate_handshake" then
    if request['challenge'] == nil
      or not string_with_length(request['dh_key'], 32)
    then
      return false
    end
    return crypto.verify(request)
  elseif request['type'] == "s.message" then
    if not string_with_length(request['nonce'], 12)
      or not string_with_length(request['auth_tag'], 16)
      or type(request['ciphertext']) ~= "string"
      or type(request['timestamp']) ~= "number" or request['timestamp'] < os.epoch("utc") - 1000 or request['timestamp'] > os.epoch("utc")
    then
      return false
    end
    return true
  else
    return false
  end
end

return {
  makeHandshakeRequest=makeHandshakeRequest,
  beginHandshakeRequest=beginHandshakeRequest,
  terminateHandshakeRequest=terminateHandshakeRequest,
  verify=verify,
  encrypt=encrypt,
  decrypt=decrypt,
}

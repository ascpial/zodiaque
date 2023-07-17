local ecdsa = require("ccryptolib.ed25519")
local utils = require("utils")

--- Signs in place a request with the sender private key
--- @param sk string The sender secrete key
--- @param pk string The sender public key
--- @param r table The request to sign
local function sign(sk, pk, r)
  local payloadString = utils.serialize(r)
  r["signature"] = ecdsa.sign(sk, pk, payloadString)
end

--- Verifies if a message was signed by the sender
--- @param r table The request to check
--- @return boolean valid true if the request was signed by the author
local function verify(r)
  local request = utils.copyTable(r)
  local signature = request["signature"]
  request["signature"] = nil
  local signedString = utils.serialize(request)
  return ecdsa.verify(request["from"], signedString, signature)
end

return {
  sign=sign,
  verify=verify,
}

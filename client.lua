local utils = require("utils")
local storage = require("storage")
local random = require("ccryptolib.random")
local ed = require("ccryptolib.ed25519")
local crypto = require("crypto")

local modem = peripheral.wrap("top")

if modem == nil then
  print("cépété")
  os.exit(300)
end

modem.open(300)

utils.initRandom()

local sk = random.random(32)
local pk = ed.publicKey(sk)

local peers = storage.Peers:new(sk, pk)

local serverPk = fs.open('secure/server.pk', 'r').readAll()

local request = peers:askHandshake(serverPk)

modem.transmit(300, 300, utils.serialize(request))

local event, side, channel, replyChannel, message, distance, request

repeat
  event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
  request = utils.unserialize(message)
until request["to"] == pk and crypto.verify(request)

local next_request = peers:update(request)

modem.transmit(300, 300, utils.serialize(next_request))

while 1 do
local input = io.read("l")

  request = peers:encrypt(serverPk, input)
  modem.transmit(300, 300, utils.serialize(request))
end

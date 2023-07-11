local utils = require("utils")
local crypto = require("crypto")
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

local peers = storage.Peers:new(sk, pk)

network.serve(
  300,
  modem,
  peers,
  function () end
)


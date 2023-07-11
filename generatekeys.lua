local ecdsa = require("ccryptolib.ed25519")
local utils = require("utils")
local random = require("ccryptolib.random")

utils.initRandom()

local skFile = fs.open("secure/server.sk", 'w')
local pkFile = fs.open("secure/server.pk", 'w')

local sk = random.random(32)
local pk = ecdsa.publicKey(sk)

skFile.write(sk)
pkFile.write(pk)

skFile.close()
pkFile.close()

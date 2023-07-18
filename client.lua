local api = require("api")
local random = require("ccryptolib.random")
local utils = require("utils")

utils.initRandom()

local client = api.Api:new(300, 'top', random.random(32))

local serverPK = fs.open("secure/server.pk", 'r').readAll()
if serverPK == nil then
  print("Did you ran generateKeys?")
  os.exit(300)
end

local function run()
  local peer = client:connect(serverPK)
  local text = read()
  api.waitForReady(peer)

  peer:send(text)
  print(api.waitForMessage(peer))
end

client:run(run)

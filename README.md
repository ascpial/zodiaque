# Zodiaque project

The zodiaque project aims to provide a clean, simple, secure and modern way of comunicating in computercraft.

The only thing you need to know before communicating is the server public key, and then everything will be encrypted and attackers won't be able to read the content of the requests nor impersonate you.

## Installing

To install the library on a computer, run the following command:

```wget run https://raw.githubusercontent.com/ascpial/zodiaque/main/install.lua```

This installer will clone two folders:

- `zodiaque` which contains the code of this project;
- `ccryptolib` which contains all crypto primitives used by this project, [made by migeyel](https://github.com/migeyel/ccryptolib).

## Demo

There is demo client and server in this repo, but keep in mind that you need to share a file containing the server public key to the client computer.

To generate the keys, on the server computer, create the folder `secure`, then run `generateKeys`, and share the file named `server.pk` (pk for public key) to the client computer in the same folder.

You can listen to all communications using the `snooper` program, which simply outputs in the consol all the trafic on the channel used by the demo client and server.

## Using the API

To start with, you need to initiate the random number generator. To do this, there is an helper function in the `zodiaque.utils` package named `initRandom` which asks random.org and initiate the generator with this data.

Now, if you develop a client, you might want to create a random secrete key to get a new identity.
To do this, you can use the following code:

```lua
local random = require("ccryptolib.random")

local sk = random.random(32) -- sk for secrete key
```

If you are a server, you need a fixed identity. You need to generate a secrete / public key pair, and store it in a file:

```lua
local random = require("ccryptolib.random")
local ed = require("ccryptolib.ed25519")

local sk = random.random(32)
local pk = ed.publicKey(sk) -- Derivate a public key from your private key
```

You can then share the public key with everyone, using a trusted channel for example floppy disks.
This public key will be used to ensure that you are who you say you are.

Once you generated or loaded you identity, which is you secrete key, you can create an API object, which will be used for communications:

```lua
local api = require("zodiaque.api")

local channel = 300 -- specifies the channel you want to use for communications
local modemSide = "top"

local client = api.Api:new(channel, modemSide, sk)
```

You is know two ways of doing things.

### Use a linear execution for you code

This method is good for a client application.
With this method, you code will be executed like any program, linearly.

First, create a function that will contain you code:

```lua
local function run()
  local peer = client:connect(serverPk) -- serverPk is the publickey of the server you want to connect to
  api.waitForReady(server) -- Will wait until the client and the server finished key exchange
  peer:send("Hello, world!") -- Send an encrypted message to the server
  print(api.waitForMessage(peer)) -- Wait for a new encrypted message and display it in the console
end
```

You can then run the program with a parallel loop which listen for messages and manages key exchange:

```lua
client:run(run)
```

### Use a function that will be execute for each request

This approach is nice for a server which listen for requests from the client.

First, creates a function that will be execute each time the server receives a request:

```lua
local function handler(peer, content)
  print(content)
  peer:send("Hello! "..content) -- Respond with a nice message
end
```

You can then serve the application:

```lua
client:serve(handler)
```

All functions are documented, so a modern IDE should be able to display to you everything you can do with this library.

To learn more about how you can access data, I recommend you to check the code of the `api.lua` file and try to understand how things goes.

## How this works

Magic.

This will be filled... one day. Or never.

To be quick: your identity is proven by the fact that you can sign challenges containing your public key, and this is how we make sure that Diffie-Hellman key exchange is done with the right person.

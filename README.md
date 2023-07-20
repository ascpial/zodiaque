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

### Identity

Each peer (we'll call a participant in any communication a peer) is identified by a string of characters. This string of characters is a public key that has been generated from a secrete key that the peer that issued it is the only to know.

A peer owns an identity if he can proves that it does know the private key associated with the public key used to identify it.

When doing authentication and exchanging a shared secret for further communications, every request is signed (the entire requst is signed, containing the sender, the receiver, and the content of the request) with the private key of the peer. In this way, other peers can check the validity of the request by verifying the request against the sender public key. If the request is valid, then:

- we can ensure that the peer that claims to be "this public key" does really own this identity;
- the request has not been tampered with.

### Handshake

To be able to encrypt application communications, we need both peer to know a shared secret, which is a key that can be used in symmetric encryption.

The authentication between Peer A (which initiate the connection) and Peer B (the other peer) goes as follow:

- Peer A, which knows the identity (public key) of Peer B, broadcast a handshake request, **signed with its private key**, that contains:

  - Its own public key (the public key of Peer A) as sender
  - The public key of Peer B as receiver
  - A random string of characters that will be used in the next part of the authentication to prevent replay attacks as next_challenge

- When Peer B receives a handshake request which has been verified, and if Peer B accepts incoming handshake request, Peer B generates a Diffie-Hellman keypair, then responds with a begin handshake request, **signed with its private key**, that contains:

  - The public key of Peer B as sender
  - The public key of Peer A as receiver
  - The challenge specified in the previous request as challenge
  - A random string of characters that will be used in the next step to prevent replay attacks as next_challenge
  - Peer B's Diffie-Hellman public key

- When Peer A receives a begin request which has been verified from someone it knows he asked handshake because it remembers the next_challenge, if the specified challenge is correct, Peer A generates a Diffie-Hellman keypair, then generates the shared secret from its private key and from Peer B's public Diffie-Hellman key, then responds with a terminate handshake request, **signer with its private key**, that contains:

  - The public key of Peer A as sender
  - The public key of Peer B as receiver
  - The challenge specified in the previous request as challenge
  - Peer A's Diffie-Hellman public key

- When Peer B receives a terminate request which has been verified, if it knows a secrete Diffie-Hellman key for Peer A and if the challenge correspond to the one it remembers, Peer B computes the shared secrete from Peer A's Diffie-Hellman public key and store it.

When the handshake is finished, Peer A and Peer B can send messages to each other, while keeping privacy, authenticity and integrity.

### In practice

In this section, we will go through how this algorithm is implemented in practice.

#### Signing requests

The first part, and the most important aspect of this implementation, beside primitives implementations, is how we manage requests signing.

A request is a Lua table serialized. One issue with the default `textutils.serialize` implementation is that the order of the keys inside the serialized body is always the same because it depends on the Lua `next()` function, which, as per Lua docs:

> The order in which the indices are enumerated is not specified, even for numeric indices.

The idea behind request signing is that you serialize in a string the request, you sign it, then add the signature in the original request table and serialize it again.

You cannot use the default `textutils.serialize` function because, depending on background factors, the order will be different, and thus the signature will be considered invalid if you remove the signature from the table and serialize it again.

In the zodiaque package, the function `utils.serialize` will serialize the string with the keys sorted in alphanumerical order, and the order should be predictable.

To summarize:

- to sign a request, you serialize it into a string, and then sign this string;
- you add the signature into the request table;
- you serialize the table again, and can then send this string to the other peer.

To verify a request:

- you unserialize the request, and remove the signature from this table;
- you serialize the table again and check the signature on this string.

#### Request format

The format of a request is the following:

- field `from` (required): this field contains the public key of the sender. Signature should be verified against this key.
- field `to` (required): this field contains the public key of the receiver. Should be the first field checked when receiving a request.
- field `type` (required): denote the type of the request. Can be `s.ask_handshake`, `s.begin_handshake`, `s.terminate_handshake` and `s.message`.
- field `signature` (required for handshake requests): The signature used to prove that the message was send by the sender specified in the `from` field. This is the only field which is not included when serializing a request to sign it.

Other fields are specific to a request type.

#### 

## Developing

If you want to work on the project, you can clone the repo in a folder and mount it in a computer using an emulator.

You just need to clone as well the [ccryptolib project](https://github.com/migeyel/ccryptolib) and copy the folder `ccryptolib` in the folder of the zodiaque project (the ccryptolib folder was added to the .gitignore so it won't be an issue).

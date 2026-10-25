## 3.0.0-alpha.7

- Uses `ioredis` 2.0.0-alpha.3, which can send and get binary messages. `RedisAdapter` and `SocketIoEmitter` take `ioredis` clients.
- `RedisAdapter` reads msgpack and JSON messages. Before, it read only JSON, so the Socket.IO emitters (Node.js, PHP, Python, Go) did not work. They use msgpack.
- Breaking: `RedisAdapter` writes msgpack by default, like `@socket.io/redis-adapter`. Use `format: RedisFormat.json` for Node.js servers with a JSON parser.
- Fix: binary data in JSON Redis messages is written as a Node.js Buffer (`{"type":"Buffer","data":[...]}`). Before, it was written as a plain list of numbers.
- `RedisAdapter` handles the requests on `socket.io-request#<nsp>#`: `socketsJoin`, `socketsLeave` and `disconnectSockets` from emitters and other servers. It answers `fetchSockets`, `allRooms` and broadcasts with acks from Node.js servers, so they do not wait for a timeout.
- New `SocketIoEmitter(redis)`: sends events, `socketsJoin`, `socketsLeave` and `disconnectSockets` through Redis without a Socket.IO server. Same format as `@socket.io/redis-emitter`.
- New `MsgPack` encoder and decoder.
- Performance: a broadcast builds the websocket text frame and its UTF-8 bytes once and shares them with every client (new `SharedText`). Before, each client built and encoded its own copy.
- Performance: a broadcast with no `except` and at most one room goes over the room members directly. Before, it copied all socket ids into new sets each time.
- Breaking: `SocketIoServer.listen()` starts a native server (`dox_http_native`), not a `dart:io` one. The websocket transport uses the native WebSocket upgrade. Long-polling works the same. `attach()` still takes any `HttpServer`, also a `dart:io` one.
- Security: on the native server, a websocket message over `maxHttpBufferSize` bytes is closed with 1009 in Rust, before Dart reads it.
- Security: a binary packet nested deeper than 32 levels is a parse error (`SocketDecoder(maxDepth: ...)`). Before, a deep packet overflowed the stack and could stop the server. Any decode error now closes only that one connection.
- Security: many CONNECT packets for one namespace at once make only one socket. Before, each one made a socket that stayed in memory.
- Security: websocket compression is off. A small compressed message could grow very big in memory.
- Security: when `CorsOptions.origins` lists origins, a websocket from another origin gets 403. With no `cors`, or with `*`, any origin is still allowed.
- Breaking: `CorsOptions(origins: ['*'], credentials: true)` throws an `ArgumentError`. Before, it sent back any origin with credentials.
- Security: a middleware error that is not a `SocketIoException` sends `{"message": "Internal error"}` to the client and writes the real error to stderr.
- Security: a client whose CONNECT is refused is closed after `connectTimeout`. Before, it could stay connected forever.

- Security: a binary packet may have at most 10 attachments (`SocketDecoder(maxAttachments: ...)`). More closes the connection with a parse error. Before, a client could send `51000000-[...]` before any auth and the server kept every binary frame after it in memory.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- Version bump only, to match the other packages.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.

## 3.0.0-alpha.1

- Uses `ioredis` 2.
- `RedisAdapter` listens with `PSUBSCRIBE`, so it also gets the room channels that the Node.js redis adapter uses for one room. `onRedisMessage` now takes `(pattern, channel, message)`.
- First version. Socket.IO v4 server (Engine.IO v4, Socket.IO protocol v5).
- Polling and websocket transports, upgrade, heartbeat, CORS.
- Namespaces, middleware, rooms, broadcast, acks, binary.
- In-memory adapter and Redis adapter.

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

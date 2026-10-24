## Unreleased

- Breaking: websockets run on the native server (`dox_http_native`), not on `dart:io`. Rust does the upgrade and the WebSocket protocol. The public API is the same: the socket is still a `dart:io` `WebSocket`.
- Security: a message over `maxMessageSize` bytes is now closed with 1009 in Rust, before Dart reads it. Before, `dart:io` read the whole message into memory first.
- Breaking: `joinRoom` is refused unless you set `WebsocketServer().authorizeJoin`. Before, any client could join any room, like `user:42`, and get its messages.
- Security: new `WebsocketServer().allowedOrigins`. When set, a websocket from another origin gets 403. When null (the default), any origin is allowed.
- Security: websocket compression is off, and a message bigger than `WebsocketServer().maxMessageSize` (default 1 MB) closes the connection with code 1009.

- Security: a client can not `joinRoom` a room that starts with `room:`. That is the default room of a route, so a client of a public route could join the room of a route with auth middleware and get all its messages.
- Security: a room with no members is removed, and a room name longer than 255 chars is not joined. Before, every room name a client sent stayed in memory, so one client could fill the memory of the server.

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
- `WebsocketAdapterInterface.emit` now has a `void` return type.

## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.
- `uuid` 4 and `ioredis` 2.

## 1.0.0

- Initial version.

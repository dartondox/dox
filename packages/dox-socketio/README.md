# dox_socketio

Socket.IO v4 server for Dart. It works with the Dox framework and with plain `dart:io`.

[![pub package](https://img.shields.io/pub/v/dox_socketio.svg)](https://pub.dev/packages/dox_socketio)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_socketio
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

## Use it

```dart
import 'package:dox_socketio/dox_socketio.dart';

Future<void> main() async {
  SocketIoServer io = SocketIoServer();
  io.on('connection', onConnection);
  await io.listen(3001);
}

void onConnection(Socket socket) {
  socket.emit('welcome', 'hello');
  socket.join('lobby');
  socket.on('chat', onChat);
}

void onChat(SocketEvent event) {
  event.socket.to('lobby').emit('chat', event.data); // everyone in lobby but me
  event.ack('ok'); // answer the client callback
}
```

The official clients connect with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package.
In a Dox app, turn it on with `AppConfig(socketIo: SocketIoConfig(enabled: true))`. It then runs on the app port.

## Features

- Engine.IO protocol v4 and Socket.IO protocol v5 (the protocols of Socket.IO v4).
- Polling and websocket transports, upgrade, heartbeat and CORS.
- Namespaces (also as classes), middleware, rooms, broadcast, acks and binary data.
- In-memory adapter, and a Redis adapter for many servers.
- The Redis adapter uses the message format of `@socket.io/redis-adapter`.
- Limits: `fetchSockets`, `socketsJoin` and broadcast acks work only on the local server.

## Documentation

- [Socket.IO](https://dartondox.dev/latest/packages/socketio/)
- [API reference](https://pub.dev/documentation/dox_socketio/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

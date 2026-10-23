# dox_websocket

WebSocket routes for Dox apps, with rooms and a Redis adapter for many isolates.

[![pub package](https://img.shields.io/pub/v/dox_websocket.svg)](https://pub.dev/packages/dox_websocket)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

```bash
dart pub add dox_websocket
```

Dox 3.x is in alpha (`3.0.0-alpha.4`). The API can still change before the stable release.

## Use it

Start the WebSocket server in a service:

```dart
import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WebsocketService implements DoxService {
  @override
  void setup() {
    WebsocketServer(Dox()); // one isolate. For many, add WebsocketRedisAdapter.
  }
}
```

Add a route and a controller:

```dart
class ChatController {
  void intro(WebsocketEmitter emitter, dynamic message) {
    emitter.room('chat').emitExceptSender('intro', message);
  }
}

ChatController chat = ChatController();

Route.websocket('ws', (WebsocketEvent event) {
  event.on('intro', chat.intro);
});
```

The client sends JSON text like `{"event": "intro", "message": "hi"}` to `ws://127.0.0.1:3000/ws`.

## Features

- `Route.websocket(path, callback)` with middleware, like other routes.
- Rooms. The client joins with the built-in `joinRoom` event.
- `emit`, `emitExceptSender` and `emitToSender`.
- `WebsocketRedisAdapter` sends each message to all isolates and all servers.
- A JavaScript client: [`@dartondox/websocket`](https://github.com/dartondox/dox-web-socket-client/).

An app with a WebSocket route runs on the `dart:io` server, because the native server can not upgrade connections yet.
For the official Socket.IO clients, use `dox_socketio`.

## Documentation

- [WebSocket](https://dartondox.dev/latest/digging-deeper/websocket/)
- [API reference](https://pub.dev/documentation/dox_websocket/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).

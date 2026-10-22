# WebSocket

`dox_websocket` adds WebSocket routes to a Dox app. Use it for live chat, notifications and other real-time updates.

!!! tip "Want Socket.IO clients?"
    Use [Socket.IO](../packages/socketio.md#in-a-dox-app-same-port-as-http). Turn it on with `AppConfig(socketIo: SocketIoConfig(enabled: true))`.
    It runs on the same port, works with the official Socket.IO clients, and has acks and namespaces.
    `dox_websocket` keeps working next to it.

!!! info "WebSocket uses the `dart:io` server"
    The native server can not upgrade a connection to WebSocket yet.
    So when your app has a WebSocket route, Dox uses the `dart:io` server by itself.
    See [Native server](native-server.md#use-dartio-instead).

## Setup

### 1. Add the package

```bash
dart pub add dox_websocket:^3.0.0-alpha.4
```

### 2. Create a WebSocket service

The service creates the WebSocket server in every isolate. See [Services](services.md).

#### Many isolates (Redis)

Pick this for production. It works with more than one isolate and more than one server.

```dart title="lib/services/websocket_service.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:ioredis/ioredis.dart';

class WebsocketService implements DoxService {
  @override
  void setup() {
    Redis sub = Redis(RedisOptions(host: Env.get('REDIS_HOST', '127.0.0.1')));
    Redis pub = sub.duplicate();

    WebsocketServer io = WebsocketServer(Dox());
    io.adapter(WebsocketRedisAdapter(subscriber: sub, publisher: pub));
  }
}
```

Add [`ioredis`](https://pub.dev/packages/ioredis) `^2.0.0-alpha.2` to your `pubspec.yaml`.

#### One isolate

Pick this for a small app or for local work, when you do not want Redis.

```dart title="lib/services/websocket_service.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_websocket/dox_websocket.dart';

class WebsocketService implements DoxService {
  @override
  void setup() {
    WebsocketServer(Dox());
  }
}
```

Set `totalIsolate: 1` in `lib/config/app.dart` (or `APP_TOTAL_ISOLATE=1`).

!!! warning "Many isolates need Redis"
    Dox runs one isolate per CPU core by default. Each isolate has its own memory.
    Without an adapter, a message only reaches clients on the same isolate.
    The Redis adapter sends each message to all isolates and all servers.

### 3. Register the service

```dart title="lib/config/services.dart"
List<DoxService> services = <DoxService>[
  // ... other services
  WebsocketService(),
];
```

### 4. Create a controller

```bash
dox create:controller Chat -ws
```

This makes `lib/app/ws/controllers/chat.controller.dart`. Each method gets the `WebsocketEmitter` and the message from the client:

```dart title="lib/app/ws/controllers/chat.controller.dart"
import 'package:dox_websocket/dox_websocket.dart';

class ChatController {
  void intro(WebsocketEmitter emitter, dynamic message) {
    // send to the 'chat' room, but not to the sender
    emitter.room('chat').emitExceptSender('intro', message);
  }

  void noti(WebsocketEmitter emitter, dynamic message) {
    // send to the 'chat' room, also to the sender
    emitter.room('chat').emit('noti', message);
  }
}
```

A WebSocket connection stays open. So a controller method does not need to return a value.

### 5. Add the route

Use `Route.websocket(path, callback)`. In the callback, map each event name to a controller method:

```dart title="lib/routes/web.dart"
ChatController chat = ChatController();

Route.websocket('ws', (WebsocketEvent event) {
  // the client sends event `intro`: run chat.intro
  event.on('intro', chat.intro);
  event.on('noti', chat.noti);
});
```

The URL is `ws://127.0.0.1:{port}/ws`. You can add more WebSocket routes on other paths.
`Route.websocket` also takes `middleware:`, like other routes.

## Messages

Client and server send JSON text.

The client sends `event` and `message`:

```json
{"event": "intro", "message": "Mingalaba!"}
```

The server sends `event`, `message`, `sender` (the socket id of the sender) and `room`:

```json
{"event": "intro", "message": "Mingalaba!", "sender": "ws:4f1c...", "room": "chat"}
```

Two events are built in:

| Event | Direction | What it does |
| --- | --- | --- |
| `connected` | server to client | sent once after connect. `message` is `{"id": "<socket id>"}` |
| `joinRoom` | client to server | joins the room. `message` is the room name |

Each client is also in a room for its route, so `emitter.emit()` with no room reaches all clients of the same route.

## Client examples

### Dart

Use `WebSocket` from `dart:io`.

```dart
import 'dart:convert';
import 'dart:io';

void main() async {
  WebSocket socket = await WebSocket.connect('ws://localhost:3000/ws');

  socket.listen((dynamic data) {
    Map<String, dynamic> payload = jsonDecode(data as String);
    print('${payload['event']}: ${payload['message']}');
  });

  // join the chat room
  socket.add(jsonEncode(<String, dynamic>{
    'event': 'joinRoom',
    'message': 'chat',
  }));

  // send the intro event
  socket.add(jsonEncode(<String, dynamic>{
    'event': 'intro',
    'message': 'Mingalaba!',
  }));
}
```

### JavaScript

Use the browser `WebSocket`, or the client [`@dartondox/websocket`](https://github.com/dartondox/dox-web-socket-client/):

```js
import DoxWebsocket from '@dartondox/websocket';

const socket = DoxWebsocket('ws://127.0.0.1:3000/ws', {
  maxRetries: 18,
  retryAfter: 2000,
});

socket.onConnected(() => console.log(socket.id));
socket.onError(() => console.log('socket error'));
socket.onClose(() => console.log('socket closed'));

// listen for the intro event from the server
socket.on('intro', (msg) => console.log(msg));

// send the intro event
socket.emit('intro', 'Mingalaba!');
```

## WebsocketEmitter

### `room`

Pick the room to send to. Use the same name the client sent with `joinRoom`.

```dart
emitter.room('chat').emit('event-name', message);
```

`room()` returns a new emitter. The room does not stay set for later events.

### `emit`

Send to every client in the room. Without `room()`, this is every client of the same route.

```dart
emitter.emit('event-name', message);
```

### `emitExceptSender`

Send to every client in the room, but not to the sender.

```dart
emitter.emitExceptSender('event-name', message);
```

### `emitToSender`

Send only to the client that sent the event.

```dart
emitter.emitToSender('event-name', message);
```

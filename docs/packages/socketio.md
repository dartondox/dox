# Socket.IO

This page shows how to run a Socket.IO server with `dox_socketio`, inside Dox or on its own.

`dox_socketio` is a Socket.IO v4 server for Dart.
The official clients connect to it with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package.

!!! tip "Socket.IO or WebSocket?"
    - [WebSocket](../digging-deeper/websocket.md) (`dox_websocket`) runs inside the Dox HTTP server. It uses its own small JSON format.
    - Socket.IO (this page) works with the Socket.IO clients. It has acks, namespaces, binary data and long-polling.

## Install

```bash
dart pub add dox_socketio
```

## Quick start

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

Client (JavaScript):

```js
import { io } from 'socket.io-client';

const socket = io('http://localhost:3001');
socket.emit('chat', 'hi', (answer) => console.log(answer)); // 'ok'
```

## In a Dox app: same port as HTTP

`dox_core` can serve Socket.IO at `/socket.io/` on the app port. It is off by default.

`dox_core` does not export `dox_socketio`. Add it, and `ioredis` for the Redis adapter:

```bash
dart pub add dox_socketio ioredis
```

```dart title="lib/config/socketio.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart';
import 'package:my_app/app/socket/chat.namespace.dart';
import 'package:my_app/config/env.dart';

Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));

SocketIoConfig socketIo = SocketIoConfig(
  enabled: env.socketioEnabled,
  namespaces: <NamespaceHandler>[ChatNamespace(MessageService())],
  adapter: const RedisSocketAdapterFactory(), // shares broadcasts between isolates
);

/// makes the Redis adapter inside each isolate
class RedisSocketAdapterFactory extends SocketAdapterFactory {
  const RedisSocketAdapterFactory();

  @override
  Adapter create() {
    return RedisAdapter(subscriber: redis.duplicate(), publisher: redis);
  }
}
```

Add a getter for the `SOCKETIO_ENABLED` key to `lib/config/env.dart`, then run `dart run build_runner build`:

```dart title="lib/config/env.dart"
  /// serve Socket.IO on the app port
  bool get socketioEnabled => false;
```

```dart title="lib/config/app.dart"
AppConfig appConfig = AppConfig(
  socketIo: socketIo,
  // ...
);
```

| `SocketIoConfig` option | Default | What it does |
| --- | --- | --- |
| `enabled` | `false` | serve Socket.IO at `options.path` |
| `options` | `ServerOptions()` | see [Options](#options) |
| `namespaces` | `[]` | `NamespaceHandler` classes to register |
| `adapter` | `null` (in-memory) | makes one adapter in each isolate |

- Requests to `/socket.io/` go to Socket.IO before the router. Middleware and body reading are skipped.
- When it is off, there is no extra work per request.
- `Dox().socketIo` is the server of this isolate: `Dox().socketIo?.to('room').emit('news', data)`.
- `dox_websocket` (`Route.websocket`) still works next to it.

!!! warning "Many isolates"
    Dox runs one isolate per CPU core, and each isolate has its own Socket.IO server.

    - Clients should connect with **websocket only**. One websocket stays on one isolate.
      With the Redis adapter, a broadcast reaches clients on every isolate.
    - HTTP long-polling sends many requests, and they can reach different isolates. It only works
      with `totalIsolate: 1`, or with sticky sessions in front of many single-isolate servers.

    ```js
    const socket = io('http://localhost:3000/chat', { transports: ['websocket'] });
    ```

    Dox logs this hint at startup when it runs many isolates and polling is allowed.

## Where to run it (outside Dox)

`io.listen(port)` opens its own port. Run it in its own small program, for example `bin/socket.dart`,
next to the Dox HTTP server. Put both behind the same proxy.

- `io.attach(httpServer)` uses a `dart:io` server you already have.
- In your own `dart:io` server, call `io.handle(request)` when `io.matches(request)` is true.
- The path is `/socket.io/` by default.

## Namespaces in a class

A namespace can be a class. Its dependencies come in through the constructor.

```dart
class ChatNamespace extends NamespaceHandler {
  ChatNamespace(this.messages);

  final MessageService messages;

  @override
  String get path => '/chat';

  @override
  List<Middleware> get middleware => <Middleware>[checkToken];

  void checkToken(Socket socket) {
    if (socket.handshake.auth['token'] != 'secret') {
      throw SocketIoException('unauthorized', data: {'reason': 'bad token'});
    }
  }

  @override
  void onConnection(Socket socket) {
    socket.on('message', onMessage);
  }

  void onMessage(SocketEvent event) {
    event.ack(messages.save(event.data));
  }
}

io.register(ChatNamespace(MessageService()));
```

When a middleware throws, the client gets `connect_error` with the message and the data.

## Node.js to Dart

| Node.js | Dart |
| --- | --- |
| `socket.on('e', (a, cb) => ...)` | `socket.on('e', (SocketEvent e) => ...)`, then `e.data`, `e.args`, `e.ack(x)` |
| `socket.emit('e', a, b)` | `socket.emit('e', a)` or `socket.emitArgs('e', [a, b])` |
| `await socket.timeout(5000).emitWithAck('e', a)` | `await socket.emitWithAck('e', a, timeout: Duration(seconds: 5))` |
| `socket.join(r)` / `socket.leave(r)` | the same |
| `socket.to(r).emit(...)` | the same |
| `socket.broadcast.emit(...)` | the same |
| `io.to(r).except(x).emit(...)` | the same |
| `io.of('/chat')`, `io.use(fn)` | the same |
| `socket.handshake` | `.headers`, `.query`, `.auth`, `.address` |
| `socket.data` | `socket.data` (a `Map`) |
| `io.in(r).fetchSockets()` | `io.to(r).fetchSockets()` (this server only) |

- `disconnecting` and `disconnect` give the reason in `event.data`, like `transport close` or `ping timeout`.
- Binary data: send a `Uint8List`. It can be anywhere in lists and maps.

## Options

```dart
SocketIoServer(
  options: ServerOptions(
    path: '/socket.io/',
    pingInterval: Duration(seconds: 25),
    pingTimeout: Duration(seconds: 20),
    maxHttpBufferSize: 1000000,
    transports: ['polling', 'websocket'],
    cors: CorsOptions(origins: ['https://my.app'], credentials: true),
  ),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `path` | `/socket.io/` | the URL path |
| `pingInterval` | 25 s | how often the server sends a ping |
| `pingTimeout` | 20 s | how long to wait for the pong before the client is gone |
| `upgradeTimeout` | 10 s | how long an upgrade from polling to websocket may take |
| `connectTimeout` | 45 s | how long the client has to join a namespace |
| `maxHttpBufferSize` | 1,000,000 bytes | the biggest message |
| `transports` | `['polling', 'websocket']` | allowed transports |
| `allowUpgrades` | `true` | let polling clients move to websocket |
| `cors` | `null` | CORS headers for polling requests |

## Many servers: Redis adapter

With more than one server process, use the Redis adapter.
Then a broadcast on one server reaches the clients of all servers.

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
SocketIoServer io = SocketIoServer(
  adapter: RedisAdapter(subscriber: redis.duplicate(), publisher: redis),
);
```

The subscriber needs its own connection. A Redis connection in subscribe mode can not run other commands.

- It uses the message format of `@socket.io/redis-adapter`. A Node.js server can share broadcasts with it, when Node uses a JSON parser.
- `fetchSockets`, `socketsJoin` and broadcast acks only work on the local server.
- Long-polling needs sticky sessions when many servers share one port.
  If you can not have them, use `transports: ['websocket']` on the client.

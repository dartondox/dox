---
icon: lucide/radio-tower
---

# Socket.IO

This page shows how to run a Socket.IO server with `dox_socketio`, inside Dox or on its own.

`dox_socketio` is a Socket.IO v4 server for Dart.
The official clients connect to it with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package.
It has acks, rooms, namespaces, binary data and long-polling.
Socket.IO is the way to do realtime in Dox.

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
- Need a plain WebSocket with no Socket.IO protocol? `Route.websocket(path, handler)` in `dox_core` gives you the raw socket.

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

- `io.listen(port)` starts a native server (`dox_http_native`).
- `io.attach(httpServer)` uses a server you already have: a `NativeHttpServer` or a `dart:io` one.
- In your own server, call `io.handle(request)` when `io.matches(request)` is true.
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

When a middleware throws a `SocketIoException`, the client gets `connect_error` with the message and the data.
Any other error is written to stderr. The client only gets `{"message": "Internal error"}`, so it can not see private text like SQL.

A client that is refused is still closed after `connectTimeout`, unless it joins another namespace.

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
| `maxHttpBufferSize` | 1,000,000 bytes | the biggest message. A bigger websocket message closes the connection |
| `transports` | `['polling', 'websocket']` | allowed transports |
| `allowUpgrades` | `true` | let polling clients move to websocket |
| `cors` | `null` | CORS headers for polling requests. It also checks the origin of websockets |

- `cors` with a list of origins: a websocket from another origin gets 403. A request with no `Origin` header (not a browser) is allowed.
- `cors: null`, or `*` in `origins`: websockets from any origin are allowed. If you log users in with cookies, list your origins.
- `*` together with `credentials: true` throws an `ArgumentError`. List your origins instead.
- Websocket compression is off. A message bigger than `maxHttpBufferSize` closes with code 1009.
- On a plain `dart:io` server (`io.attach`), the whole message is read before the size check. Also set a size limit in your proxy.

## Many servers: Redis adapter

With more than one server process, use the Redis adapter.
Then a broadcast on one server reaches the clients of all servers.

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
SocketIoServer io = SocketIoServer(
  adapter: RedisAdapter(subscriber: redis.duplicate(), publisher: redis),
);
```

- `Redis` comes from the `ioredis` package (`^2.0.0-alpha.3`).
- The subscriber needs its own connection. A Redis connection in subscribe mode can not run other commands.
- It uses the format of `@socket.io/redis-adapter`. Node.js servers with that adapter can share one Redis with Dox servers.
- It reads messages in msgpack and in JSON. It writes msgpack, like the Node.js adapter.
  If your Node.js servers use a JSON parser, set `format: RedisFormat.json`.
- Other servers can ask a Dox server for `fetchSockets`, `allRooms`, `socketsJoin`, `socketsLeave` and `disconnectSockets`. It answers.
- On a Dox server, `fetchSockets`, `socketsJoin`, `socketsLeave` and `disconnectSockets` only act on its own sockets.
  To act on all servers, use an [emitter](#emit-from-other-programs).
- Broadcast acks from other servers: Dox clients get the event, but their acks are not sent back.
- `serverSideEmit` from other servers is ignored.
- Long-polling needs sticky sessions, the same as with [many isolates](#in-a-dox-app-same-port-as-http). Or use `transports: ['websocket']` on the client.

## Emit from other programs

An emitter sends events to your clients without a Socket.IO server.
Use it in a queue worker, a cron job or a service in another language.
It writes to Redis, and every server with the Redis adapter sends the event to its clients.

Dart (for example in a Dox queue job or a CLI command):

```dart
import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart';

Future<void> main() async {
  Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
  SocketIoEmitter emitter = SocketIoEmitter(redis);

  await emitter.emit('news', {'title': 'hello'}); // all clients of `/`
  await emitter.to('room1').except('room2').emit('news', 'hi room1');
  await emitter.of('/chat').to('vip').emit('notice', 'for vip');

  await emitter.to('room1').socketsJoin('room3'); // sockets in room1 join room3
  await emitter.to('room3').socketsLeave('room1');
  await emitter.to('banned').disconnectSockets();

  await redis.disconnect();
}
```

Node.js, with [`@socket.io/redis-emitter`](https://www.npmjs.com/package/@socket.io/redis-emitter):

```js
import { Emitter } from '@socket.io/redis-emitter';
import { createClient } from 'redis';

const redis = createClient({ url: 'redis://127.0.0.1:6379' });
await redis.connect();

const emitter = new Emitter(redis);
emitter.to('room1').emit('news', { title: 'hello' });
emitter.of('/chat').emit('notice', 'for everyone in /chat');
```

- The emitters of other languages (PHP, Python, Go) use the same format, so they work too.
- Binary data (`Uint8List` in Dart, `Buffer` in Node.js) arrives as binary.
- The emitter does not wait for an answer. It can not know if a client got the event.
- `key` must be the same as the `key` of the adapter. Both default to `socket.io`.

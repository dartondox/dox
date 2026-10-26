---
icon: lucide/radio-tower
---

# Socket.IO

This page shows how to set up Socket.IO in a Dox app with `dox_socketio`.

It can also run on its own, see [Without Dox](#without-dox).

`dox_socketio` is a Socket.IO v4 server for Dart.
The official clients connect to it with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package.
It has acks, rooms, namespaces, binary data and long-polling.
Socket.IO is the way to do realtime in Dox.

## In a Dox app

Socket.IO runs on the same port as your HTTP routes, at `/socket.io/`. You add a provider, a config, a namespace and one env key.

### 1. Install

```bash
dart pub add dox_socketio
```

### 2. The provider

The provider starts Socket.IO in every isolate. Put it in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/socketio_provider.dart"
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/config/socketio.dart';

class AppSocketIoProvider extends SocketIoProvider {
  AppSocketIoProvider() : super(socketIoConfig);
}
```

### 3. The config

The config says which namespaces to serve:

```dart title="lib/config/socketio.dart"
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/app/socket/chat.namespace.dart';
import 'package:my_app/config/env.dart';

SocketIoConfig socketIoConfig = SocketIoConfig(
  enabled: env.socketioEnabled,
  namespaces: <NamespaceHandler>[ChatNamespace()],
);
```

| `SocketIoConfig` option | Default | What it does |
| --- | --- | --- |
| `enabled` | `true` | serve Socket.IO at `options.path` |
| `options` | `ServerOptions()` | see [Options](#options) |
| `namespaces` | `[]` | `NamespaceHandler` classes to register |
| `adapter` | `null` (in memory) | makes one adapter in each isolate, see [Many isolates](#many-isolates-redis-adapter) |

### 4. A namespace

A namespace handles the events of one path, like `/chat`:

```dart title="lib/app/socket/chat.namespace.dart"
import 'package:dox_socketio/dox_socketio.dart';

class ChatNamespace extends NamespaceHandler {
  @override
  String get path => '/chat';

  @override
  void onConnection(Socket socket) {
    socket.emit('welcome', <String, dynamic>{'id': socket.id});
    socket.join('lobby');
    socket.on('message', onMessage);
  }

  void onMessage(SocketEvent event) {
    event.socket.to('lobby').emit('message', event.data); // everyone in lobby but me
    event.ack('sent'); // answer the client callback
  }
}
```

See [Namespaces](#namespaces) for middleware and dependencies.

### 5. Turn it on

Add a getter for the `SOCKETIO_ENABLED` key to `lib/config/env.dart`:

```dart title="lib/config/env.dart"
  /// serve Socket.IO on the app port
  bool get socketioEnabled => false;
```

```bash title=".env"
SOCKETIO_ENABLED=true
```

Then run `dart run build_runner build` and `dox serve`.

### 6. Connect a client

```js
import { io } from 'socket.io-client';

const socket = io('http://localhost:3000/chat', { transports: ['websocket'] });
socket.on('welcome', (data) => console.log(data.id));
socket.emit('message', 'hi', (answer) => console.log(answer)); // 'sent'
```

Use `transports: ['websocket']`. See [Many isolates](#many-isolates-redis-adapter) for why.

### Send from a controller or a service

`SocketIoProvider.server` is the Socket.IO server of this isolate:

```dart
await SocketIoProvider.server?.of('/chat').to('lobby').emit('news', data);
```

From a queue job or another program, use the [emitter](#emit-from-other-programs).

- Requests to `/socket.io/` go to Socket.IO before the router. Middleware and body reading are skipped.
- With no provider, or with `enabled: false`, there is no extra work per request.
- Need a plain WebSocket with no Socket.IO protocol? `Route.websocket(path, handler)` in `dox_core` gives you the raw socket.

### Many isolates: Redis adapter

Dox runs one isolate per CPU core, and each isolate has its own Socket.IO server.
With the default in-memory adapter, a broadcast only reaches the clients of the same isolate.
Use the Redis adapter, so a broadcast reaches clients on every isolate (and on every server).

```bash
dart pub add ioredis
```

```dart title="lib/config/socketio.dart"
import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart';
import 'package:my_app/app/socket/chat.namespace.dart';
import 'package:my_app/config/env.dart';

SocketIoConfig socketIoConfig = SocketIoConfig(
  enabled: env.socketioEnabled,
  namespaces: <NamespaceHandler>[ChatNamespace()],
  adapter: const RedisSocketAdapterFactory(),
);

/// makes the Redis adapter inside each isolate.
/// A Redis connection can not be sent to another isolate.
class RedisSocketAdapterFactory extends SocketAdapterFactory {
  const RedisSocketAdapterFactory();

  @override
  Adapter create() {
    Redis redis = Redis(); // 127.0.0.1:6379. Or Redis(RedisOptions(host: ..., port: ...))
    return RedisAdapter(subscriber: redis.duplicate(), publisher: redis);
  }
}
```

!!! warning "Clients should connect with websocket only"
    One websocket stays on one isolate. HTTP long-polling sends many requests, and they can reach different isolates.
    Long-polling only works with `totalIsolate: 1`, or with sticky sessions in front of many single-isolate servers.
    Dox logs this hint at startup when it runs many isolates and polling is allowed.

## Without Dox

`dox_socketio` also runs on its own, with no Dox app:

```dart
import 'package:dox_socketio/dox_socketio.dart';

Future<void> main() async {
  SocketIoServer io = SocketIoServer();
  io.register(ChatNamespace());
  await io.listen(3001);
}
```

- `io.listen(port)` starts a native server (`dox_http_native`) on its own port. Run it in its own small program, for example `bin/socket.dart`, and put it behind the same proxy as the HTTP server.
- `io.attach(httpServer)` uses a server you already have: a `NativeHttpServer` or a `dart:io` one.
- In your own server, call `io.handle(request)` when `io.matches(request)` is true.
- `io.on('connection', (Socket socket) {...})` handles the default namespace `/` with no class.

## Namespaces

A namespace is a class. Its dependencies come in through the constructor.

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
      throw SocketIoException('unauthorized', data: <String, dynamic>{'reason': 'bad token'});
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

// in lib/config/socketio.dart
namespaces: <NamespaceHandler>[ChatNamespace(MessageService())],
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
| `await io.in(r).fetchSockets()` | `await io.to(r).fetchSockets()` (all servers) |
| `await io.timeout(5000).emitWithAck('e', a)` | `await io.timeout(Duration(seconds: 5)).emitWithAck('e', a)` |
| `io.serverSideEmit('e', a)` | `await io.serverSideEmit('e', [a])` |
| `io.on('e', (a, cb) => ...)` (from other servers) | `io.onServerSideEmit('e', (ServerSideEvent e) => ...)`, then `e.data`, `e.ack(x)` |

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
    transports: <String>['polling', 'websocket'],
    cors: CorsOptions(origins: <String>['https://my.app'], credentials: true),
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
| `maxAttachments` | `10` | the most binary parts in one packet. A packet with more closes that client |
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

- `Redis` comes from the `ioredis` package.
- The subscriber needs its own connection. A Redis connection in subscribe mode can not run other commands.
- It uses the format of `@socket.io/redis-adapter`. Node.js servers with that adapter can share one Redis with Dox servers.
- It reads messages in msgpack and in JSON. It writes msgpack, like the Node.js adapter.
  If your Node.js servers use a JSON parser, set `format: RedisFormat.json`.
- `fetchSockets`, `socketsJoin`, `socketsLeave` and `disconnectSockets` act on the sockets of all servers.
- Broadcasts with an ack get the acks of clients on all servers.
- Servers can send events to each other with `serverSideEmit`. Clients do not get them.
- A request waits at most `requestsTimeout` for the other servers (5 seconds by default, like Node.js).
- Long-polling needs sticky sessions, the same as with [many isolates](#many-isolates-redis-adapter). Or use `transports: ['websocket']` on the client.

### Act on all servers

```dart
// sockets of every server. Sockets of this server are `Socket`s.
List<RemoteSocket> sockets = await io.to('room1').fetchSockets();
for (RemoteSocket socket in sockets) {
  socket.emit('hello', socket.data['name']);
}

await io.to('room1').socketsJoin('room2');
await io.to('banned').disconnectSockets();

// one ack per client, from all servers. A timeout is needed.
List<Object?> answers = await io
    .timeout(const Duration(seconds: 5))
    .emitWithAck('ping', 'are you there?');
```

`fetchSockets` throws a `TimeoutException` when a server does not answer in time.

### Events between servers

`serverSideEmit` sends an event to the other servers. Clients do not get it.

```dart
// on every server
io.onServerSideEmit('reload-config', (ServerSideEvent event) {
  reloadConfig(event.data);
  event.ack('done'); // only when the sender waits for an answer
});

// on one server
await io.serverSideEmit('reload-config', <Object?>['v2']);

// wait for one answer from each other server
List<Object?> answers = await io.serverSideEmitWithAck('reload-config', <Object?>['v2']);
```

When a server does not answer in time, `serverSideEmitWithAck` throws an `AckTimeoutException`. Its `responses` holds the answers that came back.
`onServerSideEmit` is also on namespaces: `io.of('/chat').onServerSideEmit(...)`.

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

  await emitter.emit('news', <String, dynamic>{'title': 'hello'}); // all clients of `/`
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

---
icon: lucide/radio-tower
---

# Socket.IO

`dox_socketio` is a Socket.IO v4 server for Dart, and it is the way to do realtime in Dox.

The official clients connect to it with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package. It has acks, rooms, namespaces, binary data and long-polling.

In a Dox app, Socket.IO runs on the same port as your HTTP routes, at `/socket.io/`. It can also run on its own, see [Without Dox](#without-dox).

## In a Dox app

### Install

The quick way is the CLI:

```bash
dox add socketio
```

It adds the package, the provider, the config and the env key (steps 1, 2, 3 and 5 below). It never overwrites a file, so it is safe to run twice. Then write a namespace (step 4) and connect a client (step 6). Add `--broadcasting` to also turn on [broadcasting](../digging-deeper/broadcasting.md).

### Set it up by hand

If you do not use `dox add socketio`, do all the steps below.

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
| `adapter` | `null` | makes one adapter in each isolate, see [Many isolates](#many-isolates) |

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

Use `transports: ['websocket']`, because long-polling does not work with many isolates. See [Many isolates](#many-isolates).

Requests to `/socket.io/` go to Socket.IO before the router, so route middleware does not run for them. To log users in, see [Log in a socket](#log-in-a-socket).

## Namespaces

A namespace is a class, so its dependencies come in through the constructor:

```dart
class ChatNamespace extends NamespaceHandler {
  ChatNamespace(this.messages);

  final MessageService messages;

  @override
  String get path => '/chat';

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

### Namespace middleware

Sometimes you want to check a client before it joins. Add a middleware to the namespace. When it throws a `SocketIoException`, the client gets `connect_error` with the message and the data:

```dart
@override
List<Middleware> get middleware => <Middleware>[checkToken];

void checkToken(Socket socket) {
  if (socket.handshake.auth['token'] != 'secret') {
    throw SocketIoException('unauthorized', data: <String, dynamic>{'reason': 'bad token'});
  }
}
```

Any other error is written to stderr, and the client only gets `{"message": "Internal error"}`. So private text, like SQL, never reaches the client.

## Sending events

### Sending from a controller or a service

`SocketIoProvider.server` is the Socket.IO server of this isolate:

```dart
await SocketIoProvider.server?.of('/chat').to('lobby').emit('news', data);
```

From a queue job or another program, use the [emitter](#emit-from-other-programs).

### Common methods

The API follows the Node.js server. This table shows the few places where Dart is different:

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
| `socket.handshake` | `.headers`, `.query`, `.auth`, `.address`, `.token`, `.cookie(name)`, `.session()` |
| `socket.data` | `socket.data` (a `Map`) |
| `await io.in(r).fetchSockets()` | `await io.to(r).fetchSockets()` (all servers) |
| `await io.timeout(5000).emitWithAck('e', a)` | `await io.timeout(Duration(seconds: 5)).emitWithAck('e', a)` |
| `io.serverSideEmit('e', a)` | `await io.serverSideEmit('e', [a])` |
| `io.on('e', (a, cb) => ...)` (from other servers) | `io.onServerSideEmit('e', (ServerSideEvent e) => ...)`, then `e.data`, `e.ack(x)` |

To send binary data, send a `Uint8List`. It can be anywhere in lists and maps. The `disconnecting` and `disconnect` events give the reason in `event.data`, like `transport close`.

## Log in a socket

Socket.IO gets its requests before the router, so route middleware like session and auth does not run. Use `SocketAuth` as a namespace middleware instead. Your function gets the handshake and returns the user, or `null`:

```dart title="lib/app/socket/chat.namespace.dart"
class ChatNamespace extends NamespaceHandler {
  @override
  String get path => '/chat';

  @override
  List<Middleware> get middleware => <Middleware>[SocketAuth(findUser).handle];

  static Future<User?> findUser(Handshake handshake) async {
    String? token = handshake.token;
    if (token == null) return null;
    return User().where('api_token', token).getFirst();
  }

  @override
  void onConnection(Socket socket) {
    User user = socket.user! as User;
    socket.join('user:${user.id}');
  }
}
```

The client sends the token in `auth`. Browsers can not set headers on a websocket, so use `auth` and not a header:

```js
const socket = io('http://localhost:3000/chat', {
  transports: ['websocket'],
  auth: { token: 'the-user-token' },
});
socket.on('connect_error', (err) => console.log(err.message)); // 'Unauthorized'
```

When the function returns a user, it is kept in `socket.user`. When it returns `null`, the client gets a `connect_error` with the message `Unauthorized`, and `onConnection` does not run.

The handshake gives you these helpers:

- `handshake.token` is `auth.token` from the client, else the `Authorization: Bearer` header.
- `handshake.cookie('name')` reads a cookie and decrypts it with the `APP_KEY`. Use `decrypt: false` for a plain cookie.
- `await handshake.session()` gives the Dox session of the client, from its session cookie.

### With dox_auth

[dox_auth](../security/authentication.md#check-a-login-with-no-request) can check a JWT or the web login session for you:

```dart
static Future<User?> findUser(Handshake handshake) async {
  // an API client or a mobile app sends a JWT
  String? token = handshake.token;
  if (token != null) return Auth(guard: 'api').userFromToken(token);

  // a browser that logged in on a web page sends the session cookie
  Session session = await handshake.session();
  return Auth(guard: 'web').userFromSession(session);
}
```

`userFromToken` runs the same checks as `AuthMiddleware`, so a bad, expired or revoked token gives `null`. `handshake.session()` runs the same checks as `SessionMiddleware`.

The session is read once, when the socket connects. A logout later does not close the socket, so call `socket.disconnect()` yourself if you need that.

!!! warning "Cookie login needs `allowedOrigins`"
    A browser sends its cookies on a websocket from any website. So if you log users in with a cookie, set [`allowedOrigins`](#allowed-origins) to your own sites. Without it, another website can open a socket as your user.

## Many isolates

Dox runs one isolate per CPU core, and each isolate has its own Socket.IO server. A client is connected to one of them.

With many isolates, the provider uses the `IsolateAdapter` by default. It sends each broadcast to the other isolates of the process, so it reaches every client. `socketsJoin`, `fetchSockets`, `serverSideEmit` and broadcast acks work across isolates too. You need no Redis for this.

| Adapter | Reaches |
|---|---|
| `InMemoryAdapter` (one isolate) | the clients of this isolate |
| `IsolateAdapter` (many isolates, the default) | the clients of every isolate of this process |
| `RedisAdapter` | the clients of every isolate of every server |

Clients should connect with websocket only. One websocket stays on one isolate, but long-polling sends many requests that can reach different isolates. Long-polling only works with `totalIsolate: 1`, or with sticky sessions in front of many single-isolate servers.

Add each namespace in the config, so it is added in every isolate. A namespace that only one isolate adds with `io.of('/x')` gets no answer from the others, so `fetchSockets` and `serverSideEmitWithAck` wait 5 seconds and throw.

## Many servers: Redis adapter

If you run more than one server process, or Dox next to Node.js servers, use the Redis adapter. Then a broadcast on one server reaches the clients of all servers.

Add the `ioredis` package:

```bash
dart pub add ioredis
```

Then make the adapter in each isolate with a factory, because a Redis connection can not be sent to another isolate:

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

The subscriber needs its own connection, because a Redis connection in subscribe mode can not run other commands.

The adapter uses the format of `@socket.io/redis-adapter`, so Node.js servers with that adapter can share one Redis with Dox servers. If your Node.js servers use a JSON parser, set `format: RedisFormat.json`.

### Acting on all servers

With the Redis adapter, these methods work on the sockets of all servers:

```dart
// sockets of every server. Sockets of this server are `Socket`s.
List<RemoteSocket> sockets = await io.to('room1').fetchSockets();
for (RemoteSocket socket in sockets) {
  socket.emit('hello', socket.data['name']);
}

await io.to('room1').socketsJoin('room2');
await io.to('banned').disconnectSockets();
```

To get one ack from each client on all servers, set a timeout:

```dart
List<Object?> answers = await io
    .timeout(const Duration(seconds: 5))
    .emitWithAck('ping', 'are you there?');
```

`fetchSockets` throws a `TimeoutException` when a server does not answer within `requestsTimeout` (5 seconds by default).

### Events between servers

Sometimes the servers need to tell each other something, like "reload the config". `serverSideEmit` sends an event to the other servers. Clients do not get it:

```dart
// on every server
io.onServerSideEmit('reload-config', (ServerSideEvent event) {
  reloadConfig(event.data);
  event.ack('done'); // only when the sender waits for an answer
});

// on one server
await io.serverSideEmit('reload-config', <Object?>['v2']);
```

To wait for one answer from each other server, use `serverSideEmitWithAck`. When a server does not answer in time, it throws an `AckTimeoutException`, and its `responses` holds the answers that came back:

```dart
List<Object?> answers = await io.serverSideEmitWithAck('reload-config', <Object?>['v2']);
```

## Emit from other programs

Sometimes you want to send an event from a queue worker, a cron job or a service in another language. An emitter does this without a Socket.IO server. It writes to Redis, and every server with the Redis adapter sends the event to its clients:

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

The emitter does not wait for an answer, so it can not know if a client got the event.

The emitters of other languages use the same format, so they work too. For example, Node.js with [`@socket.io/redis-emitter`](https://www.npmjs.com/package/@socket.io/redis-emitter):

```js
import { Emitter } from '@socket.io/redis-emitter';
import { createClient } from 'redis';

const redis = createClient({ url: 'redis://127.0.0.1:6379' });
await redis.connect();

const emitter = new Emitter(redis);
emitter.to('room1').emit('news', { title: 'hello' });
emitter.of('/chat').emit('notice', 'for everyone in /chat');
```

## Broadcasting

To send events to public, private and presence channels, see [Broadcasting](../digging-deeper/broadcasting.md).

## Options

Pass `ServerOptions` as `options` to `SocketIoConfig` in a Dox app, or to `SocketIoServer` without Dox:

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
| `maxAttachments` | `10` | the most binary parts in one packet |
| `transports` | `['polling', 'websocket']` | allowed transports |
| `allowUpgrades` | `true` | let polling clients move to websocket |
| `cors` | `null` | CORS headers for polling requests. With a list of origins, it also checks the origin of websockets |
| `allowedOrigins` | `null` | the sites that may connect, see [Allowed origins](#allowed-origins) |
| `allowRequest` | `null` | accepts or refuses each request, see [Allow requests and limit sessions](#allow-requests-and-limit-sessions) |
| `maxSessions` | `null` | the most open sessions per isolate. Set it in production |
| `maxAttachmentBytes` | `null` | the most bytes of all binary parts of one packet. A bigger packet closes the client |
| `maxAuthSize` | `null` | the most bytes of the `auth` payload of a connect. A bigger one gets `connect_error` (`auth payload too large`) |
| `maxWriteBufferSize` | `null` | the most bytes kept for a client that does not read, like a polling client that stopped. Above it, the session closes |
| `ackTimeout` | `null` | the default timeout of `emitWithAck`. With `null`, it waits until the client answers or leaves |

### Waiting for acks

`socket.waitingAcks` is the number of acks a socket still waits for. Use it to see a client that never answers:

```dart
int waiting = socket.waitingAcks;
```

### Allowed origins

`allowedOrigins` says which websites may open a socket. You should set it when you log users in with cookies:

```dart
ServerOptions(allowedOrigins: <String>['https://app.example.com']);
```

- `null` (the default): no extra check. Dox logs a warning at start.
- `[]`: only pages of the same host can connect.
- A list of sites: the same host and those sites can connect.
- `['*']`: every site can connect.

Other sites get 403. A client with no `Origin` header (not a browser) is always allowed.

### Allow requests and limit sessions

`allowRequest` runs for every handshake and every websocket upgrade. It gets an `EngineRequest` with the headers, query and address, and returns `true` or `false`. `maxSessions` is the most open sessions:

```dart title="lib/config/socketio.dart"
SocketIoConfig socketIoConfig = SocketIoConfig(
  options: ServerOptions(
    allowRequest: (EngineRequest req) => req.query['key'] == 'secret',
    maxSessions: 10000,
  ),
);
```

When `allowRequest` gives `false` or throws, the client gets `403`. At the limit, a new handshake gets `503` and open sessions keep working. The count is per isolate, so with 4 isolates the app allows 4 times `maxSessions`. Without `maxSessions`, every GET request makes a session that lives about 45 seconds, so Dox logs one warning at start.

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

- `io.listen(port)` starts a native server on its own port. Run it in its own small program, like `bin/socket.dart`, behind the same proxy as the HTTP server.
- `io.attach(httpServer)` uses a server you already have: a `NativeHttpServer` or a `dart:io` one.
- In your own server, call `io.handle(request)` when `io.matches(request)` is true.
- `io.on('connection', (Socket socket) {...})` handles the default namespace `/` with no class.
- `io.use(SocketAuth(findUser).handle)` logs users in on the default namespace.

To use the Redis adapter, pass it to the server:

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
SocketIoServer io = SocketIoServer(
  adapter: RedisAdapter(subscriber: redis.duplicate(), publisher: redis),
);
```

## Details

- With no provider, or with `enabled: false`, there is no extra work per request.
- Need a plain WebSocket with no Socket.IO protocol? `Route.websocket(path, handler)` in `dox_core` gives you the raw socket.
- Dox logs a hint at startup when it runs many isolates and polling is allowed.
- A client that a middleware refuses is closed after `connectTimeout`, unless it joins another namespace.
- `socket.user` stays on this server. `fetchSockets()` on other servers does not get it.
- `SocketAuth(findUser, message: '...')` changes the `Unauthorized` message.
- `handshake.session()` uses `AppConfig.session`. Pass another `SessionConfig` like `handshake.session(config)`. The session is read only, so changes are not saved. It prints a warning once when `allowedOrigins` is `null` or has `'*'`.
- With `userCacheTtl` on in `dox_auth`, a deleted or banned user can still connect until the cache time ends, unless `forgetUser` runs.
- With the `cookie` session driver, an old copy of the session cookie still works after logout until the `lifetime` ends. Use the `cache` driver if a logout must stop old cookies.
- `cors` with `*` in `origins`, or `cors: null`, allows websockets from any origin. `*` with `credentials: true` throws an `ArgumentError`.
- Websocket compression is off. A message bigger than `maxHttpBufferSize` closes with code 1009. On a plain `dart:io` server, the whole message is read before the size check, so also set a size limit in your proxy.
- A packet with more than `maxAttachments` binary parts closes that client.
- `allowRequest` does not run again for the polling requests of an open session. A client that leaves while it runs still holds a `maxSessions` slot until the ping timeout. A browser client only sees a connect error, not the `403` or `503` body.
- The Redis adapter reads msgpack and JSON, and writes msgpack. Long-polling with it needs sticky sessions too.
- The emitter `key` must be the same as the adapter `key`. Both default to `socket.io`. Binary data (`Uint8List`, or `Buffer` in Node.js) arrives as binary.

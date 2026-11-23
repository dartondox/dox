---
icon: lucide/radio-tower
---

# Socket.IO

`dox_socketio` is a Socket.IO v4 server for Dart, and it is the way to do realtime in Dox.

The official clients connect to it with no changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client` package. It has acks, rooms, namespaces, binary data and long-polling. In a Dox app, it runs on the same port as your HTTP routes, at `/socket.io/`. For a plain WebSocket with no Socket.IO protocol, use `Route.websocket` of [routing](../the-basic/routing.md#websocket-routes).

## Setup

### Install

The quick way is the CLI. It adds the package, the provider, the config and the env key (steps 1, 2, 3 and 5 below). It never overwrites a file:

```bash
dox add socketio
```

Then write a namespace (step 4) and connect a client (step 6). Add `--broadcasting` to also turn on [broadcasting](../digging-deeper/broadcasting.md). Without the CLI, do all the steps.

### 1. Add the package

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

The config lists the namespaces to serve:

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
| `enabled` | true | serve Socket.IO at `options.path` |
| `options` | `ServerOptions()` | see [Options](#options) |
| `namespaces` | `[]` | `NamespaceHandler` classes to register |
| `adapter` | none | makes one adapter in each isolate, see [Many isolates](#many-isolates) |

### 4. A namespace

A **namespace** handles the events of one path, like `/chat`:

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
    // everyone in lobby but me
    event.socket.to('lobby').emit('message', event.data);
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

Use `transports: ['websocket']`, because long-polling does not work with many isolates. See [Many isolates](#many-isolates):

```js
import { io } from 'socket.io-client';

const socket = io('http://localhost:3000/chat', { transports: ['websocket'] });
socket.on('welcome', (data) => console.log(data.id));
socket.emit('message', 'hi', (answer) => console.log(answer)); // 'sent'
```

Requests to `/socket.io/` go to Socket.IO before the router, so route middleware does not run for them. To log users in, see [Log in a socket](#log-in-a-socket).

### Options

Give `ServerOptions` as `options` to `SocketIoConfig`, or to `SocketIoServer` without Dox:

```dart
SocketIoServer(
  options: ServerOptions(
    path: '/socket.io/',
    pingInterval: Duration(seconds: 25),
    pingTimeout: Duration(seconds: 20),
    maxHttpBufferSize: 1000000,
    transports: <String>['polling', 'websocket'],
    cors: CorsOptions(
        origins: <String>['https://my.app'], credentials: true),
  ),
);
```

| Option | Default | What it does |
| --- | --- | --- |
| `path` | `/socket.io/` | the URL path |
| `pingInterval` | 25 s | how often the server sends a ping |
| `pingTimeout` | 20 s | how long to wait for the pong before the client is gone |
| `upgradeTimeout` | 10 s | how long an upgrade from polling to websocket can take |
| `connectTimeout` | 45 s | how long the client has to join a namespace |
| `maxHttpBufferSize` | 1,000,000 bytes | the biggest message. A bigger websocket message closes the connection with code 1009 |
| `maxAttachments` | `10` | the most binary parts in one packet. More closes the client |
| `transports` | `['polling', 'websocket']` | allowed transports |
| `allowUpgrades` | true | let polling clients move to websocket |
| `cors` | none | CORS headers for polling requests. With a list of origins, it also checks the origin of websockets |
| `allowedOrigins` | none | the sites that can connect, see [Allowed origins](#allowed-origins) |
| `allowRequest` | none | accepts or refuses each request, see [Allow requests and limit sessions](#allow-requests-and-limit-sessions) |
| `maxSessions` | none | the most open sessions per isolate. Set it in production |
| `maxAttachmentBytes` | none | the most bytes of all binary parts of one packet. A bigger packet closes the client |
| `maxAuthSize` | none | the most bytes of the `auth` payload. A bigger one gets `connect_error` (`auth payload too large`) |
| `maxWriteBufferSize` | none | the most bytes kept for a client that does not read. Above it, the session closes |
| `ackTimeout` | none | the default timeout of `emitWithAck`. With none, it waits until the client answers or leaves |

On a plain `dart:io` server, the full message is read before the size check, so also set a size limit in your proxy.

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

A middleware checks a client before it joins. When it throws a `SocketIoException`, the client gets `connect_error` with the message and the data:

```dart
@override
List<Middleware> get middleware => <Middleware>[checkToken];

void checkToken(Socket socket) {
  if (socket.handshake.auth['token'] != 'secret') {
    throw SocketIoException('unauthorized',
        data: <String, dynamic>{'reason': 'bad token'});
  }
}
```

Any other error goes to stderr, and the client gets only `{"message": "Internal error"}`.

## Sending events

### Sending from a controller or a service

`SocketIoProvider.server` is the Socket.IO server of this isolate:

```dart
await SocketIoProvider.server?.of('/chat').to('lobby').emit('news', data);
```

From a queue job or another program, use the [emitter](#emit-from-other-programs).

### Common methods

The API follows the Node.js server. This table shows where Dart is different:

| Node.js | Dart |
| --- | --- |
| `socket.on('e', (a, cb) => ...)` | `socket.on('e', (SocketEvent e) => ...)`, then `e.data`, `e.args`, `e.ack(x)` |
| `socket.emit('e', a, b)` | `socket.emit('e', a)` or `socket.emitArgs('e', [a, b])` |
| `await socket.timeout(5000).emitWithAck('e', a)` | `await socket.emitWithAck('e', a, timeout: Duration(seconds: 5))` |
| `socket.join(r)`, `socket.leave(r)` | the same |
| `socket.to(r).emit(...)`, `socket.except(r)` | the same |
| `socket.broadcast.emit(...)` | the same |
| `io.to(r).except(x).emit(...)` | the same |
| `io.of('/chat')`, `io.use(fn)` | the same |
| `io.local.emit(...)` | the same: only sockets of this server |
| `socket.handshake` | `.headers`, `.query`, `.auth`, `.address`, `.url`, `.secure`, `.time`, `.token`, `.cookie(name)`, `.session()` |
| `socket.data` | `socket.data` (a map). Keep it JSON, because other servers get a copy |
| `await io.in(r).fetchSockets()` | `await io.to(r).fetchSockets()` (all servers) |
| `await io.timeout(5000).emitWithAck('e', a)` | `await io.timeout(Duration(seconds: 5)).emitWithAck('e', a)` |
| `io.serverSideEmit('e', a)` | `await io.serverSideEmit('e', [a])` |
| `io.on('e', (a, cb) => ...)` (from other servers) | `io.onServerSideEmit('e', (ServerSideEvent e) => ...)`, then `e.data`, `e.ack(x)` |

To send binary data, send a `Uint8List`. It can be anywhere in lists and maps. An event with many values uses `emitArgs`, `emitArgsWithAck` and `e.ackArgs([a, b])`. `e.hasAck` is true when the client waits for an answer.

### The state of a socket

```dart
socket.connected;   // true while connected
socket.transport;   // 'polling' or 'websocket'
socket.rooms;       // the rooms of the socket
socket.waitingAcks; // acks it still waits for
```

To stop a handler, call `socket.off('message', onMessage)`. With no handler, all handlers of the event go. `nsp.offServerSideEmit` does the same for server events.

### Leaving

The `disconnecting` and `disconnect` events give the reason in `event.data`, like `transport close`. To close a socket from the server, call `disconnect`. `disconnect(true)` also closes the connection under it:

```dart
socket.on('disconnect', (SocketEvent e) => print(e.data));
socket.disconnect();
```

## Log in a socket

Route middleware, like session and auth, does not run for Socket.IO. Use `SocketAuth` as a namespace middleware. Your function gets the handshake and returns the user, or null:

```dart title="lib/app/socket/chat.namespace.dart"
class ChatNamespace extends NamespaceHandler {
  @override
  String get path => '/chat';

  @override
  List<Middleware> get middleware =>
      <Middleware>[SocketAuth(findUser).handle];

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

The client sends the token in `auth`, because browsers can not set headers on a websocket:

```js
const socket = io('http://localhost:3000/chat', {
  transports: ['websocket'],
  auth: { token: 'the-user-token' },
});
socket.on('connect_error', (err) => console.log(err.message)); // 'Unauthorized'
```

A returned user is kept in `socket.user`, on this server only. When the function returns null, the client gets `connect_error` with the message `Unauthorized`, and `onConnection` does not run. `SocketAuth(findUser, message: '...')` changes the message.

The handshake has these helpers:

- `handshake.token` is `auth.token` from the client, else the `Authorization: Bearer` header.
- `handshake.cookie('name')` reads a cookie and decrypts it with `APP_KEY`. Use `decrypt: false` for a plain cookie.
- `await handshake.session()` gives the Dox session of the client. It uses `AppConfig.session`, or the `SessionConfig` you give. Changes are not saved.

### With dox_auth

[dox_auth](../security/authentication.md#check-a-login-with-no-request) can check a JWT or the web login session:

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

A bad, expired or revoked token gives null. The session is read one time, when the socket connects, so call `socket.disconnect()` yourself after a logout. With `userCacheTtl` in `dox_auth`, a banned user can connect until the cache time ends, unless `forgetUser` runs. With the cookie session driver, an old session cookie works after logout until the `lifetime` ends.

!!! warning "Cookie login needs `allowedOrigins`"
    A browser sends its cookies on a websocket from any website. If you log users in with a cookie, set [`allowedOrigins`](#allowed-origins) to your own sites. Else another website can open a socket as your user.

## Protecting the server

### Allowed origins

`allowedOrigins` sets the websites that can open a socket. Set it when you log users in with cookies:

```dart
ServerOptions(allowedOrigins: <String>['https://app.example.com']);
```

- None (the default): no extra check. Dox logs a warning at start.
- `[]`: only pages of the same host can connect.
- A list of sites: the same host and those sites can connect.
- `['*']`: every site can connect.

Other sites get 403. A client with no `Origin` header (not a browser) can always connect. `cors` with `*` in `origins`, or no `cors`, allows websockets from any origin. `*` with `credentials: true` throws an `ArgumentError`.

### Allow requests and limit sessions

`allowRequest` runs for every handshake and every websocket upgrade. It gets an `EngineRequest` with the headers, query and address, and returns true or false. `maxSessions` is the most open sessions:

```dart title="lib/config/socketio.dart"
SocketIoConfig socketIoConfig = SocketIoConfig(
  options: ServerOptions(
    allowRequest: (EngineRequest req) => req.query['key'] == 'secret',
    maxSessions: 10000,
  ),
);
```

When `allowRequest` gives false or throws, the client gets 403. At the limit, a new handshake gets 503, and open sessions keep working. The count is per isolate, so with 4 isolates the app allows 4 times `maxSessions`.

!!! warning
    Without `maxSessions`, every GET request makes a session that lives about 45 seconds. Set it in production.

## Many isolates

Dox runs one isolate per CPU core, and each isolate has its own Socket.IO server. With many isolates, the provider uses the `IsolateAdapter`. It sends each broadcast, `socketsJoin`, `fetchSockets`, `serverSideEmit` and broadcast ack to the other isolates of the process:

| Adapter | Reaches |
|---|---|
| `InMemoryAdapter` (one isolate) | the clients of this isolate |
| `IsolateAdapter` (many isolates, the default) | the clients of every isolate of this process |
| `RedisAdapter` | the clients of every isolate of every server |

Clients must connect with websocket only. Long-polling sends many requests that can reach different isolates. It works only with `totalIsolate: 1`, or with sticky sessions in front of many single-isolate servers.

Add each namespace in the config, so every isolate adds it. A namespace that only one isolate adds with `io.of('/x')` gets no answer from the others, so `fetchSockets` and `serverSideEmitWithAck` wait 5 seconds and throw.

## Many servers: Redis adapter

With many server processes, or Dox next to Node.js servers, use the Redis adapter. A broadcast on one server then reaches the clients of all servers. Add the `ioredis` package:

```bash
dart pub add ioredis
```

Make the adapter in each isolate with a factory, because a Redis connection can not go to another isolate:

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
class RedisSocketAdapterFactory extends SocketAdapterFactory {
  const RedisSocketAdapterFactory();

  @override
  Adapter create() {
    // 127.0.0.1:6379. Or Redis(RedisOptions(host: ..., port: ...))
    Redis redis = Redis();
    return RedisAdapter(subscriber: redis.duplicate(), publisher: redis);
  }
}
```

The subscriber needs its own connection, because a connection in subscribe mode can not run other commands.

The adapter uses the format of `@socket.io/redis-adapter`, so Node.js servers with that adapter can share one Redis with Dox. If your Node.js servers use a JSON parser, set `format: RedisFormat.json`. Long-polling with this adapter also needs sticky sessions.

### Acting on all servers

With the Redis adapter, these methods work on the sockets of all servers:

```dart
// sockets of every server. Sockets of this server are `Socket`s.
List<RemoteSocket> sockets = await io.to('room1').fetchSockets();
for (RemoteSocket socket in sockets) {
  socket.emit('hello', socket.data['name']);
}

await io.to('room1').socketsJoin('room2');
await io.to('room2').socketsLeave('room1');
await io.to('banned').disconnectSockets();
```

A `RemoteSocket` also has `join`, `leave` and `disconnect`. `fetchSockets` throws a `TimeoutException` when a server does not answer in `requestsTimeout` (5 seconds by default).

To get one ack from each client on all servers, set a timeout:

```dart
List<Object?> answers = await io
    .timeout(const Duration(seconds: 5))
    .emitWithAck('ping', 'are you there?');
```

### Events between servers

`serverSideEmit` sends an event to the other servers, like "reload the config". Clients do not get it:

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
List<Object?> answers =
    await io.serverSideEmitWithAck('reload-config', <Object?>['v2']);
```

## Emit from other programs

An **emitter** sends an event with no Socket.IO server, for example from a queue worker or a cron job. It writes to Redis, and every server with the Redis adapter sends the event to its clients:

```dart
import 'package:dox_socketio/dox_socketio.dart';
import 'package:ioredis/ioredis.dart';

Future<void> main() async {
  Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
  SocketIoEmitter emitter = SocketIoEmitter(redis);

  // all clients of `/`
  await emitter.emit('news', <String, dynamic>{'title': 'hello'});
  await emitter.to('room1').except('room2').emit('news', 'hi room1');
  await emitter.of('/chat').to('vip').emit('notice', 'for vip');

  await emitter.to('room1').socketsJoin('room3');
  await emitter.to('room3').socketsLeave('room1');
  await emitter.to('banned').disconnectSockets();
  await emitter.serverSideEmit('reload-config', <Object?>['v2']);

  await redis.disconnect();
}
```

The emitter does not wait for an answer. Its `key` must be the same as the adapter `key`. Both default to `socket.io`.

The emitters of other languages use the same format. For example, Node.js with [`@socket.io/redis-emitter`](https://www.npmjs.com/package/@socket.io/redis-emitter):

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

## Without Dox

`dox_socketio` also runs with no Dox app:

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
- `io.on('connection', (Socket socket) {...})` handles the default namespace `/` with no class. `io.sockets` is that namespace.
- `io.use(SocketAuth(findUser).handle)` logs users in on the default namespace.
- `await io.close()` disconnects everyone and stops the server.

To use the Redis adapter, give it to the server:

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
SocketIoServer io = SocketIoServer(
  adapter: RedisAdapter(subscriber: redis.duplicate(), publisher: redis),
);
```

## Next steps

- [Broadcasting](../digging-deeper/broadcasting.md): send server events to channels.
- [Authentication](../security/authentication.md): log users in.

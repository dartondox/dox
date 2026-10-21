# dox_socketio

A Socket.IO server for Dart. The official clients can connect to it without
changes: `socket.io-client` (JavaScript v4) and the Dart `socket_io_client`
package.

It speaks Engine.IO protocol v4 and Socket.IO protocol v5. These are the
protocols of Socket.IO v4.

## Quick start

```dart
import 'package:dox_socketio/dox_socketio.dart';

Future<void> main() async {
  SocketIoServer io = SocketIoServer();
  io.on('connection', onConnection);
  await io.listen(3000);
}

void onConnection(Socket socket) {
  socket.emit('welcome', 'hello');
  socket.on('chat', (SocketEvent event) {
    socket.to('lobby').emit('chat', event.data); // everyone in lobby but me
    event.ack('ok'); // answer the client callback
  });
}
```

## Class-based style

Put a namespace in a class. Its dependencies come in through the constructor,
so it works with any DI container.

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
  void onConnection(Socket socket) => socket.on('message', onMessage);

  void onMessage(SocketEvent event) => event.ack(messages.save(event.data));
}

io.register(ChatNamespace(MessageService()));
```

When a middleware throws, the client gets `connect_error` with the message and
data.

## API overview

| Node.js | Dart |
| --- | --- |
| `io.of('/chat')` | `io.of('/chat')` |
| `io.use(fn)` / `nsp.use(fn)` | `io.use(fn)` / `nsp.use(fn)` |
| `io.on('connection', fn)` | `io.on('connection', fn)` |
| `socket.on('e', (a, cb) => ...)` | `socket.on('e', (SocketEvent e) => ...)`, `e.data`, `e.args`, `e.ack(x)` |
| `socket.emit('e', a, b)` | `socket.emit('e', a)` or `socket.emitArgs('e', [a, b])` |
| `await socket.timeout(5000).emitWithAck('e', a)` | `await socket.emitWithAck('e', a, timeout: Duration(seconds: 5))` |
| `socket.join(r)` / `socket.leave(r)` | `socket.join(r)` / `socket.leave(r)` |
| `socket.to(r).emit(...)` | `socket.to(r).emit(...)` |
| `socket.broadcast.emit(...)` | `socket.broadcast.emit(...)` |
| `io.to(r).except(x).emit(...)` | `io.to(r).except(x).emit(...)` |
| `io.local.emit(...)` | `io.local.emit(...)` |
| `socket.handshake` | `socket.handshake.headers`, `.query`, `.auth`, `.address` |
| `socket.data` | `socket.data` (a `Map`) |
| `socket.disconnect(true)` | `socket.disconnect(true)` |
| `io.in(r).fetchSockets()` | `io.to(r).fetchSockets()` (this server only) |

Events `disconnecting` and `disconnect` give the reason in `event.data`, like
`transport close`, `ping timeout` or `client namespace disconnect`.

Binary data: send a `Uint8List`. It can be anywhere inside lists and maps.

## Mounting

- Standalone: `await io.listen(3000)`. Or `io.attach(httpServer)`.
- Inside your own `dart:io` server: send the request to `io.handle(request)`
  when `io.matches(request)` is true. The path is `/socket.io/` by default.

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

## Many servers: Redis adapter

Use the Redis adapter when you run more than one server process. A broadcast
on one server then reaches the clients of all servers.

```dart
Redis sub = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
SocketIoServer io = SocketIoServer(
  adapter: RedisAdapter(subscriber: sub, publisher: sub.duplicate()),
);
```

The messages use the format of `@socket.io/redis-adapter`. A Node.js server
can share broadcasts with a Dart server when it uses a JSON parser:

```js
createAdapter(pub, sub, { parser: { encode: JSON.stringify, decode: JSON.parse } })
```

The Dart adapter listens with PSUBSCRIBE, so it also gets the room channels
that Node.js uses when it broadcasts to exactly one room.

Limits: `fetchSockets`, `socketsJoin` and
broadcast acks only work on the local server.

HTTP long-polling needs sticky sessions when you run many servers behind one
port. Use `transports: ['websocket']` on the client if you can not have them.

## Tests

```sh
dart test
```

- The interop tests run the real `socket.io-client` with Node.js. They run
  `npm ci` in `test/interop` the first time. They skip when Node.js is missing.
- The Redis tests read `REDIS_HOST` and `REDIS_PORT` (default `127.0.0.1:6379`).
  They skip when Redis is not reachable.

---
date:
  created: 2026-11-09
authors:
  - dox
categories:
  - Guides
tags:
  - socket.io
  - realtime
  - tutorial
slug: live-updates-with-socketio
---

# Live updates with Socket.IO in Dox

This post shows how to add live updates to a Dox app with Socket.IO.
When one user changes data, the screens of the other users change too, with no refresh.

<!-- more -->

The example is a team app. Many people work in one project.
When one member adds a task, the other members should see it at once, with no refresh.

`dox_socketio` is a Socket.IO v4 server.
The official `socket.io-client` connects to it with no changes.
It runs on the same port as your HTTP routes, at `/socket.io/`.

## The plan

- Each user signs in to the socket with the same token the app already uses for the API.
- Each socket joins a room for its user: `user:<id>`.
- After a write, the server sends a small `changed` event to the users who can see that data.
- The event holds only a topic, like `tasks`. It never holds the data.
- The app gets the event and loads that data again through the normal API.

Why no data in the event?
The API already checks who may see what.
If the event only says "tasks changed", those checks stay in one place.
A bug in the socket code can not leak data.

## 1. Install

```bash
dart pub add dox_socketio
```

```bash
npm install socket.io-client
```

## 2. The provider

The provider starts Socket.IO in every isolate.
Make the file `lib/providers/socket_io_provider.dart`.
It must be in `lib/providers/`, so the generated container finds it:

```dart title="lib/providers/socket_io_provider.dart"
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/config/socketio.dart';

class AppSocketIoProvider extends SocketIoProvider {
  AppSocketIoProvider() : super(socketIoConfig);
}
```

## 3. The config

Make the file `lib/config/socketio.dart`:

```dart title="lib/config/socketio.dart"
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/app/socket/live.namespace.dart';
import 'package:my_app/config/settings.dart';

SocketIoConfig socketIoConfig = SocketIoConfig(
  options: ServerOptions(
    transports: const <String>['websocket'],
    allowedOrigins: <String>[settings.appUrl, ...settings.frontendUrls],
  ),
  namespaces: <NamespaceHandler>[LiveNamespace()],
);
```

Two settings matter here:

- `transports: ['websocket']`. Dox runs one isolate per CPU core. One websocket stays on one isolate. Long-polling sends many HTTP requests, and they can reach different isolates. So allow websocket only.
- `allowedOrigins`. Only your own pages may open a socket. Other websites get 403.

## 4. Sign in the socket

Socket.IO gets its requests before the router, so your route auth middleware does not run.
Use `SocketAuth` as a namespace middleware instead.
Your function gets the handshake and returns the user, or `null`.

Make the file `lib/app/socket/live.namespace.dart`:

```dart title="lib/app/socket/live.namespace.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/app/models/user.model.dart';
import 'package:my_app/app/services/live.service.dart';

class LiveNamespace extends NamespaceHandler {
  @override
  String get path => '/';

  @override
  List<Middleware> get middleware => <Middleware>[SocketAuth(findUser).handle];

  /// The same checks as the API auth middleware.
  static Future<User?> findUser(Handshake handshake) async {
    String? token = handshake.token;
    if (token == null || token.isEmpty) return null;
    return Dox().ioc.get<UserService>().findByToken(token);
  }

  @override
  void onConnection(Socket socket) {
    User user = socket.user! as User;
    socket.join(LiveService.roomOf(user.id!));
  }
}
```

- `handshake.token` is `auth.token` from the client.
- With `null`, the client gets a `connect_error` with `Unauthorized`, and `onConnection` does not run.
- The token is checked once, when the socket connects.

`findUser` can check any token your API already uses.
With `dox_auth`, use `Auth(guard: 'api').userFromToken(token)`.
See [Log in a socket](/latest/packages/socketio/#log-in-a-socket).

## 5. Send events after a write

A small service sends the events.
`SocketIoProvider.server` is the Socket.IO server of this isolate.

Make the file `lib/app/services/live.service.dart`:

```dart title="lib/app/services/live.service.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';

@Inject()
class LiveService {
  LiveService(this.projectMembers);

  final ProjectMemberRepository projectMembers;

  static String roomOf(int userId) => 'user:$userId';

  /// Data of [projectId] changed: tell its members.
  Future<void> projectChanged(int projectId, String topic) async {
    try {
      Set<int> users = await projectMembers.userIdsOf(projectId);
      await _emit(users, <String, Object>{'topic': topic, 'projectId': projectId});
    } catch (error) {
      Logger.warn('[live] project $projectId $topic: $error');
    }
  }

  /// Something everyone sees changed, like a notice for all users.
  Future<void> everyoneChanged(String topic) async {
    await SocketIoProvider.server?.emit('changed', <String, Object>{'topic': topic});
  }

  Future<void> _emit(Set<int> users, Map<String, Object> data) async {
    SocketIoServer? io = SocketIoProvider.server;
    if (io == null || users.isEmpty) return;
    BroadcastOperator to = io.to(roomOf(users.first));
    for (int user in users.skip(1)) {
      to = to.to(roomOf(user));
    }
    await to.emit('changed', data);
  }
}
```

Then call it from your services, after the write.
For example, in `lib/app/services/task.service.dart`:

```dart title="lib/app/services/task.service.dart"
Future<Task> create(int projectId, Map<String, dynamic> data) async {
  Task task = await tasks.create(projectId, data);
  await live.projectChanged(projectId, 'tasks');
  return task;
}
```

- A failed send is logged. It never fails the write.
- `to(a).to(b)` sends one event to many rooms. A user in two rooms gets it once.
- Put the calls in services, not controllers. Then queue jobs, scheduled jobs and other entry points send events too.

## 6. Many isolates, no Redis

Each isolate has its own Socket.IO server, and a client is connected to one of them.
So an event sent from isolate 1 must also reach clients on isolate 3.

You do not need to do anything for this.
With many isolates, the provider uses the `IsolateAdapter`.
It sends each broadcast to the other isolates of the process.
You need no Redis.

With more than one server process, use the [Redis adapter](/latest/packages/socketio/#many-servers-redis-adapter).

## 7. The client

In the frontend, make the file `src/lib/live.ts`:

```ts title="src/lib/live.ts"
import { io, type Socket } from 'socket.io-client'

let socket: Socket | null = null
let connectedOnce = false

/** Call after sign-in. */
export function startLive() {
  if (socket) return
  socket = io(window.location.origin, {
    transports: ['websocket'],
    auth: sendToken,
  })
  socket.on('connect', onConnect)
  socket.on('changed', onChanged)
}

/** Call on sign-out. */
export function stopLive() {
  socket?.disconnect()
  socket = null
  connectedOnce = false
}

/** A fresh token on every connect and reconnect. */
async function sendToken(done: (data: object) => void) {
  done({ token: (await getToken()) ?? '' })
}

/** Events sent while we were offline are lost, so a reconnect loads all. */
function onConnect() {
  if (connectedOnce) reloadAll()
  connectedOnce = true
}

function onChanged(change: { topic: string; projectId?: number }) {
  if (change.topic === 'tasks' && change.projectId === activeProjectId()) {
    reloadTasks()
  }
  // ... one line per topic
}
```

Three things to note:

- `auth` is a function, not an object. The client calls it on each reconnect, so a token that expired is replaced.
- Socket.IO does not keep events for a client that is offline. On reconnect, load everything again.
- `transports: ['websocket']` must match the server.

## 8. The dev proxy

If your frontend dev server proxies the API, add `/socket.io` with websocket support.
With Vite, add it to `vite.config.ts`:

```ts title="vite.config.ts"
server: {
  proxy: {
    '/api': 'http://localhost:3000',
    '/socket.io': { target: 'http://localhost:3000', ws: true },
  },
},
```

Without `ws: true`, the socket can not connect in dev.

## 9. Test it

You can test it with the real client, from Dart, with the `socket_io_client` package.
A good set of tests:

- A bad token is refused.
- A new task reaches the project members, and not a user outside the project.
- A user who is not signed in gets no events.

## What you get

- Live screens for every user, with no refresh.
- No data in the events, so the API access checks stay in one place.
- It works on every isolate, with no Redis.
- The standard `socket.io-client` works with no changes.

Full docs: [Socket.IO](/latest/packages/socketio/)

---
icon: lucide/radio-tower
---

# Broadcasting

Broadcasting sends server events to browsers and apps over Socket.IO, on public, private and presence channels.

A client subscribes to a channel. Your code sends an event to the channel. Every client in it gets the event.
Use it for live pages, like order status, a chat or a list of who is online.

It is part of the `dox_socketio` package. It is off by default.

## Turn it on

Do the [Socket.IO setup](../packages/socketio.md#in-a-dox-app) first. Then turn on broadcasting in the config:

```dart title="lib/config/socketio.dart"
SocketIoConfig socketIoConfig = SocketIoConfig(
  broadcasting: true,
  namespaces: <NamespaceHandler>[ChatNamespace()],
);
```

Channel rules are kept per isolate. So add them where every isolate runs them. A provider is a good place:

```dart title="lib/providers/broadcast_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/app/models/user/user.model.dart';

class BroadcastProvider extends DoxProvider {
  @override
  void setup() {
    Broadcast.channel('orders.{id}', (Object? user, String id) {
      return (user as User).id.toString() == id;
    });
  }
}
```

Run `dart run build_runner build`, so the generated container finds the provider. Without it, no rule is added, and every private subscribe gets `Forbidden`.

A client that is not logged in as a socket gets a token from the auth route. Add the route with your own auth middleware:

```dart title="lib/routes/api.dart"
@override
void register() {
  Broadcast.routes(middleware: <dynamic>[AuthMiddleware()]); // POST /api/broadcasting/auth
}
```

The prefix of the router is added to the path. This router has the prefix `api`, so the path is `/api/broadcasting/auth`.

The route runs the channel rule with `req.auth` and answers `{"auth": "<token>"}`, or `403`.
Pass `path:` to use another path.
The token is signed with a key made from `APP_KEY`. It works for one socket, one channel and one minute.

## Channels

| Channel | Name | Who can subscribe |
| --- | --- | --- |
| `Channel('news')` | `news` | any client |
| `PrivateChannel('orders.5')` | `private-orders.5` | a client that passes the rule |
| `PresenceChannel('chat.lobby')` | `presence-chat.lobby` | a client that passes the rule. Members see each other |

`Broadcast.channel(pattern, rule)` adds a rule for private and presence channels.
The pattern has no `private-` or `presence-` prefix.
A `{name}` part matches any text with no dot.
The rule gets the user, then one string for each `{name}` part. It can be async.

- A private rule gives `true` to allow. Anything else refuses.
- A presence rule gives a map with the member info, with an `id`. Anything else refuses.
- A rule that throws refuses, and the error goes to stderr.

```dart
Broadcast.channel('chat.{room}', (Object? user, String room) {
  User u = user as User;
  return <String, Object?>{'id': u.id, 'name': u.name};
});
```

One rule serves both kinds. `orders.{id}` checks `private-orders.1` and `presence-orders.1`.
When more than one pattern matches, the first one added wins.

## Send an event

An event is a class with the `ShouldBroadcast` mixin:

```dart
class OrderShipped with ShouldBroadcast {
  OrderShipped(this.order);
  final Order order;

  @override
  List<Channel> broadcastOn() => <Channel>[PrivateChannel('orders.${order.id}')];

  @override
  String broadcastAs() => 'order.shipped'; // default: the class name

  @override
  Map<String, Object?> broadcastWith() => <String, Object?>{'id': order.id};
}
```

- `broadcastOn` gives the channels. It is required.
- `broadcastAs` gives the event name. The default is the class name.
- `broadcastWith` gives the payload. It must be JSON. The default is an empty map.

Send it:

```dart
await broadcast(OrderShipped(order));
await Broadcast.event(OrderShipped(order)); // the same
```

`toOthers` skips one socket, for example the one that made the change.
The client sends its socket id in the `X-Socket-ID` header. `Broadcast.socketId(req)` reads it:

```dart
await Broadcast.event(OrderShipped(order), toOthers: Broadcast.socketId(req));
```

Without a Socket.IO server in the process, and with no [emitter](#send-from-a-process-with-no-socketio-server), `Broadcast.event` throws a `StateError`.

## The client

Use `socket.io-client`. A public channel needs no token.
A subscription belongs to one socket. After a reconnect, the client has a new socket and is in no channel.
So subscribe inside the `connect` handler. It runs again after each reconnect.

```js
import { io } from 'socket.io-client';

const socket = io('https://app.example.com', { transports: ['websocket'] });

socket.on('order.shipped', (channel, payload) => console.log(channel, payload));
socket.on('connect', () => {
  socket.emit('subscribe', { channel: 'news' }, (ack) => console.log(ack));
});
```

For a private or presence channel, get a token first, then send it in `subscribe`.
A token works for one socket id only. So ask for a new token in the `connect` handler, after each reconnect too:

```js
socket.on('connect', async () => {
  const res = await fetch('/api/broadcasting/auth', {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${apiToken}` },
    body: JSON.stringify({ socket_id: socket.id, channel_name: 'private-orders.5' }),
  });
  const { auth } = await res.json();
  socket.emit('subscribe', { channel: 'private-orders.5', auth }, (ack) => console.log(ack));
});
```

A socket that is already logged in with [`SocketAuth`](../packages/socketio.md#log-in-a-socket) needs no token. The server runs the rule with `socket.user`.

- The ack of `subscribe` and `unsubscribe` is `{ok: true}` or `{ok: false, error}`.
- Events arrive as `(channel, payload)`, under the name from `broadcastAs`.
- `socket.emit('unsubscribe', { channel }, ack)` leaves the channel.

| `error` | Why |
| --- | --- |
| `channel is missing` | no channel name |
| `channel name is too long` | over `Broadcast.maxChannelLength` |
| `too many channels` | over `Broadcast.maxChannelsPerSocket` |
| `already subscribing` | the same channel is still being checked |
| `Forbidden` | the rule refused, or the token is missing, wrong or old |
| `unsubscribed` | an `unsubscribe` came while it was subscribing |
| `presence is not available` | another server did not answer in time |

Send the token as a string in `auth`, like above. An object of headers is refused with `Forbidden`.

## Presence

A presence channel tells its members who else is in it. The client gets three events:

| Event | Arguments | When |
| --- | --- | --- |
| `presence:subscribed` | `(channel, members)` | to the new socket, with all members |
| `presence:joining` | `(channel, member)` | to the others, when a member joins |
| `presence:leaving` | `(channel, member)` | to the others, when a member leaves |

A member is `{user_id, user_info}`. `user_info` is the map from the rule.

```js
socket.on('presence:subscribed', (channel, members) => console.log(members));
socket.on('presence:joining', (channel, member) => console.log(member.user_info.name));
socket.on('presence:leaving', (channel, member) => console.log(member.user_id));
```

A user with two sockets is one member. `presence:joining` is sent for the first socket, and `presence:leaving` for the last one.
The member list covers all isolates and servers that share the adapter.

## Queued broadcasting

A queued broadcast goes through your [queue](queue.md). The request does not wait for it.

`dox_socketio` does not depend on `dox_queue`. You connect them with a hook and a small job. Follow these steps.

### 1. Mark the event

Use `ShouldBroadcastQueued` in place of `ShouldBroadcast`:

```dart
class OrderShipped with ShouldBroadcastQueued {
  OrderShipped(this.order);
  final Order order;

  @override
  List<Channel> broadcastOn() => <Channel>[PrivateChannel('orders.${order.id}')];

  @override
  Map<String, Object?> broadcastWith() => <String, Object?>{'id': order.id};
}

await broadcast(OrderShipped(order)); // goes to the queue
```

### 2. Write the job

The worker runs this job. It sends the saved broadcast to the clients:

```dart title="lib/app/jobs/broadcast.job.dart"
import 'package:dox_queue/dox_queue.dart';
import 'package:dox_socketio/dox_socketio.dart';

/// Sends one queued broadcast to the clients.
@Job()
class BroadcastJob extends DoxJob {
  BroadcastJob({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Future<void> handle() async {
    await Broadcast.deliver(BroadcastPayload.fromJson(payload));
  }
}
```

Run `dart run build_runner build`. It adds the job to `lib/generated/jobs.g.dart`. The queue needs this file to save and load the job. See [how the queue works](queue.md#how-it-works).
Make sure `jobs: jobRegistry` is set in your [queue config](queue.md#1-config).

### 3. Set the hook

The hook gets the broadcast and puts it on the queue. Add it to the `setup()` of the `BroadcastProvider` from [Turn it on](#turn-it-on), next to the channel rules. Keep the rules:

```dart title="lib/providers/broadcast_provider.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_queue/dox_queue.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:my_app/app/models/user/user.model.dart';

import '../app/jobs/broadcast.job.dart';

class BroadcastProvider extends DoxProvider {
  @override
  void setup() {
    Broadcast.channel('orders.{id}', (Object? user, String id) {
      return (user as User).id.toString() == id;
    });

    // puts ShouldBroadcastQueued events on the queue
    Broadcast.useQueue(queueBroadcast);
  }

  static Future<void> queueBroadcast(BroadcastPayload payload) async {
    await Queue.dispatch(BroadcastJob(payload: payload.toJson()));
  }
}
```

The payload is JSON: `{channels, event, data, except}`. `except` is the `toOthers` socket id.

### 4. Use the Redis adapter

The worker is its own process. It starts your providers, so it gets its own Socket.IO server. That server has no clients.
So the worker must reach the clients of the web server through Redis.

Set the [Redis adapter](../packages/socketio.md#many-servers-redis-adapter) in `SocketIoConfig`. The web server and the worker use the same config, so both use the same Redis.
A `Broadcast.emitter` does not help here. The worker has its own Socket.IO server, and `Broadcast.deliver` sends through that server first.

### 5. Run the worker

```bash
dart run bin/queue.dart
```

Deploy the worker together with the web app. See [run the worker](queue.md#run-the-worker).

### Rules

- With no hook set (`Broadcast.useQueue` not called), a `ShouldBroadcastQueued` event is sent at once, like a normal one. So tests and small apps work without a queue.
- Normal `ShouldBroadcast` events never use the hook.
- `Broadcast.deliver` throws a `StateError` when the worker has no way to send. This is when broadcasting is off and there is no `Broadcast.emitter`.
- `deliver` prints a warning once when it sends through an in-memory adapter with no clients. The clients of the web server do not get that broadcast.
- In tests, `Broadcast.fake()` keeps queued events too. Check them with `fake.assertQueued<OrderShipped>()`. `fake.delivered` holds the payloads that `deliver` got.

## Send from a process with no Socket.IO server

A queue worker or a command has no Socket.IO server. Set an emitter, so `Broadcast.event` can send through Redis:

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
Broadcast.emitter = SocketIoEmitter(redis);

await Broadcast.event(OrderShipped(order));
```

The servers must use the [Redis adapter](../packages/socketio.md#many-servers-redis-adapter).
When the emitter is for another namespace than `/`, use `SocketIoEmitter(redis).of('/chat')`.
With no server and no emitter, `Broadcast.event` throws a `StateError`.

To send from a [queue](queue.md) job, use [queued broadcasting](#queued-broadcasting).

## Whisper

A whisper lets a client send an event to the other members of a private or presence channel. A typical use is "is typing".
The server only passes it on.

It is off by default. A whisper lets clients message each other with no code of yours in between. So you choose to allow it:

```dart
SocketIoConfig(broadcasting: true, whisper: true);
```

The client sends `client event` with `{channel, event, data}`. The event name must start with `client-`.
The other sockets in the channel get the event with `(channel, data)`:

```js
socket.emit('client event', {
  channel: 'presence-chat.lobby',
  event: 'client-typing',
  data: { name: 'Alice' },
}, (ack) => console.log(ack)); // the ack is optional

socket.on('client-typing', (channel, data) => console.log(channel, data));
```

- Only a socket that subscribed to the channel can whisper.
- Only private and presence channels allow it. A public channel does not.
- The sender does not get its own whisper. Its other sockets do.
- It works across isolates and servers with the Redis adapter.
- A whisper is dropped when its data is bigger than `Broadcast.maxWhisperSize`. The default is 10 KB of JSON.
- When a whisper is refused, the ack is `{ok: false, error}`. The error is, for example, `not subscribed` or `data is too big`.
- With whisper off, a `client event` is ignored, with no ack.
- The `client-` prefix keeps a whisper apart from server events. Do not give a server event (`broadcastAs`) a name that starts with `client-`.
- The event names and the whisper format follow Laravel Echo. So `channel.whisper('typing', data)` and `listenForWhisper('typing', ...)` use the same names.
- Laravel Echo sends `auth` as an object of headers. This server refuses that. So Echo can not join a private or presence channel on its own. Log the socket in with [`SocketAuth`](../packages/socketio.md#log-in-a-socket), or send your own `subscribe` with the token, as shown in [The client](#the-client). Then whispers work.

## Limits and settings

| Setting | Default | What it does |
| --- | --- | --- |
| `Broadcast.maxChannelLength` | `200` | the longest channel name a client may subscribe to |
| `Broadcast.maxChannelsPerSocket` | `100` | the most channels for one socket |
| `Broadcast.tokenLifetime` | 1 minute | how long a token from the auth route works |
| `Broadcast.presenceTimeout` | 2 seconds | how long a presence join or leave waits for other servers |
| `Broadcast.maxWhisperSize` | 10 KB | the biggest `data` of a [whisper](#whisper), in bytes of JSON |

- It needs `APP_KEY`, to sign the tokens.
- Turn broadcasting on for one namespace only. With two namespaces, both accept `subscribe`, but `Broadcast.event` sends only through the last one.
- A presence `subscribe` is refused when a server does not answer in time. A leave still sends `presence:leaving`.
- Presence joins and leaves of one channel run one after another in each isolate. During a Redis outage, each one waits up to `presenceTimeout`, so keep it short.
- When two sockets of one user join or leave at the same moment on two isolates or servers, `presence:joining` or `presence:leaving` can be missed or sent twice.
- A client cannot send events to the other clients of a channel, unless you turn on [whispers](#whisper).

## Testing

`Broadcast.fake()` keeps the events and sends nothing:

```dart
test('shipping an order broadcasts', () async {
  BroadcastFake fake = Broadcast.fake();

  await shipOrder(order);

  fake.assertBroadcasted<OrderShipped>();
  fake.assertBroadcastedOn<OrderShipped>('private-orders.${order.id}');
  fake.assertBroadcastedTimes<OrderShipped>(1);
});
```

| Method | Passes when |
| --- | --- |
| `assertBroadcasted<T>([test])` | an event of type `T` was sent. With `test`, one of them passes it |
| `assertBroadcastedOn<T>(name)` | `T` was sent on the channel `name`, with its `private-` or `presence-` prefix |
| `assertBroadcastedTimes<T>(n)` | `T` was sent exactly `n` times |
| `assertNotBroadcasted<T>()` | no `T` was sent |
| `assertNothingBroadcasted()` | no event was sent |

A failed assert throws an `AssertionError`.
`fake.eventsOf<T>()` gives the events, and `fake.clear()` forgets them.
`Broadcast.restore()` turns the fake off.
`Broadcast.reset()` forgets the rules, the emitter and the fake. Call it in `tearDown`.

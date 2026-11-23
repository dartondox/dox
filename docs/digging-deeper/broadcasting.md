---
icon: lucide/radio-tower
---

# Broadcasting

Broadcasting sends server events to browsers and apps over Socket.IO, on public, private and presence channels.

A client subscribes to a **channel**. Your code sends an event to the channel, and every client in it gets the event. Broadcasting is part of the `dox_socketio` package. It is off by default.

## Setup

Do the [Socket.IO setup](../packages/socketio.md#setup) first. Then turn on broadcasting in the config:

```dart title="lib/config/socketio.dart"
SocketIoConfig socketIoConfig = SocketIoConfig(
  broadcasting: true,
  namespaces: <NamespaceHandler>[ChatNamespace()],
);
```

Broadcasting works on the `/` namespace. To use another namespace, call `Broadcast.listen(nsp)` with it. `Broadcast.event` sends through the last namespace it got.

### Channel rules

Private and presence channels need a rule for who can join. Each isolate keeps its own rules, so add them in a provider:

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

Run `dart run build_runner build`, so the container finds the provider. Without a rule, every private subscribe gets `Forbidden`. See [Authorizing channels](#authorizing-channels).

### The auth route

A client gets a channel token from the auth route. Add the route with your auth middleware:

```dart title="lib/routes/api.dart"
@override
void register() {
  // POST /api/broadcasting/auth
  Broadcast.routes(middleware: <dynamic>[AuthMiddleware()]);
}
```

The router prefix goes in front of the path. Give `path:` to use another path. The route answers `{"auth": "<token>"}`, or 403 when the rule refuses. The token is signed with a key from `APP_KEY`, and it works for one socket, one channel and one minute.

### Limits

| Setting | Default | What it does |
| --- | --- | --- |
| `Broadcast.maxChannelLength` | 200 | the longest channel name a client can subscribe to |
| `Broadcast.maxChannelsPerSocket` | 100 | the most channels for one socket |
| `Broadcast.tokenLifetime` | 1 minute | how long a token from the auth route works |
| `Broadcast.presenceTimeout` | 2 seconds | how long a presence join or leave waits for other servers |
| `Broadcast.maxWhisperSize` | 10 KB | the biggest `data` of a [client event](#client-events), in bytes of JSON |

## Channel types

| Channel | Name | Who can subscribe |
| --- | --- | --- |
| `Channel('news')` | `news` | any client |
| `PrivateChannel('orders.5')` | `private-orders.5` | a client that passes the rule |
| `PresenceChannel('chat.lobby')` | `presence-chat.lobby` | a client that passes the rule. Members see each other |

## Defining broadcast events

An event is a class with the `ShouldBroadcast` mixin:

```dart
class OrderShipped with ShouldBroadcast {
  OrderShipped(this.order);
  final Order order;

  @override
  List<Channel> broadcastOn() =>
      <Channel>[PrivateChannel('orders.${order.id}')];

  @override
  String broadcastAs() => 'order.shipped'; // default: the class name

  @override
  Map<String, Object?> broadcastWith() =>
      <String, Object?>{'id': order.id};
}
```

`broadcastOn` gives the channels. `broadcastWith` gives the JSON payload, an empty map by default. Do not start an event name with `client-`, because that prefix is for [client events](#client-events).

## Authorizing channels

`Broadcast.channel(pattern, rule)` adds a rule. The pattern has no `private-` or `presence-` prefix, and a `{name}` part matches any text with no dot. The rule gets the user, then one string for each `{name}` part. It can be async.

- A private rule returns true to allow.
- A presence rule returns a map of member info, with an `id`.
- Any other result, or an error, refuses.

This presence rule lets any logged in user join a chat room:

```dart
Broadcast.channel('chat.{room}', (Object? user, String room) {
  User u = user as User;
  return <String, Object?>{'id': u.id, 'name': u.name};
});
```

One rule serves both kinds, so `orders.{id}` checks `private-orders.1` and `presence-orders.1`. When more patterns match, the first rule wins.

### Your own auth endpoint

To write the auth route yourself, run the rule with `Broadcast.authorize`, and make the token with `Broadcast.authToken`:

```dart
Object? result = await Broadcast.authorize(user, 'private-orders.5');
if (result == null) throw ForbiddenHttpException();
String token = Broadcast.authToken(socketId, 'private-orders.5');
```

`authorize` gives null when the rule refuses. For a presence channel, it gives the member map. Give that map as the third argument of `authToken`.

## Broadcasting events

Use `broadcast` to send an event. `Broadcast.event` does the same:

```dart
await broadcast(OrderShipped(order));
await Broadcast.event(OrderShipped(order)); // the same
```

### Only to others

Use `toOthers` to skip the socket of the user who made the change. `Broadcast.socketId(req)` reads the socket id from the `X-Socket-ID` header:

```dart
await Broadcast.event(OrderShipped(order),
    toOthers: Broadcast.socketId(req));
```

## Receiving broadcasts

On the client, use `socket.io-client`. Subscribe in the `connect` handler, because after a reconnect the socket has no channels:

```js
import { io } from 'socket.io-client';

const socket = io('https://app.example.com', { transports: ['websocket'] });

socket.on('order.shipped',
  (channel, payload) => console.log(channel, payload));
socket.on('connect', () => {
  socket.emit('subscribe', { channel: 'news' }, (ack) => console.log(ack));
});
```

Events come as `(channel, payload)`, with the name from `broadcastAs`.

### Private and presence channels

Get a token from the auth route, then send it as a string in `auth`. A token works for one socket id, so get a new one in the `connect` handler:

```js
socket.on('connect', async () => {
  const res = await fetch('/api/broadcasting/auth', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${apiToken}`,
    },
    body: JSON.stringify({
      socket_id: socket.id,
      channel_name: 'private-orders.5',
    }),
  });
  const { auth } = await res.json();
  socket.emit('subscribe', { channel: 'private-orders.5', auth },
    (ack) => console.log(ack));
});
```

A socket logged in with [`SocketAuth`](../packages/socketio.md#log-in-a-socket) needs no token. The rule then gets `socket.user`.

### Leaving a channel

Send `unsubscribe` with the channel name:

```js
socket.emit('unsubscribe', { channel: 'news' }, (ack) => console.log(ack));
```

### Subscribe errors

The ack of `subscribe` and `unsubscribe` is `{ok: true}` or `{ok: false, error}`:

| `error` | Why |
| --- | --- |
| `channel is missing` | no channel name |
| `channel name is too long` | over `Broadcast.maxChannelLength` |
| `too many channels` | over `Broadcast.maxChannelsPerSocket` |
| `already subscribing` | the server still checks the same channel |
| `Forbidden` | the rule refused, or the token is missing, wrong or old |
| `unsubscribed` | an `unsubscribe` came during the subscribe |
| `presence is not available` | another server did not answer in time |

## Presence channels

A presence channel tells its members who else is in it. The client gets three events:

| Event | Arguments | When |
| --- | --- | --- |
| `presence:subscribed` | `(channel, members)` | to the new socket, with all members |
| `presence:joining` | `(channel, member)` | to the others, when a member joins |
| `presence:leaving` | `(channel, member)` | to the others, when a member leaves |

A member is `{user_id, user_info}`, and `user_info` is the map from the rule:

```js
socket.on('presence:subscribed',
  (channel, members) => console.log(members));
socket.on('presence:joining',
  (channel, member) => console.log(member.user_info.name));
socket.on('presence:leaving',
  (channel, member) => console.log(member.user_id));
```

A user with two sockets is one member. The member list covers all isolates and servers that share the adapter.

## Queued broadcasting

A queued broadcast goes through your [queue](queue.md), so the request does not wait. Connect the two packages with a hook and a small job.

### 1. Mark the event

Use `ShouldBroadcastQueued` in place of `ShouldBroadcast`:

```dart
class OrderShipped with ShouldBroadcastQueued {
  OrderShipped(this.order);
  final Order order;

  @override
  List<Channel> broadcastOn() =>
      <Channel>[PrivateChannel('orders.${order.id}')];

  @override
  Map<String, Object?> broadcastWith() =>
      <String, Object?>{'id': order.id};
}

await broadcast(OrderShipped(order)); // goes to the queue
```

### 2. Write the job

The worker runs this job, and it sends the broadcast to the clients:

```dart title="lib/app/jobs/broadcast.job.dart"
import 'package:dox_queue/dox_queue.dart';
import 'package:dox_socketio/dox_socketio.dart';

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

Run `dart run build_runner build` to add the job to the job registry. See [queue setup](queue.md#setup) and [configuration](queue.md#configuration).

### 3. Set the hook

Add the hook to `setup()` of the `BroadcastProvider` from [Channel rules](#channel-rules):

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

With no hook, a `ShouldBroadcastQueued` event is sent at once.

### 4. Use the Redis adapter

The worker is its own process, so it reaches the clients of the web server through Redis. Set the [Redis adapter](../packages/socketio.md#many-servers-redis-adapter) in `SocketIoConfig`. The web server and the worker share this config.

### 5. Run the worker

```bash
dart run bin/queue.dart
```

Deploy the worker with the web app. See [run the worker](queue.md#running-the-worker).

## Broadcasting from other processes

A command has no Socket.IO server. Set an emitter, so `Broadcast.event` sends through Redis:

```dart
Redis redis = Redis(RedisOptions(host: '127.0.0.1', port: 6379));
Broadcast.emitter = SocketIoEmitter(redis);

await Broadcast.event(OrderShipped(order));
```

The servers must use the [Redis adapter](../packages/socketio.md#many-servers-redis-adapter). For a namespace other than `/`, use `SocketIoEmitter(redis).of('/chat')`. With no server and no emitter, `Broadcast.event` throws a StateError.

## Client events

A **client event** (a whisper) goes from one client to the other members of a private or presence channel, like "is typing". The server only passes it on. It is off by default, because clients can then send messages to each other:

```dart
SocketIoConfig(broadcasting: true, whisper: true);
```

The client sends `client event` with `{channel, event, data}`. The event name must start with `client-`. The other sockets in the channel get `(channel, data)`:

```js
socket.emit('client event', {
  channel: 'presence-chat.lobby',
  event: 'client-typing',
  data: { name: 'Alice' },
}, (ack) => console.log(ack)); // the ack is optional

socket.on('client-typing', (channel, data) => console.log(channel, data));
```

Only a subscribed socket can whisper. The sender does not get its own whisper. A refused whisper gets `{ok: false, error}`, like `not subscribed`.

The names match the Echo client. Echo sends `auth` as headers, so log its socket in with [`SocketAuth`](../packages/socketio.md#log-in-a-socket) for private channels.

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
| `assertBroadcastedOn<T>(name)` | `T` was sent on the channel `name`, with its prefix |
| `assertBroadcastedTimes<T>(n)` | `T` was sent `n` times |
| `assertQueued<T>([test])` | `T` was sent as a queued event |
| `assertNotBroadcasted<T>()` | no `T` was sent |
| `assertNothingBroadcasted()` | no event was sent |

`fake.eventsOf<T>()` gives the events, `fake.delivered` gives the payloads of `deliver`, and `fake.clear()` removes them. `Broadcast.restore()` turns the fake off. Call `Broadcast.reset()` in `tearDown` to remove the rules, the emitter and the fake.

## Next steps

- [Socket.IO](../packages/socketio.md): namespaces, rooms and the Redis adapter.
- [Queue](queue.md): run the worker for queued broadcasts.

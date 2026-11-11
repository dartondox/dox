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

A client that is not logged in as a socket gets a token from the auth route. Add the route with your own auth middleware:

```dart title="lib/routes/api.dart"
@override
void register() {
  Broadcast.routes(middleware: <dynamic>[AuthMiddleware()]); // POST /broadcasting/auth
}
```

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

Use `socket.io-client`. A public channel needs no token:

```js
import { io } from 'socket.io-client';

const socket = io('https://app.example.com', { transports: ['websocket'] });

socket.on('order.shipped', (channel, payload) => console.log(channel, payload));
socket.emit('subscribe', { channel: 'news' }, (ack) => console.log(ack));
```

For a private or presence channel, get a token first, then send it in `subscribe`:

```js
socket.on('connect', async () => {
  const res = await fetch('/broadcasting/auth', {
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

The event names are the same as in the Echo Socket.IO connector. The auth is not. Echo sends `auth` as an object with headers. This server wants a token string, so get it yourself and send a small `subscribe` like above.

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

There is no queued broadcasting. To send from a [queue](queue.md) job, call `Broadcast.event` inside the job.

## Limits and settings

| Setting | Default | What it does |
| --- | --- | --- |
| `Broadcast.maxChannelLength` | `200` | the longest channel name a client may subscribe to |
| `Broadcast.maxChannelsPerSocket` | `100` | the most channels for one socket |
| `Broadcast.tokenLifetime` | 1 minute | how long a token from the auth route works |
| `Broadcast.presenceTimeout` | 2 seconds | how long a presence join or leave waits for other servers |

- It needs `APP_KEY`, to sign the tokens.
- Turn broadcasting on for one namespace only. With two namespaces, both accept `subscribe`, but `Broadcast.event` sends only through the last one.
- A presence `subscribe` is refused when a server does not answer in time. A leave still sends `presence:leaving`.
- Presence joins and leaves of one channel run one after another in each isolate. During a Redis outage, each one waits up to `presenceTimeout`, so keep it short.
- When two sockets of one user join or leave at the same moment on two isolates or servers, `presence:joining` or `presence:leaving` can be missed or sent twice.
- A client cannot send events to the other clients of a channel. Only the server sends.

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

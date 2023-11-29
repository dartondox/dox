# WebSocket

WebSocket is a communication protocol that enables real-time, full-duplex, bidirectional data exchange between a client and a server over a single, long-lived connection. It is commonly used in web applications to facilitate interactive features like live chat, online gaming, and real-time updates, as it allows for efficient and low-latency data transfer without the overhead of constantly opening and closing connections. WebSocket is especially well-suited for scenarios where instant communication and data synchronization between client and server are crucial.

## Usage

### 1. Create websocket controller

```bash
dox create:controller SocketController -ws
```

```dart
import 'package:dox_core/dox_core.dart';

class ChatWebSocketController {
  intro(SocketEmitter emitter, message) {
    // sent message to chart room but exclude the sender
    emitter.room('chat').emitExceptSender('intro', message);
  }

  noti(SocketEmitter emitter, message) {
    // sent message to chart room including the sender
    emitter.room('chat').emit('noti', message);
  }
}
```

!!! tip "Note"
    As webSocket maintains an open connection, there is no requirement to send back any values from your controller method.

### 2. register websocket route

```dart
ChatWebSocketController controller = ChatWebSocketController();

Router.websocket('ws', (socket) {
    // when client sent an event called `intro`, 
    // it will execute `controller.intro` method
    socket.on('intro', controller.intro);
    
    // when client sent an event called `noti`, 
    // it will execute `controller.noti` method
    socket.on('noti', controller.noti);
});
```

!!! info
    You can register websocket routes on `lib/routes/web.dart` or you can also create custom websocket router and register in `lib/config/app.dart`. Both option will create a websocket url on `ws://127.0.0.1:{port}/ws`.

!!! tip "Note"
    You also have the option to register WebSocket routes for multiple paths, rather than just the default `/ws` route.

## Client Usage

You have the option to utilize either the built-in browser WebSocket or any WebSocket library for clients. The key requirement is that when sending data, it must be in the form of a JSON string containing both `event` and `message` attributes. Refer to the example below for clarification.

#### Example with Dart

```dart
import 'dart:io';

// The event name that is listening in your routes
// Eg. DoxWebsocket.on('intro', controller.intro);
String event = 'intro';

// Message can be any type such as int, float, map, string etc..
String message = "Mingalaba!"; 


// Encoding to json formatted string
var data = jsonEncode({
    "event": event,
    "message": message,
});

String url = 'ws://localhost:3000/ws';
WebSocket socket = await WebSocket.connect(url);

socket.add(data);


// If you would like to join the room, please use event name `joinRoom`
var joinRoomData = jsonEncode({
    "event": "joinRoom",
    "message": "chat", // sent room name as message
});

// Sent message to join the chat room
socket.add(joinRoomData);
```

---

#### Example with javascript

For Handling with javascript, we suggested you to use below library. [https://github.com/dartondox/dox-web-socket-client](https://github.com/dartondox/dox-web-socket-client/)

```js
import DoxWebsocket from '@dartondox/websocket';

const socket = DoxWebsocket('ws://127.0.0.1:3000/ws', {
  maxRetries: 18, retryAfter: 2000 
})

socket.onConnected(() => {
  console.log(socket.id)
})

socket.onError(() => {
  console.log('socket error')
})

// Listen in client for intro event that will sent from the server
socket.on('intro', (msg) => {
  console.log(msg)
})

socket.onClose(() => {
  console.log('socket closed')
})

function sendMessage(message) {
  socket.emit('intro', message)
}
```

## SocketEmitter

#### `room`

Set the room before emit to client

```dart
emitter.room('chat').emit('event-name', message);
```

#### `emit`

Emit to all the client connected to the same websocket route.

```dart
emitter.emit('event-name', message);
```

#### `emitExceptSender`

Emit to all the client connected to the same websocket route except the sender.

```dart
emitter.emitExceptSender('event-name', message);
```
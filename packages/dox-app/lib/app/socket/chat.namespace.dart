import 'package:dox_socketio/dox_socketio.dart';

/// Socket.IO namespace `/chat`.
/// Client: `io('http://localhost:3000/chat', { transports: ['websocket'] })`
class ChatNamespace extends NamespaceHandler {
  @override
  String get path => '/chat';

  @override
  void onConnection(Socket socket) {
    socket.on('join', onJoin);
    socket.on('message', onMessage);
  }

  void onJoin(SocketEvent event) {
    event.socket.join(event.data.toString());
    event.ack(true);
  }

  void onMessage(SocketEvent event) {
    Map<String, dynamic> data = event.data as Map<String, dynamic>;
    event.socket.to(data['room'].toString()).emit('message', data);
  }
}

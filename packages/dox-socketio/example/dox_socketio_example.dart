import 'package:dox_socketio/dox_socketio.dart';

/// A service class. In a real app it comes from your DI container.
class MessageService {
  String format(String text) => text.trim();
}

/// Class-based namespace. Its dependencies come in through the constructor.
class ChatNamespace extends NamespaceHandler {
  ChatNamespace(this.messages);

  final MessageService messages;

  @override
  String get path => '/chat';

  @override
  List<Middleware> get middleware => <Middleware>[checkToken];

  void checkToken(Socket socket) {
    if (socket.handshake.auth['token'] != 'secret') {
      throw SocketIoException('unauthorized');
    }
  }

  @override
  void onConnection(Socket socket) {
    socket.join('lobby');
    socket.on('message', onMessage);
    socket.on('disconnect', onDisconnect);
  }

  void onMessage(SocketEvent event) {
    String text = messages.format(event.data.toString());
    event.socket.to('lobby').emit('message', text);
    event.ack('sent');
  }

  void onDisconnect(SocketEvent event) => print('left: ${event.data}');
}

Future<void> main() async {
  SocketIoServer io = SocketIoServer(
    options: ServerOptions(cors: CorsOptions()),
  );
  io.register(ChatNamespace(MessageService()));
  await io.listen(3000);
  print('Socket.IO server on http://127.0.0.1:3000/socket.io/');
}

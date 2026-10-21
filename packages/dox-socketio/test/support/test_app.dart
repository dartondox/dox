import 'dart:io';
import 'dart:typed_data';

import 'package:dox_socketio/dox_socketio.dart';

/// Main namespace handlers used by the interop tests.
class MainNamespace extends NamespaceHandler {
  MainNamespace(this.events);

  /// Things the server saw, for the tests to check.
  final List<String> events;

  @override
  void onConnection(Socket socket) {
    events.add('connect:${socket.id}');
    socket.emit('welcome', <String, Object>{'id': socket.id});
    socket.on('echo', onEcho);
    socket.on('message', onMessage);
    socket.on('sum', onSum);
    socket.on('ask-me', onAskMe);
    socket.on('join', onJoin);
    socket.on('say', onSay);
    socket.on('news-to', onNewsTo);
    socket.on('broadcast-all', onBroadcastAll);
    socket.on('binary-echo', onEcho);
    socket.on('send-binary', onSendBinary);
    socket.on('kick', onKick);
    socket.on('disconnect', onDisconnect);
  }

  void onEcho(SocketEvent event) => event.ack(event.data);

  void onMessage(SocketEvent event) =>
      event.socket.emitArgs('message-back', event.args);

  void onSum(SocketEvent event) {
    List<Object?> numbers = event.data! as List<Object?>;
    event.ack(numbers.cast<num>().reduce(_add));
  }

  Future<void> onAskMe(SocketEvent event) async {
    List<Object?> answer = await event.socket.emitWithAck(
      'question',
      'hello?',
      timeout: Duration(seconds: 3),
    );
    event.socket.emit('answer-was', answer);
  }

  void onJoin(SocketEvent event) {
    event.socket.join(event.data! as String);
    event.ack(true);
  }

  void onSay(SocketEvent event) {
    Map<String, dynamic> data = event.data! as Map<String, dynamic>;
    event.socket.to(data['room'] as String).emit('said', data);
  }

  void onNewsTo(SocketEvent event) {
    Map<String, dynamic> data = event.data! as Map<String, dynamic>;
    event.socket.nsp
        .to(data['room'] as String)
        .except(data['except'] as String)
        .emit('news', 'hello room');
  }

  void onBroadcastAll(SocketEvent event) =>
      event.socket.broadcast.emit('all', 'everyone');

  void onSendBinary(SocketEvent event) =>
      event.socket.emit('binary', Uint8List.fromList(<int>[9, 8, 7]));

  void onKick(SocketEvent event) => event.socket.disconnect();

  void onDisconnect(SocketEvent event) =>
      events.add('disconnect:${event.data}');

  static num _add(num a, num b) => a + b;
}

/// `/admin` namespace with a token check.
class AdminNamespace extends NamespaceHandler {
  @override
  String get path => '/admin';

  @override
  List<Middleware> get middleware => <Middleware>[checkToken];

  void checkToken(Socket socket) {
    if (socket.handshake.auth['token'] != 'secret') {
      throw SocketIoException(
        'unauthorized',
        data: <String, String>{'reason': 'bad token'},
      );
    }
  }

  @override
  void onConnection(Socket socket) => socket.on('whoami', onWhoAmI);

  void onWhoAmI(SocketEvent event) {
    event.ack(<String, Object?>{
      'nsp': event.socket.nsp.name,
      'token': event.socket.handshake.auth['token'],
    });
  }
}

/// Starts a server with the test namespaces on a free port.
class TestApp {
  TestApp({ServerOptions options = const ServerOptions(), Adapter? adapter})
    : io = SocketIoServer(options: options, adapter: adapter) {
    io.register(MainNamespace(events));
    io.register(AdminNamespace());
  }

  final SocketIoServer io;
  final List<String> events = <String>[];
  late final HttpServer http;

  String get url => 'http://127.0.0.1:${http.port}';

  Future<void> start() async => http = await io.listen(0);

  Future<void> stop() => io.close();
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'config/app.dart';

websocketTest() {
  Config config = Config();

  test('websocket', () async {
    Route.websocket('ws', (socket) {
      socket.on('intro', (SocketEmitter emitter, message) {
        expect(message, 'hello');
      });

      socket.on('json', (SocketEmitter emitter, message) {
        expect(message['title'], 'hello');
      });
    });

    WebSocket socket =
        await WebSocket.connect('ws://localhost:${config.serverPort}/ws');

    var data = jsonEncode({
      "event": "intro",
      "message": "hello",
    });

    var jsonData = jsonEncode({
      "event": "json",
      "message": {"title": "hello"}
    });

    socket.add(data);
    socket.add(jsonData);

    socket.close();
  });
}

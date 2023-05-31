import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'requirements/config/app.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Websocket |', () {
    setUpAll(() async {
      config.serverPort = 50013;
      Dox().initialize(config);
      await Future.delayed(Duration(milliseconds: 500));
    });

    tearDownAll(() {
      Dox().server.close();
    });

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
  });
}

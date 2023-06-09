import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/websocket/dox_websocket.dart';
import 'package:test/test.dart';

import 'requirements/config/app.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Websocket |', () {
    setUpAll(() async {
      config.serverPort = 50013;
      await Dox().initialize(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('websocket', () async {
      Route.websocket('ws', (DoxWebsocket socket) {
        socket.on('intro', (SocketEmitter emitter, dynamic message) {
          expect(message, 'hello');
        });

        socket.on('json', (SocketEmitter emitter, dynamic message) {
          expect(message['title'], 'hello');
        });
      });

      WebSocket socket =
          await WebSocket.connect('ws://localhost:${config.serverPort}/ws');

      String data = jsonEncode(<String, String>{
        'event': 'intro',
        'message': 'hello',
      });

      String jsonData = jsonEncode(<String, dynamic>{
        'event': 'json',
        'message': <String, String>{'title': 'hello'}
      });

      socket.add(data);
      socket.add(jsonData);

      await socket.close();
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart';
import 'package:dox_core/websocket/dox_websocket.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import 'requirements/config/app.dart';

Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Websocket |', () {
    setUpAll(() async {
      await startHttpServer(config);
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('websocket', () async {
      Route.websocket('ws', (DoxWebsocket socket) {
        socket.on('intro', (SocketEmitter emitter, dynamic message) {
          emitter.room('ws').emit('intro', message);
        });

        socket.on('json', (SocketEmitter emitter, dynamic message) {
          emitter.emitExceptSender('json', message);
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

      socket.listen((dynamic message) {
        Map<String, dynamic> data = JSON.parse(message);
        if (data['event'] == 'intro') {
          expect(data['message'], 'hello');
        }
      });

      socket.add(data);
      socket.add(jsonData);

      WebSocket socket2 =
          await WebSocket.connect('ws://localhost:${config.serverPort}/ws');

      String joinRoomData = jsonEncode(<String, String>{
        'event': 'joinRoom',
        'message': 'ws',
      });

      socket2.add(joinRoomData);

      socket2.listen((dynamic message) {
        Map<String, dynamic> data = JSON.parse(message);
        if (data['event'] == 'intro') {
          expect(data['message'], 'hello');
        }

        if (data['event'] == 'json') {
          expect(data['message']['title'], 'hello');
        }
      });

      await socket.close();
      await socket2.close();
    });
  });
}

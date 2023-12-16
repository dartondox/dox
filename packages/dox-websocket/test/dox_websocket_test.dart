import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/json.dart';
import 'package:dox_websocket/dox_websocket.dart';
import 'package:ioredis/ioredis.dart';
import 'package:test/test.dart';

import 'config/app_config.dart';

String baseUrl = 'http://localhost:${appConfig.serverPort}';

class WebsocketService implements DoxService {
  @override
  void setup() {
    Redis sub = Redis();
    Redis pub = sub.duplicate();

    WebsocketServer io = WebsocketServer(Dox());
    io.adapter(WebsocketRedisAdapter(
      subscriber: sub,
      publisher: pub,
    ));
  }
}

void main() {
  group('Websocket |', () {
    setUpAll(() async {
      Dox().initialize(appConfig);
      Dox().addService(WebsocketService());
      await Dox().startServer();
    });

    tearDownAll(() async {
      await Dox().server.close();
    });

    test('websocket', () async {
      WebSocket socket =
          await WebSocket.connect('ws://localhost:${appConfig.serverPort}/ws');

      socket.listen((dynamic message) {
        Map<String, dynamic> data = JSON.parse(message);
        if (data['event'] == 'intro') {
          expect(data['message'], 'hello');
        }
        if (data['event'] == 'json') {
          expect(data['message']['title'], 'hello');
        }
      });

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

      await Future<void>.delayed(Duration(seconds: 2));

      await socket.close();
    });
  });
}

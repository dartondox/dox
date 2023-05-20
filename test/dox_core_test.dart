import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'app/config/app.dart';
import 'app/controllers/example.controller.dart';

Dox dox = Dox();
Config config = Config();
String baseUrl = 'http://localhost:${config.serverPort}';

void main() {
  group('Http', () {
    setUp(() {
      dox.websocket(websocket: DoxWebsocket());
      dox.initialize(config);
    });

    test('ping -> pong', () async {
      Route.get('/ping', (DoxRequest req) {
        return 'pong';
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/ping');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong');

      dox.server.close();
    });

    test('param route', () async {
      Route.get('/ping/{name}', (DoxRequest req, String name) {
        return 'pong $name';
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/ping/dox');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong dox');

      dox.server.close();
    });

    test('double param route', () async {
      Route.get('/ping/{name}/{type}',
          (DoxRequest req, String name, String type) {
        return 'pong $name $type';
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/ping/dox/framework');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, 'pong dox framework');

      dox.server.close();
    });

    test('json response', () async {
      var responseData = {"ping": "pong"};
      Route.get('/json', (DoxRequest req) {
        return responseData;
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/json');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, jsonEncode(responseData));
      expect(
          response.headers['content-type']?.contains('application/json'), true);

      dox.server.close();
    });

    test('exception', () async {
      Route.get('/exception', ExampleController().testException);

      await sleep(1);

      var url = Uri.parse('$baseUrl/exception');
      var response = await http.get(url);

      expect(response.statusCode, 500);
      expect(response.body, 'something went wrong');

      dox.server.close();
    });

    test('http exception', () async {
      Route.get('/http_exception', ExampleController().httpException);

      await sleep(1);

      var url = Uri.parse('$baseUrl/http_exception');
      var response = await http.get(url);

      expect(response.statusCode, 401);
      expect(response.body, 'Failed to authorize');

      dox.server.close();
    });

    test('list', () async {
      var responseData = ['1', '2', '4'];
      Route.get('/list', (DoxRequest req) {
        return responseData;
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/list');
      var response = await http.get(url);

      expect(response.statusCode, 200);
      expect(response.body, jsonEncode(responseData));

      dox.server.close();
    });

    test('custom status', () async {
      Route.get('/custom_status', (DoxRequest req) {
        return response('pong').statusCode(207);
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/custom_status');
      var res = await http.get(url);

      expect(res.statusCode, 207);
      expect(res.body, 'pong');

      dox.server.close();
    });

    test('custom header', () async {
      Route.get('/custom_header', (DoxRequest req) {
        return response('pong').header('x-key', 'ABCD');
      });

      await sleep(1);

      var url = Uri.parse('$baseUrl/custom_header');
      var res = await http.get(url);

      expect(res.statusCode, 200);
      expect(res.body, 'pong');
      expect(res.headers['x-key'], 'ABCD');

      dox.server.close();
    });

    test('websocket', () async {
      WebSocket socket =
          await WebSocket.connect('ws://localhost:${config.serverPort}/ws');

      await sleep(1);

      DoxWebsocket.on('intro', (SocketEmitter emitter, message) {
        expect(message, 'hello');
      });

      DoxWebsocket.on('json', (SocketEmitter emitter, message) {
        expect(message['title'], 'hello');
      });

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

      await sleep(1);
      socket.close();
    });
  });
}

Future<void> sleep(second) {
  return Future.delayed(Duration(seconds: second));
}

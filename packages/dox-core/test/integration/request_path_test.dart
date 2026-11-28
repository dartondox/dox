import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// sends GET [target] as it is (no client cleans it), gives the answer
Future<String> raw(String target) async {
  Socket s = await Socket.connect('127.0.0.1', Dox().server.httpServer.port);
  s.write('GET $target HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
  String out = await utf8.decoder.bind(s).join();
  s.destroy();
  return out;
}

String bodyOf(String answer) =>
    answer.substring(answer.indexOf('\r\n\r\n') + 4);

void main() {
  setUpAll(() async {
    Route.get('/ping', (DoxRequest req) => 'pong');
    Route.get('/users/{id}', (DoxRequest req) => 'user ${req.param['id']}');
    Route.get(
      '/echo',
      (DoxRequest req) =>
          '${req.uri.path}|${req.uri.query}|${req.input('a')}|${req.path()}',
    );
    await startHttpServer(
      AppConfig(appKey: testAppKey, serverPort: 0, totalIsolate: 1),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
  });

  test(
    'a plain path and a path the Uri parse cleans find the same route',
    () async {
      for (String target in <String>[
        '/ping',
        '/ping?x=1',
        '/ping/',
        '/a/../ping',
        '/./ping',
        '/pi%6Eg',
        '/ping?x=1#y',
      ]) {
        expect(bodyOf(await raw(target)), 'pong', reason: target);
      }
    },
  );

  test('params still decode', () async {
    expect(bodyOf(await raw('/users/7')), 'user 7');
    expect(bodyOf(await raw('/users/a%20b')), 'user a b');
    expect(bodyOf(await raw('/users/x/../9')), 'user 9');
  });

  test('req.uri is made on first use and has the query', () async {
    expect(bodyOf(await raw('/echo?a=1&b=2')), '/echo|a=1&b=2|1|/echo');
  });

  test('an unknown path is 404 with its path in the message', () async {
    String answer = await raw('/nope?x=1');
    expect(answer, startsWith('HTTP/1.1 404'));
    expect(answer, contains('/nope'));
    expect(answer, isNot(contains('x=1')));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

int get port => Dox().server.httpServer.port;

/// the server runs in another isolate, so the filter writes the log
/// line to a file
const String logFile = 'storage/log_middleware_test.json';

Map<String, dynamic> saveLine(Map<String, dynamic> line) {
  File(logFile)
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(line));
  return line;
}

class LogRouter extends Router {
  @override
  void register() {
    Route.post('/log/login', (DoxRequest req) => 'ok');
  }
}

void main() {
  setUpAll(() async {
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        // the OS picks a free port, so test files can run in parallel
        serverPort: 0,
        totalIsolate: 1,
        routers: <Router>[LogRouter()],
        globalMiddleware: <dynamic>[
          LogMiddleware(enabled: true, withHeader: true, filter: saveLine),
        ],
      ),
    );
  });

  tearDownAll(() async {
    await Dox().server.close();
    if (File(logFile).existsSync()) File(logFile).deleteSync();
  });

  test('passwords, tokens and auth headers are not logged', () async {
    HttpClient client = HttpClient();
    HttpClientRequest req = await client.post('localhost', port, '/log/login');
    req.headers.contentType = ContentType.json;
    req.headers.set('Authorization', 'Bearer abc.def');
    req.headers.set('X-Api-Key', 'key-123');
    req.write(
      jsonEncode(<String, dynamic>{
        'email': 'a@dox.dev',
        'password': 'hunter2',
        'profile': <String, dynamic>{'api_key': 'k', 'name': 'A'},
        'refresh_token': 'r',
      }),
    );
    HttpClientResponse res = await req.close();
    await res.drain<void>();
    client.close();

    Map<String, dynamic> logged = jsonDecode(File(logFile).readAsStringSync());
    Map<String, dynamic> payload = logged['payload'];
    Map<String, dynamic> body = payload['request'];
    expect(body['email'], 'a@dox.dev');
    expect(body['password'], '[REDACTED]');
    expect(body['refresh_token'], '[REDACTED]');
    expect(body['profile'], <String, dynamic>{
      'api_key': '[REDACTED]',
      'name': 'A',
    });
    expect(payload['headers']['authorization'], '[REDACTED]');
    expect(payload['headers']['x-api-key'], '[REDACTED]');
    expect(jsonEncode(logged), isNot(contains('hunter2')));
    expect(jsonEncode(logged), isNot(contains('key-123')));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http2/http2.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// Sends one GET over h2c (prior knowledge) and returns status and body.
Future<(int, String)> getOverH2c(int port, String path) async {
  ClientTransportConnection c = ClientTransportConnection.viaSocket(
    await Socket.connect('127.0.0.1', port),
  );
  ClientTransportStream s = c.makeRequest(<Header>[
    Header.ascii(':method', 'GET'),
    Header.ascii(':scheme', 'http'),
    Header.ascii(':path', path),
    Header.ascii(':authority', 'localhost'),
  ], endStream: true);
  int status = 0;
  List<int> body = <int>[];
  await for (StreamMessage m in s.incomingMessages) {
    if (m is HeadersStreamMessage) {
      for (Header h in m.headers) {
        if (ascii.decode(h.name) == ':status') {
          status = int.parse(ascii.decode(h.value));
        }
      }
    } else if (m is DataStreamMessage) {
      body.addAll(m.bytes);
    }
  }
  await c.finish();
  return (status, utf8.decode(body));
}

void main() {
  tearDown(() async {
    await Dox().server.close();
  });

  test('http2 on: h2c and HTTP/1.1 share one port', () async {
    Route.get('/proto', (DoxRequest req) => req.protocolVersion);
    await startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        http2: true,
      ),
    );
    int port = Dox().server.httpServer.port;

    (int, String) h2 = await getOverH2c(port, '/proto');
    expect(h2.$1, 200);
    expect(h2.$2, '2.0');

    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      port,
      '/proto',
    )).close();
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join(), '1.1');
    client.close();
  });

  test('maxConcurrentStreams below 1 throws when the server starts', () async {
    await expectLater(
      startHttpServer(
        AppConfig(
          appKey: testAppKey,
          serverPort: 0,
          totalIsolate: 1,
          http2: true,
          maxConcurrentStreams: 0,
        ),
      ),
      throwsArgumentError,
    );
  });
}

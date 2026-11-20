import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:http2/http2.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

/// Time for one request. The full test run is busy, so it is generous.
const Duration _wait = Duration(seconds: 20);

/// Sends one GET over h2c (prior knowledge) and returns status and body.
Future<(int, String)> getOverH2c(int port, String path) async {
  Socket socket = await Socket.connect('127.0.0.1', port);
  ClientTransportConnection c = ClientTransportConnection.viaSocket(socket);
  ClientTransportStream s = c.makeRequest(<Header>[
    Header.ascii(':method', 'GET'),
    Header.ascii(':scheme', 'http'),
    Header.ascii(':path', path),
    Header.ascii(':authority', 'localhost'),
  ], endStream: true);
  try {
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
    return (status, utf8.decode(body));
  } finally {
    // finish() waits for the server to close the socket. On a busy
    // machine that can take long, and the test has what it needs. Close now.
    await c.terminate();
    socket.destroy();
  }
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

    (int, String) h2 = await getOverH2c(port, '/proto').timeout(_wait);
    expect(h2.$1, 200);
    expect(h2.$2, '2.0');

    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      '127.0.0.1',
      port,
      '/proto',
    )).close().timeout(_wait);
    expect(res.statusCode, 200);
    expect(await res.transform(utf8.decoder).join().timeout(_wait), '1.1');
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

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

AppConfig backendConfig({ServerBackend server = ServerBackend.native}) {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    serverPort: 50040,
    totalIsolate: 1,
    server: server,
  );
}

/// `DOX_SERVER=dartio dart test` runs the whole suite on dart:io.
bool envDartIo = Platform.environment['DOX_SERVER'] == 'dartio';

void main() {
  tearDown(() async {
    await Dox().server.close();
  });

  test('native is the default backend', () async {
    Route.get('/backend', (DoxRequest req) => 'ok');
    await startHttpServer(backendConfig());
    expect(Dox().server.httpServer is NativeHttpServer, !envDartIo);

    HttpClient client = HttpClient();
    HttpClientResponse res = await (await client.get(
      'localhost',
      50040,
      '/backend',
    )).close();
    expect(res.statusCode, 200);
    client.close();
  });

  test('ServerBackend.dartIo uses the dart:io server', () async {
    await startHttpServer(backendConfig(server: ServerBackend.dartIo));
    expect(Dox().server.httpServer is NativeHttpServer, isFalse);
  });
}

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/server/dox_server.dart';
import 'package:dox_http_native/dox_http_native.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

void main() {
  setUpAll(() => Env().load());

  tearDown(() {
    Env().env.remove('APP_PORT');
    Env().env.remove('PORT');
    Env().env.remove('APP_HOST');
  });

  group('port |', () {
    test('APP_PORT, else PORT, else the default', () {
      expect(DoxServer.portFor(3000), 3000);
      Env().env['PORT'] = '8080';
      expect(DoxServer.portFor(3000), 8080);
      Env().env['APP_PORT'] = '4000';
      // the app reads APP_PORT into serverPort, so serverPort wins
      expect(DoxServer.portFor(4000), 4000);
    });

    test('a bad PORT keeps the default', () {
      Env().env['PORT'] = 'abc';
      expect(DoxServer.portFor(3000), 3000);
    });
  });

  group('host |', () {
    test('config, else APP_HOST, else all interfaces', () {
      expect(DoxServer.hostFor(null), isNull);
      Env().env['APP_HOST'] = '127.0.0.1';
      expect(DoxServer.hostFor(null), '127.0.0.1');
      expect(DoxServer.hostFor('0.0.0.0'), '0.0.0.0');
    });

    test('the start log shows the real host and port', () {
      expect(
        Dox.serverUrl(_FakeServer(InternetAddress.loopbackIPv4, 3000)),
        'http://127.0.0.1:3000',
      );
      expect(
        Dox.serverUrl(_FakeServer(InternetAddress.anyIPv6, 8080)),
        'http://[::]:8080',
      );
    });

    for (ServerBackend backend in ServerBackend.values) {
      test('APP_HOST=127.0.0.1 listens on IPv4 loopback only '
          '(${backend.name})', () async {
        Env().env['APP_HOST'] = '127.0.0.1';
        Env().env['PORT'] = '50092';
        Route.get('/listen', (DoxRequest req) => 'ok');
        await startHttpServer(
          AppConfig(
            appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
            totalIsolate: 1,
            server: backend,
          ),
        );
        try {
          HttpServer server = Dox().server.httpServer;
          bool dartIo = Platform.environment['DOX_SERVER'] == 'dartio';
          expect(
            server is NativeHttpServer,
            backend == ServerBackend.native && !dartIo,
          );
          expect(server.port, 50092);
          expect(server.address, InternetAddress.loopbackIPv4);
          HttpClient client = HttpClient();
          HttpClientResponse res = await (await client.get(
            '127.0.0.1',
            50092,
            '/listen',
          )).close();
          expect(res.statusCode, 200);
          await res.drain<void>();
          client.close();
          await expectLater(
            Socket.connect(InternetAddress.loopbackIPv6, 50092),
            throwsA(isA<SocketException>()),
          );
        } finally {
          await Dox().server.close();
        }
      });
    }
  });
}

class _FakeServer implements HttpServer {
  _FakeServer(this.address, this.port);

  @override
  final InternetAddress address;

  @override
  final int port;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

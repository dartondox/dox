import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/free_port.dart';
import '../utils/start_http_server.dart';

class Cleanup implements DoxService, DoxShutdown {
  int calls = 0;

  @override
  void setup() {}

  @override
  void shutdown() => calls++;
}

/// GET [path] and give the status and body, or the error
Future<Object> fetch(int port, String path) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.get('127.0.0.1', port, path);
    HttpClientResponse res = await req.close();
    return '${res.statusCode} ${await utf8.decodeStream(res)}';
  } catch (error) {
    return error;
  } finally {
    client.close(force: true);
  }
}

Future<String> slow(DoxRequest req) async {
  int ms = int.parse(req.input('ms') as String);
  await Future<void>.delayed(Duration(milliseconds: ms));
  return 'slow done';
}

void main() {
  bool dartIo = Platform.environment['DOX_SERVER'] == 'dartio';

  for (ServerBackend backend in ServerBackend.values) {
    group('stop (${backend.name}) |', () {
      late int port;
      late Cleanup cleanup;

      setUp(() async {
        cleanup = Cleanup();
        Route.get('/slow', slow);
        await startHttpServer(
          AppConfig(
            appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
            // the OS picks a free port, so test files can run in parallel
            serverPort: 0,
            totalIsolate: 1,
            server: backend,
            services: <DoxService>[cleanup],
            shutdownTimeout: const Duration(seconds: 2),
          ),
        );
        port = Dox().server.httpServer.port;
      });

      test('open requests finish, new ones are refused', () async {
        Future<Object> open = fetch(port, '/slow?ms=500');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        Future<void> stopped = Dox().stop();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(await fetch(port, '/slow?ms=0'), isA<SocketException>());
        expect(await open, '200 slow done');
        await stopped;
        expect(cleanup.calls, 1);
      });

      test('a request longer than shutdownTimeout is cut', () async {
        Future<Object> open = fetch(port, '/slow?ms=5000');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        Stopwatch clock = Stopwatch()..start();
        await Dox().stop();
        expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
        expect(await open, isNot('200 slow done'));
        expect(cleanup.calls, 1);
      });
    });
  }

  group('SIGTERM |', () {
    for (ServerBackend backend in ServerBackend.values) {
      if (dartIo && backend == ServerBackend.native) continue;
      test('3 isolates finish open requests, then exit 0 '
          '(${backend.name})', () async {
        // a free port, known before the start: 3 isolates share it
        int port = await freePort();
        Process app = await Process.start(Platform.resolvedExecutable, <String>[
          'run',
          'test/integration/requirements/shutdown_app.dart',
          '$port',
          '3',
          backend.name,
        ]);
        StringBuffer out = StringBuffer();
        Completer<void> ready = Completer<void>();
        app.stdout.transform(utf8.decoder).listen((String text) {
          out.write(text);
          if (out.toString().contains('ready') && !ready.isCompleted) {
            ready.complete();
          }
        });
        app.stderr.transform(utf8.decoder).listen(out.write);
        try {
          await ready.future.timeout(const Duration(seconds: 60));
          // wait until all 3 isolates serve
          await Future<void>.delayed(const Duration(milliseconds: 500));
          List<Future<Object>> open = <Future<Object>>[
            for (int i = 0; i < 6; i++) fetch(port, '/slow'),
          ];
          await Future<void>.delayed(const Duration(milliseconds: 200));
          app.kill(); // SIGTERM
          for (Object result in await Future.wait(open)) {
            expect(result, '200 slow done');
          }
          int code = await app.exitCode.timeout(const Duration(seconds: 15));
          expect(code, 0, reason: '$out');
          // the DoxShutdown service ran in every isolate
          for (int id = 1; id <= 3; id++) {
            expect(out.toString(), contains('cleanup $id'));
          }
        } finally {
          app.kill(ProcessSignal.sigkill);
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });
}

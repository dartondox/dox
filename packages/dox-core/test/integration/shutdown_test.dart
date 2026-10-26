import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dox_cache/dox_cache.dart' show MemoryDriver;
import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/free_port.dart';
import '../utils/start_http_server.dart';

class Cleanup extends DoxProvider {
  int calls = 0;

  @override
  void setup() {}

  @override
  void shutdown() => calls++;
}

/// a cache driver that counts close calls
class SpyCacheDriver extends MemoryDriver {
  int closed = 0;

  @override
  Future<void> close() async => closed++;
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

/// completes when a `/slow` request reaches the handler. With one isolate
/// the handler runs in the isolate of the test.
Completer<void> slowStarted = Completer<void>();

Future<String> slow(DoxRequest req) async {
  if (!slowStarted.isCompleted) slowStarted.complete();
  int ms = int.parse(req.input('ms') as String);
  await Future<void>.delayed(Duration(milliseconds: ms));
  return 'slow done';
}

void main() {
  group('stop |', () {
    late int port;
    late Cleanup cleanup;

    setUp(() async {
      cleanup = Cleanup();
      slowStarted = Completer<void>();
      Route.get('/slow', slow);
      await startHttpServer(
        AppConfig(
          appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
          // the OS picks a free port, so test files can run in parallel
          serverPort: 0,
          totalIsolate: 1,
          providers: <DoxProvider>[cleanup],
          shutdownTimeout: const Duration(seconds: 2),
        ),
      );
      port = Dox().server.httpServer.port;
    });

    test('open requests finish, new ones are refused', () async {
      Future<Object> open = fetch(port, '/slow?ms=500');
      // stop only when the request is in the handler. A fixed delay is
      // too short on a busy CI machine.
      await slowStarted.future.timeout(const Duration(seconds: 10));
      Future<void> stopped = Dox().stop();
      // a new request is refused once the server stops listening
      Object refused = await fetch(port, '/slow?ms=0');
      for (int i = 0; i < 100 && refused is! SocketException; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        refused = await fetch(port, '/slow?ms=0');
      }
      expect(refused, isA<SocketException>());
      expect(await open, '200 slow done');
      await stopped;
      expect(cleanup.calls, 1);
    });

    // closing the database on stop is tested in dartondox/dox-orm
    test('stop closes the cache', () async {
      SpyCacheDriver spy = SpyCacheDriver();
      Dox().cache.addStore('spy', spy);
      await Dox().stop();
      expect(spy.closed, 1);
    });

    test('a request longer than shutdownTimeout is cut', () async {
      Future<Object> open = fetch(port, '/slow?ms=5000');
      await slowStarted.future.timeout(const Duration(seconds: 10));
      Stopwatch clock = Stopwatch()..start();
      await Dox().stop();
      expect(clock.elapsed, lessThan(const Duration(seconds: 4)));
      expect(await open, isNot('200 slow done'));
      expect(cleanup.calls, 1);
    });
  });

  group('SIGTERM |', () {
    test('3 isolates finish open requests, then exit 0', () async {
      // a free port, known before the start: 3 isolates share it
      int port = await freePort();
      Process app = await Process.start(Platform.resolvedExecutable, <String>[
        'run',
        'test/integration/requirements/shutdown_app.dart',
        '$port',
        '3',
      ]);
      StringBuffer out = StringBuffer();
      Completer<void> ready = Completer<void>();
      // all 6 requests are in a handler (the app prints `slow start`)
      Completer<void> started = Completer<void>();
      app.stdout.transform(utf8.decoder).listen((String text) {
        out.write(text);
        if (out.toString().contains('ready') && !ready.isCompleted) {
          ready.complete();
        }
        if ('slow start'.allMatches(out.toString()).length >= 6 &&
            !started.isCompleted) {
          started.complete();
        }
      });
      app.stderr.transform(utf8.decoder).listen(out.write);
      try {
        await ready.future.timeout(const Duration(seconds: 60));
        List<Future<Object>> open = <Future<Object>>[
          for (int i = 0; i < 6; i++) fetch(port, '/slow'),
        ];
        // SIGTERM only when every request is in a handler. A fixed delay
        // is too short on a busy CI machine.
        await started.future.timeout(const Duration(seconds: 30));
        app.kill(); // SIGTERM
        for (Object result in await Future.wait(open)) {
          expect(result, '200 slow done');
        }
        int code = await app.exitCode.timeout(const Duration(seconds: 15));
        expect(code, 0, reason: '$out');
        // the provider shutdown ran in every isolate
        for (int id = 1; id <= 3; id++) {
          expect(out.toString(), contains('cleanup $id'));
        }
      } finally {
        app.kill(ProcessSignal.sigkill);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

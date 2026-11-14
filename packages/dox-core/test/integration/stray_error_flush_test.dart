import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';
import '../utils/test_app_key.dart';

List<String> written = <String>[];

/// was the line already written one microtask after the report?
/// A flush right after the report does it. The 20 ms timer is too late.
bool writtenAtOnce = false;

/// the report adds a line to the buffer, like a real handler that logs
class LoggingHandler extends ExceptionHandler {
  const LoggingHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    LogBuffer.write('reported: $error');
    scheduleMicrotask(() => writtenAtOnce = written.isNotEmpty);
  }
}

class StrayRouter extends Router {
  @override
  void register() {
    Route.get('/stray', (DoxRequest req) {
      // an un-awaited future that fails: nobody handles it
      Future<void>.error(StateError('stray'));
      return 'ok';
    });
  }
}

void main() {
  late void Function(String) oldWriter;

  setUpAll(() async {
    oldWriter = LogBuffer.writer;
    LogBuffer.writer = written.add;
    await startHttpServer(
      AppConfig(
        appKey: testAppKey,
        serverPort: 0,
        totalIsolate: 1,
        routers: <Router>[StrayRouter()],
        exceptionHandler: const LoggingHandler(),
      ),
    );
  });

  tearDownAll(() async {
    LogBuffer.writer = oldWriter;
    await Dox().server.close();
  });

  test('a stray error is reported and the line is written at once', () async {
    HttpClient client = HttpClient();
    HttpClientRequest req = await client.get(
      'localhost',
      Dox().server.httpServer.port,
      '/stray',
    );
    HttpClientResponse res = await req.close();
    await res.drain<void>();
    client.close();
    // no LogBuffer.flush() here: the server must have written it
    for (int i = 0; i < 100 && written.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(written.join(), contains('reported: Bad state: stray'));
    expect(writtenAtOnce, isTrue);
  });
}

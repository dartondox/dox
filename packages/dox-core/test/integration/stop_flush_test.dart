import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

import '../utils/start_http_server.dart';

/// a provider whose shutdown fails, with a handler that fails too,
/// so `stopIsolate` throws on purpose
class BrokenProvider extends DoxProvider {
  @override
  void setup() {}

  @override
  void shutdown() => throw StateError('provider broke');
}

class ThrowingHandler extends ExceptionHandler {
  const ThrowingHandler();

  @override
  void report(Object error, StackTrace stackTrace) {
    throw StateError('handler broke');
  }
}

void main() {
  late List<String> written;

  setUp(() async {
    written = <String>[];
    LogBuffer.writer = written.add;
    await startHttpServer(
      AppConfig(
        appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
        serverPort: 0,
        totalIsolate: 1,
        providers: <DoxProvider>[BrokenProvider()],
        exceptionHandler: const ThrowingHandler(),
      ),
    );
  });

  tearDown(() {
    LogBuffer.writer = stdout.write;
  });

  group('shutdown that throws |', () {
    test('stopIsolate still writes the waiting lines', () async {
      LogBuffer.write('before error');
      await expectLater(Dox().stopIsolate(), throwsStateError);
      expect(written.join(), contains('before error'));
    });

    test('stop still writes the waiting lines', () async {
      LogBuffer.write('before stop error');
      await expectLater(Dox().stop(), throwsStateError);
      expect(written.join(), contains('before stop error'));
    });
  });
}

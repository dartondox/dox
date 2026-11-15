import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:dox_core/utils/strict_mode.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// keeps what is written to it, to read the stderr lines
class _Capture implements Stdout {
  final StringBuffer text = StringBuffer();

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  List<String> get lines =>
      text.toString().split('\n').where((String l) => l.isNotEmpty).toList();
}

void busy(Duration time) {
  Stopwatch watch = Stopwatch()..start();
  while (watch.elapsed < time) {}
}

class SlowRouter extends Router {
  @override
  void register() {
    Route.get('/slow/{id}', (DoxRequest req) {
      busy(const Duration(milliseconds: 80));
      return 'slow';
    });
    Route.get('/fast', (DoxRequest req) => 'fast');
  }
}

/// start a test app with [strict], call [paths], give the stderr lines
Future<List<String>> serve(StrictConfig strict, List<String> paths) async {
  _Capture err = _Capture();
  await IOOverrides.runZoned(() async {
    DoxTestClient client = await DoxTestClient.start(
      AppConfig(
        appKey: testAppKey,
        routers: <Router>[SlowRouter()],
        strict: strict,
      ),
    );
    try {
      for (String path in paths) {
        (await client.get(path)).expectStatus(200);
      }
    } finally {
      await client.close();
    }
  }, stderr: () => err);
  return err.lines;
}

List<String> capture(void Function() body) {
  _Capture err = _Capture();
  IOOverrides.runZoned(body, stderr: () => err);
  return err.lines;
}

void hashTwiceAtOnePlace(String hashed) {
  for (int i = 0; i < 2; i++) {
    Hash.verify('secret', hashed);
  }
}

void main() {
  tearDown(() {
    StrictMode.configure(const StrictConfig());
    Dox().isWebServer = false;
  });

  group('slow handler', () {
    test('on: one warning per route, with the route pattern', () async {
      List<String> lines = await serve(
        const StrictConfig(enabled: true),
        <String>['/slow/1', '/slow/2', '/fast'],
      );
      List<String> handler = lines
          .where((String l) => l.contains('blocked the isolate'))
          .toList();
      expect(handler, hasLength(1));
      expect(handler.single, startsWith('[strict] GET /slow/{id} blocked'));
      expect(handler.single, contains('Dox().compute'));
    });

    test('off: no warning', () async {
      List<String> lines = await serve(const StrictConfig(), <String>[
        '/slow/1',
      ]);
      expect(lines, isEmpty);
      expect(StrictMode.enabled, isFalse);
    });

    test('a higher limit: no warning', () async {
      List<String> lines = await serve(
        const StrictConfig(enabled: true, blockLimit: Duration(seconds: 5)),
        <String>['/slow/1'],
      );
      expect(lines, isEmpty);
    });
  });

  group('sync Hash in the web server', () {
    String hashed = Hash.make('secret', rounds: 4);

    test('on: once per place in the code, names the async method', () {
      StrictMode.configure(const StrictConfig(enabled: true));
      Dox().isWebServer = true;
      List<String> lines = capture(() {
        hashTwiceAtOnePlace(hashed);
        Hash.make('secret', rounds: 4);
        Hash.check('secret', hashed);
      });
      expect(lines, hasLength(3));
      expect(
        lines[0],
        startsWith('[strict] Hash.verify ran in the web server'),
      );
      expect(lines[0], contains('hashTwiceAtOnePlace'));
      expect(lines[0], contains('Hash.verifyAsync'));
      expect(lines[1], contains('Hash.make ran'));
      expect(lines[1], contains('Hash.makeAsync'));
      expect(lines[2], contains('Hash.check ran'));
    });

    test('on, but not the web server: no warning', () {
      StrictMode.configure(const StrictConfig(enabled: true));
      expect(capture(() => Hash.verify('secret', hashed)), isEmpty);
    });

    test('off: no warning', () {
      Dox().isWebServer = true;
      expect(capture(() => Hash.verify('secret', hashed)), isEmpty);
    });
  });

  group('watchdog', () {
    test('on: warns when the event loop was blocked, at most once in a '
        'while', () async {
      StrictMode.configure(
        const StrictConfig(
          enabled: true,
          blockLimit: Duration(milliseconds: 20),
        ),
      );
      _Capture err = _Capture();
      await IOOverrides.runZoned(() async {
        StrictMode.startWatchdog();
        try {
          for (int i = 0; i < 2; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            busy(const Duration(milliseconds: 120));
            await Future<void>.delayed(const Duration(milliseconds: 60));
          }
        } finally {
          StrictMode.stopWatchdog();
        }
      }, stderr: () => err);
      expect(err.lines, hasLength(1));
      expect(err.lines.single, contains('The event loop of isolate'));
    });

    test('configure restarts a running watchdog with the new config', () async {
      StrictMode.configure(
        const StrictConfig(
          enabled: true,
          blockLimit: Duration(milliseconds: 20),
        ),
      );
      _Capture err = _Capture();
      await IOOverrides.runZoned(() async {
        StrictMode.startWatchdog();
        // off: the old timer must stop
        StrictMode.configure(const StrictConfig());
        busy(const Duration(milliseconds: 120));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(err.lines, isEmpty);
        // a new limit: the timer follows it
        StrictMode.configure(
          const StrictConfig(
            enabled: true,
            blockLimit: Duration(milliseconds: 20),
          ),
        );
        StrictMode.startWatchdog();
        StrictMode.configure(
          const StrictConfig(
            enabled: true,
            blockLimit: Duration(milliseconds: 500),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        busy(const Duration(milliseconds: 120));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        StrictMode.stopWatchdog();
      }, stderr: () => err);
      expect(err.lines, isEmpty);
    });

    test('off: no timer and no warning', () async {
      StrictMode.configure(
        const StrictConfig(blockLimit: Duration(milliseconds: 20)),
      );
      _Capture err = _Capture();
      await IOOverrides.runZoned(() async {
        StrictMode.startWatchdog();
        busy(const Duration(milliseconds: 120));
        await Future<void>.delayed(const Duration(milliseconds: 60));
        StrictMode.stopWatchdog();
      }, stderr: () => err);
      expect(err.lines, isEmpty);
    });
  });
}

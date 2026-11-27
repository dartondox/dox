import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../utils/free_port.dart';
import '../utils/test_app_key.dart';

/// one GET on a new connection, so the kernel can spread the requests
/// over the isolates (SO_REUSEPORT). Gives the status, the body and the
/// session cookie that came back (or null).
Future<(int, String, Cookie?)> get(int port, String path, [Cookie? c]) async {
  HttpClient client = HttpClient();
  try {
    HttpClientRequest req = await client.get('127.0.0.1', port, path);
    if (c != null) req.cookies.add(c);
    HttpClientResponse res = await req.close();
    String body = await utf8.decodeStream(res);
    Cookie? cookie;
    for (Cookie k in res.cookies) {
      if (k.name == 'dox_session') cookie = k;
    }
    return (res.statusCode, body, cookie);
  } finally {
    client.close(force: true);
  }
}

void main() {
  group('isolate groups |', () {
    late int port;
    late Process app;
    StringBuffer out = StringBuffer();
    Completer<void> probed = Completer<void>();

    /// Start the app. False when the port was taken after `freePort`
    /// gave it (other tests run at the same time), then try again.
    Future<bool> startApp() async {
      out.clear();
      probed = Completer<void>();
      port = await freePort();
      // `dart run` is JIT: each isolate group starts the script again
      app = await Process.start(
        Platform.resolvedExecutable,
        <String>['run', 'test/integration/requirements/groups_app.dart'],
        environment: <String, String>{
          'GROUPS_PORT': '$port',
          'GROUPS_ISOLATES': '3',
          'GROUPS_KEY': testAppKey,
        },
      );
      void onText(String text) {
        out.write(text);
        String all = out.toString();
        if (all.contains('session ') && !probed.isCompleted) probed.complete();
        // the port was taken: the listen fails, or the groups end early
        bool taken =
            all.contains('bind failed') ||
            all.contains('in use') ||
            all.contains('CoreFlags.isolateGroups is on, but');
        if (taken && !probed.isCompleted) {
          probed.completeError('bind failed');
        }
      }

      app.stdout.transform(utf8.decoder).listen(onText);
      app.stderr.transform(utf8.decoder).listen(onText);
      try {
        await probed.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw StateError('the app did not finish: $out'),
        );
      } on String {
        app.kill(ProcessSignal.sigkill);
        await app.exitCode;
        return false;
      }
      // the line ends after the numbers
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return true;
    }

    setUpAll(() async {
      for (int i = 0; i < 3 && !await startApp(); i++) {}
      expect(probed.isCompleted && out.toString().contains('session '), isTrue);
    });

    tearDownAll(() {
      app.kill(ProcessSignal.sigkill);
    });

    test('each isolate knows its id and who is primary at start', () {
      String text = out.toString();
      expect(text, contains('start 1 true'));
      expect(text, contains('start 2 false'));
      expect(text, contains('start 3 false'));
    });

    test('each isolate runs in its own group and joins the bus', () {
      String text = out.toString();
      // the isolates did not fall back to one group
      expect(text, isNot(contains('CoreFlags.isolateGroups is on, but')));
      // all 3 joined the hub, and the primary got a pong from each other
      expect(text, contains('size 3'));
      expect(text, contains('pongs 2,3'));
      // the pongs came from isolates that were started with spawnUri
      expect(text, contains('names true'));
    });

    test('rate limit and session store of the primary work from a group', () {
      String text = out.toString();
      // 2 other isolates counted once each, the primary counted the third
      expect(text, contains('boot 3'));
      expect(text, contains('session 2,3'));
    });

    test('an isolate answers HTTP, with its own group name', () async {
      (int, String, Cookie?) name = await get(port, '/name');
      expect(name.$1, 200);
      expect(name.$2, anyOf('main', startsWith('dox-group-')));
      Set<String> ids = <String>{};
      for (int i = 0; i < 40; i++) {
        ids.add((await get(port, '/id')).$2);
      }
      // Linux spreads new connections over the isolates (SO_REUSEPORT).
      // macOS sends them all to one isolate, so the check is for Linux only.
      if (Platform.isLinux) {
        expect(ids.length, greaterThan(1), reason: 'served by $ids');
      } else {
        expect(ids, isNotEmpty);
      }
    });

    test('a rate limit counts over all the isolates', () async {
      Map<int, int> codes = <int, int>{};
      for (int i = 0; i < 12; i++) {
        int code = (await get(port, '/limited')).$1;
        codes[code] = (codes[code] ?? 0) + 1;
      }
      expect(codes, <int, int>{200: 5, 429: 7});
    });

    test('a memory session is seen by all the isolates', () async {
      (int, String, Cookie?) put = await get(port, '/put');
      expect(put.$1, 200, reason: put.$2);
      for (int i = 0; i < 30; i++) {
        (int, String, Cookie?) got = await get(port, '/get', put.$3);
        expect(got.$2.split(':').last, 'ann', reason: 'request $i');
      }
    });

    test('SIGTERM stops every isolate and exits 0', () async {
      app.kill(); // SIGTERM
      int code = await app.exitCode.timeout(const Duration(seconds: 30));
      expect(code, 0, reason: '$out');
      for (int id = 1; id <= 3; id++) {
        expect(out.toString(), contains('cleanup $id'));
      }
    });
  });

  /// Run the app with [env] until its output has [until]. It tries again
  /// when the port was taken after `freePort` gave it.
  Future<String> runApp(Map<String, String> env, String until) async {
    for (int tries = 0; ; tries++) {
      StringBuffer out = StringBuffer();
      Completer<bool> done = Completer<bool>();
      Process app = await Process.start(
        Platform.resolvedExecutable,
        <String>['run', 'test/integration/requirements/groups_app.dart'],
        environment: <String, String>{
          'GROUPS_PORT': '${await freePort()}',
          'GROUPS_ISOLATES': '3',
          'GROUPS_KEY': testAppKey,
          ...env,
        },
      );
      void onText(String text) {
        out.write(text);
        if (out.toString().contains(until) && !done.isCompleted) {
          done.complete(true);
        }
      }

      app.stdout.transform(utf8.decoder).listen(onText);
      app.stderr.transform(utf8.decoder).listen(onText);
      // the app ended before [until]: the port was taken
      unawaited(
        app.exitCode.then((int _) {
          if (!done.isCompleted) done.complete(false);
        }),
      );
      try {
        bool ok = await done.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw StateError('the app did not finish: $out'),
        );
        if (!ok && tries < 2) continue;
        expect(ok, isTrue, reason: '$out');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return out.toString();
      } finally {
        app.kill(ProcessSignal.sigkill);
      }
    }
  }

  /// [mode] `1`: `main()` of a group ends. `hang`: it waits for ever.
  Future<void> brokenApp(String mode) async {
    String text = await runApp(<String, String>{
      'GROUPS_BROKEN': mode,
    }, 'session ');
    expect(text, contains('CoreFlags.isolateGroups is on, but'));
    // the 3 isolates run, in the group of the primary. The primary
    // listened on the bus before the start, and it still gets the pongs.
    expect(text, contains('pongs 2,3'));
    expect(text, contains('names false'));
    expect(text, isNot(contains('exited, restarting')));
  }

  test(
    'isolate groups | main() of a group ends before startServer: one '
    'warning, then one group',
    () => brokenApp('1'),
  );

  test(
    'isolate groups | main() of a group never reaches startServer: one '
    'warning, then one group',
    () => brokenApp('hang'),
  );

  test('isolate groups | a group that ends is started again', () async {
    String text = await runApp(<String, String>{'GROUPS_CRASH': '1'}, 'again ');
    expect(text, contains('exited, restarting'));
    expect(text, contains('again 3'));
    expect(text, isNot(contains('CoreFlags.isolateGroups is on, but')));
  });
}

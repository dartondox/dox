import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

/// keeps what is written to it, to read the stderr lines
class _Capture implements Stdout {
  final StringBuffer text = StringBuffer();

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// default logger (off), so the warning must not need the logger
AppConfig config({List<String>? webSocketAllowedOrigins}) {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    webSocketAllowedOrigins: webSocketAllowedOrigins,
  );
}

/// the stderr lines of [Dox.warnWebSocketOrigin]
List<String> warnings() {
  _Capture err = _Capture();
  IOOverrides.runZoned(Dox().warnWebSocketOrigin, stderr: () => err);
  return err.text
      .toString()
      .split('\n')
      .where((String l) => l.isNotEmpty)
      .toList();
}

void handler(WebSocket socket, DoxRequest req) {}

void main() {
  test('no warning when every route checks the origin', () {
    Dox().initialize(config());
    Route.websocket('/checked', handler, allowedOrigins: <String>[]);
    expect(warnings(), isEmpty);
  });

  test('no warning when AppConfig turns the check on', () {
    Dox().initialize(config(webSocketAllowedOrigins: <String>[]));
    Route.websocket('/open-a', handler);
    expect(warnings(), isEmpty);
  });

  test('one warning on stderr with the logger off, only once', () {
    Dox().initialize(config());
    expect(Dox().config.logger.enabled, isFalse);
    Route.websocket('/open-b', handler);
    Route.websocket('/open-c', handler);
    expect(warnings(), <String>[Dox.webSocketOriginWarning]);
    expect(warnings(), isEmpty);
  });
}

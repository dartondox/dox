import 'dart:async';
import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

AppConfig config({List<String>? webSocketAllowedOrigins}) {
  return AppConfig(
    appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
    logger: const LoggerConfig(enabled: true),
    webSocketAllowedOrigins: webSocketAllowedOrigins,
  );
}

/// the lines that [Dox.warnWebSocketOrigin] prints
List<String> warnings() {
  List<String> lines = <String>[];
  runZoned(
    Dox().warnWebSocketOrigin,
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        lines.add(line);
      },
    ),
  );
  return lines.where((String l) => l.contains('Origin')).toList();
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

  test('one warning for a route with no check, only once', () {
    Dox().initialize(config());
    Route.websocket('/open-b', handler);
    Route.websocket('/open-c', handler);
    List<String> first = warnings();
    expect(first, hasLength(1));
    expect(first.first, contains('webSocketAllowedOrigins'));
    expect(warnings(), isEmpty);
  });
}

@Timeout(Duration(seconds: 60))
library;

import 'dart:io';

import 'package:dox_socketio/dox_socketio.dart';
import 'package:test/test.dart';

import 'support/node_runner.dart';
import 'support/test_app.dart';

/// Runs the official socket.io-client (Node.js) against the Dart server.
void main() {
  String? skip = NodeRunner.skipReason();
  NodeRunner node = NodeRunner();

  group('socket.io-client (node)', () {
    late TestApp app;

    setUpAll(node.install);

    setUp(() async {
      app = TestApp(
        options: ServerOptions(
          pingInterval: Duration(milliseconds: 300),
          pingTimeout: Duration(milliseconds: 300),
        ),
      );
      await app.start();
    });

    tearDown(() => app.stop());

    Future<void> runScenario(String name,
        [List<String> extra = const <String>[]]) async {
      ProcessResult result =
          await node.run('client.mjs', <String>[name, app.url, ...extra]);
      expect(result.exitCode, 0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');
    }

    test('connect over websocket only', () => runScenario('websocket-only'));

    test('connect over polling, then upgrade', () async {
      await runScenario('polling-upgrade');
    });

    test('polling only', () => runScenario('polling-only'));

    test('emit and receive', () => runScenario('emit-receive'));

    test('acks both ways', () => runScenario('acks'));

    test('rooms and broadcast', () => runScenario('rooms'));

    test('namespace with auth middleware', () => runScenario('namespace-auth'));

    test('binary over websocket',
        () => runScenario('binary', <String>['websocket']));

    test('binary over polling',
        () => runScenario('binary', <String>['polling']));

    test('disconnect and reconnect', () async {
      await runScenario('reconnect');
      expect(app.events, contains('disconnect:server namespace disconnect'));
      expect(app.events, contains('disconnect:transport close'));
    });

    test('heartbeat keeps the connection', () => runScenario('heartbeat'));

    test('ping timeout', () async {
      await runScenario('ping-timeout');
      expect(app.events, contains('disconnect:ping timeout'));
    });
  }, skip: skip);
}

@Timeout(Duration(seconds: 90))
library;

import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_socketio/dox_socketio.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

// the namespace used by the dox_socketio interop tests
import '../../../../dox-socketio/test/support/test_app.dart';

String get baseUrl => 'http://localhost:${Dox().server.httpServer.port}';

/// the official socket.io-client scripts of dox_socketio
final String interopDir = Directory('../dox-socketio/test/interop')
    .absolute
    .path;

class PingRouter extends Router {
  @override
  void register() {
    Route.get('/ping', (DoxRequest req) => 'pong');
  }
}

List<String> events = <String>[];

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
  // the OS picks a free port, so test files can run in parallel
  serverPort: 0,
  totalIsolate: 1,
  routers: <Router>[PingRouter()],
  socketIo: SocketIoConfig(
    enabled: true,
    options: ServerOptions(
      pingInterval: Duration(milliseconds: 300),
      pingTimeout: Duration(milliseconds: 300),
    ),
    namespaces: <NamespaceHandler>[MainNamespace(events)],
  ),
);

String? skipReason() {
  try {
    ProcessResult node = Process.runSync('node', <String>['--version']);
    if (node.exitCode != 0) return 'node failed';
  } on ProcessException {
    return 'node is not installed';
  }
  return null;
}

void main() {
  String? skip = skipReason();

  setUpAll(() async {
    if (skip == null &&
        !Directory('$interopDir/node_modules/socket.io-client').existsSync()) {
      ProcessResult install = await Process.run(
        'npm',
        <String>['ci', '--no-audit', '--no-fund'],
        workingDirectory: interopDir,
        runInShell: true,
      );
      if (install.exitCode != 0) throw StateError('${install.stderr}');
    }
    Dox().initialize(config);
    await Dox().startServer();
  });

  tearDownAll(() async {
    await Dox().socketIo?.close();
    await Dox().server.close(force: true);
  });

  Future<void> scenario(String name) async {
    ProcessResult result = await Process.run('node', <String>[
      'client.mjs',
      name,
      baseUrl,
    ], workingDirectory: interopDir).timeout(const Duration(seconds: 20));
    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
  }

  test('socket.io is mounted on the dox port', () {
    expect(Dox().socketIo, isNotNull);
    expect(Route().mounts.keys, contains('/socket.io/'));
  });

  test('websocket only', () => scenario('websocket-only'), skip: skip);

  // ponytail: 'polling-upgrade' is left out. On localhost the upgrade can
  // finish before the script checks the first transport, so it flakes.
  // dox_socketio runs it in its own tests.

  test('polling only', () => scenario('polling-only'), skip: skip);

  test('emit and receive', () => scenario('emit-receive'), skip: skip);

  test('normal routes still work next to socket.io', () async {
    http.Response res = await http.get(Uri.parse('$baseUrl/ping'));
    expect(res.body, 'pong');
  });
}

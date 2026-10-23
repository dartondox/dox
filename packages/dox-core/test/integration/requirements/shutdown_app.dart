import 'dart:io';

import 'package:dox_core/dox_core.dart';

/// a small app for the SIGTERM test. Args: port, isolates, backend.
/// `/slow` answers after 700 ms. Prints `ready` when it serves and
/// `cleanup <isolate>` when a DoxShutdown service runs.
void main(List<String> args) async {
  Dox().initialize(
    AppConfig(
      appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',
      serverPort: int.parse(args[0]),
      totalIsolate: int.parse(args[1]),
      server: ServerBackend.values.byName(args[2]),
      routers: <Router>[SlowRouter()],
      services: <DoxService>[CleanupService()],
    ),
  );
  await Dox().startServer();
  stdout.writeln('ready');
}

class SlowRouter extends Router {
  @override
  void register() {
    Route.get('/slow', slow);
  }

  static Future<String> slow(DoxRequest req) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return 'slow done';
  }
}

class CleanupService implements DoxService, DoxShutdown {
  @override
  void setup() {}

  @override
  void shutdown() {
    stdout.writeln('cleanup ${Dox().isolateId}');
  }
}

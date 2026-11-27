import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/isolate/isolate_bus.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:dox_core/session/session_memory_store.dart';

/// Starts, watches and stops the server isolates (all but the main one).
/// `DoxIsolate` starts them in the group of the main isolate.
/// `DoxIsolateGroups` starts each one in its own isolate group.
///
/// Internal: `Dox().startServer()` picks one. Apps do not use it.
abstract class IsolateSpawner {
  /// the running isolates, isolate id -> isolate
  final Map<int, Isolate> isolates = <int, Isolate>{};
  final Map<int, List<ReceivePort>> receivePorts = <int, List<ReceivePort>>{};

  /// isolate id -> the port to send the stop message to
  final Map<int, SendPort> sendPorts = <int, SendPort>{};
  bool stopped = false;

  /// wait before a dead isolate is started again,
  /// so a crash loop does not burn the CPU
  Duration restartDelay = const Duration(seconds: 1);

  /// How many times in a row an isolate may end before it serves, until
  /// it is not started again. Null: no limit.
  int? get maxEarlyExits => null;

  /// True while [spawn] waits for the first start of the isolates. An
  /// isolate that ends then is not started again: [spawn] fails.
  bool firstStart = false;

  /// isolate id -> true when it serves, false when it ended before that
  final Map<int, Completer<bool>> ready = <int, Completer<bool>>{};

  /// isolate id -> how many times in a row it ended before it served
  final Map<int, int> _earlyExits = <int, int>{};

  /// start the isolates 2 to [count]
  Future<void> spawn(int count);

  /// Start the isolate [isolateId]. It sends its stop port to [control],
  /// its errors to [error] and tells [exit] when it ends. [ports] are
  /// closed when the isolate ends.
  Future<Isolate> start(
    int isolateId,
    SendPort control,
    SendPort error,
    SendPort exit,
    List<ReceivePort> ports,
  );

  /// Stop every isolate gracefully: each stops taking connections, lets
  /// open requests finish (up to [timeout]) and runs `shutdown()` of its
  /// providers. Isolates still busy after that are killed.
  Future<void> stopAll(Duration timeout) async {
    stopped = true;
    List<Future<void>> waits = <Future<void>>[];
    for (SendPort port in sendPorts.values) {
      ReceivePort reply = ReceivePort();
      port.send(reply.sendPort);
      waits.add(
        reply.first
            // ponytail: one extra second for the provider shutdowns
            .timeout(timeout + const Duration(seconds: 1), onTimeout: _no)
            .whenComplete(reply.close),
      );
    }
    await Future.wait(waits);
    killAll();
  }

  static bool _no() => false;

  /// kill all the isolate. With [now] they stop at once, not at their
  /// next event.
  void killAll({bool now = false}) {
    stopped = true;
    isolates.forEach((int id, Isolate isolate) {
      isolate.kill(priority: now ? Isolate.immediate : Isolate.beforeNextEvent);
    });

    receivePorts.forEach((int id, List<ReceivePort> ports) {
      for (ReceivePort port in ports) {
        port.close();
      }
    });
    isolates.clear();
    receivePorts.clear();
    sendPorts.clear();
    RateLimitCounter.instance.close();
    SessionMemoryStore.instance.close();
    IsolateBus.instance.close();
  }

  /// create a thread.
  /// when it dies, the error is printed and the isolate is started again.
  /// the main isolate (id 1) is not watched here: if it dies the process
  /// exits with a non-zero code, and your supervisor (docker, systemd)
  /// restarts it.
  Future<void> spawnOne(int isolateId) async {
    ReceivePort errorPort = ReceivePort();
    ReceivePort exitPort = ReceivePort();
    ReceivePort controlPort = ReceivePort();
    List<ReceivePort> ports = <ReceivePort>[errorPort, exitPort, controlPort];
    receivePorts[isolateId] = ports;

    Completer<bool> isReady = Completer<bool>();
    ready[isolateId] = isReady;

    controlPort.listen((dynamic port) {
      sendPorts[isolateId] = port as SendPort;
      _earlyExits.remove(isolateId);
      if (!isReady.isCompleted) isReady.complete(true);
    });

    errorPort.listen((dynamic message) {
      List<dynamic> error = message as List<dynamic>;
      stderr.writeln('[server] isolate $isolateId error: ${error.first}');
      stderr.writeln(error.last);
    });

    exitPort.listen((dynamic _) async {
      for (ReceivePort port in ports) {
        port.close();
      }
      isolates.remove(isolateId);
      sendPorts.remove(isolateId);
      IsolateBus.instance.drop(isolateId);
      bool early = !isReady.isCompleted;
      if (early) isReady.complete(false);
      if (stopped || firstStart) return;
      int? limit = maxEarlyExits;
      if (early && limit != null) {
        int count = (_earlyExits[isolateId] ?? 0) + 1;
        _earlyExits[isolateId] = count;
        if (count >= limit) {
          stderr.writeln(
            '[server] isolate $isolateId ended $count times before it '
            'served. It is not started again.',
          );
          return;
        }
      }
      stderr.writeln('[server] isolate $isolateId exited, restarting');
      await Future<void>.delayed(restartDelay);
      if (stopped) return;
      try {
        await spawnOne(isolateId);
      } on IsolateSpawnException catch (error) {
        // ponytail: no more tries. The app runs with one isolate less.
        stderr.writeln('[server] isolate $isolateId did not start: $error');
      }
    });

    try {
      isolates[isolateId] = await start(
        isolateId,
        controlPort.sendPort,
        errorPort.sendPort,
        exitPort.sendPort,
        ports,
      );
    } catch (_) {
      for (ReceivePort port in ports) {
        port.close();
      }
      receivePorts.remove(isolateId);
      ready.remove(isolateId);
      rethrow;
    }
  }
}

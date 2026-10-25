import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_handler.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/router/route_data.dart';

class DoxIsolate {
  /// singleton
  static final DoxIsolate _singleton = DoxIsolate._internal();
  factory DoxIsolate() => _singleton;
  DoxIsolate._internal();

  final Map<int, Isolate> _isolates = <int, Isolate>{};
  final Map<int, List<ReceivePort>> _receivePorts = <int, List<ReceivePort>>{};

  /// isolate id -> the port to send the stop message to
  final Map<int, SendPort> _sendPorts = <int, SendPort>{};
  bool _stopped = false;

  /// routes added before `startServer()`. router routes are not in here,
  /// each isolate registers those itself. kept so a restart gets the same.
  List<RouteData> _baseRoutes = <RouteData>[];

  /// wait before a dead isolate is started again,
  /// so a crash loop does not burn the CPU
  Duration restartDelay = const Duration(seconds: 1);

  /// get list of running isolates
  Map<int, Isolate> get isolates => _isolates;
  Map<int, SendPort> get sendPorts => _sendPorts;

  /// create threads
  /// ```
  /// await DoxIsolate().spawn(3)
  /// ```
  Future<void> spawn(int count) async {
    _stopped = false;
    _baseRoutes = List<RouteData>.of(Route().routes);
    for (int i = 1; i < count; i++) {
      await _spawn(i + 1);
    }
  }

  /// Stop every isolate gracefully: each stops taking connections, lets
  /// open requests finish (up to [timeout]) and runs its `DoxShutdown`
  /// services. Isolates still busy after that are killed.
  Future<void> stopAll(Duration timeout) async {
    _stopped = true;
    List<Future<void>> waits = <Future<void>>[];
    for (SendPort port in _sendPorts.values) {
      ReceivePort reply = ReceivePort();
      port.send(reply.sendPort);
      waits.add(
        reply.first
            // ponytail: one extra second for the DoxShutdown services
            .timeout(timeout + const Duration(seconds: 1), onTimeout: _no)
            .whenComplete(reply.close),
      );
    }
    await Future.wait(waits);
    killAll();
  }

  static bool _no() => false;

  /// kill all the isolate
  void killAll() {
    _stopped = true;
    _isolates.forEach((int id, Isolate isolate) {
      isolate.kill();
    });

    _receivePorts.forEach((int id, List<ReceivePort> ports) {
      for (ReceivePort port in ports) {
        port.close();
      }
    });
    _isolates.clear();
    _receivePorts.clear();
    _sendPorts.clear();
  }

  /// create a thread.
  /// when it dies, the error is printed and the isolate is started again.
  /// the main isolate (id 1) is not watched here: if it dies the process
  /// exits with a non-zero code, and your supervisor (docker, systemd)
  /// restarts it.
  Future<void> _spawn(int isolateId) async {
    ReceivePort errorPort = ReceivePort();
    ReceivePort exitPort = ReceivePort();
    ReceivePort controlPort = ReceivePort();
    _receivePorts[isolateId] = <ReceivePort>[errorPort, exitPort, controlPort];

    controlPort.listen((dynamic port) {
      _sendPorts[isolateId] = port as SendPort;
    });

    errorPort.listen((dynamic message) {
      List<dynamic> error = message as List<dynamic>;
      stderr.writeln('[dox] isolate $isolateId error: ${error.first}');
      stderr.writeln(error.last);
    });

    exitPort.listen((dynamic _) async {
      errorPort.close();
      exitPort.close();
      controlPort.close();
      _isolates.remove(isolateId);
      _sendPorts.remove(isolateId);
      if (_stopped) return;
      stderr.writeln('[dox] isolate $isolateId exited, restarting');
      await Future<void>.delayed(restartDelay);
      if (!_stopped) await _spawn(isolateId);
    });

    Isolate isolate = await Isolate.spawn(
      isolateHandler,
      IsolateSpawnParameter(
        isolateId,
        Dox().config,
        Dox().doxServices,
        routes: _baseRoutes,
        bindings: Route().bindings,
        control: controlPort.sendPort,
      ),
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    _isolates[isolateId] = isolate;
  }
}

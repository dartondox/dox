import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_handler.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';

class DoxIsolate {
  /// singleton
  static final DoxIsolate _singleton = DoxIsolate._internal();
  factory DoxIsolate() => _singleton;
  DoxIsolate._internal();

  final Map<int, Isolate> _isolates = <int, Isolate>{};
  final Map<int, ReceivePort> _receivePorts = <int, ReceivePort>{};
  final Map<int, SendPort> _sendPorts = <int, SendPort>{};

  /// get list of running isolates
  Map<int, Isolate> get isolates => _isolates;
  Map<int, SendPort> get sendPorts => _sendPorts;

  /// create threads
  /// ```
  /// await DoxIsolate().spawn(3)
  /// ```
  Future<void> spawn(int count) async {
    for (int i = 1; i < count; i++) {
      await _spawn(i + 1);
    }
  }

  /// kill all the isolate
  void killAll() {
    _isolates.forEach((int id, Isolate isolate) {
      isolate.kill();
    });

    _receivePorts.forEach((int id, ReceivePort receivePort) {
      receivePort.close();
    });
  }

  /// create a thread
  Future<void> _spawn(int isolateId) async {
    Isolate isolate = await Isolate.spawn(
      isolateHandler,
      IsolateSpawnParameter(
        isolateId,
        Dox().config,
        Dox().doxServices,
        routes: Route().routes,
      ),
    );

    _isolates[isolateId] = isolate;
  }
}

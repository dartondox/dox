import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_handler.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';

class DoxIsolate {
  /// singleton
  static final DoxIsolate _singleton = DoxIsolate._internal();
  factory DoxIsolate() => _singleton;
  DoxIsolate._internal();

  final List<Isolate> _isolates = <Isolate>[];
  final List<ReceivePort> _receivePorts = <ReceivePort>[];

  /// create threads
  /// ```
  /// await DoxIsolate().spawn(3)
  /// ```
  Future<void> spawn(int count) async {
    for (int i = 0; i < count; i++) {
      await _spawn(i + 1);
    }
  }

  /// kill all the isolate
  void killAll() {
    for (Isolate isolate in _isolates) {
      isolate.kill();
    }
    for (ReceivePort receivePort in _receivePorts) {
      receivePort.close();
    }
  }

  /// create a thread
  Future<void> _spawn(int isolateId) async {
    ReceivePort receivePort = ReceivePort();

    Isolate isolate = await Isolate.spawn(
      isolateHandler,
      IsolateSpawnParameter(
        isolateId,
        receivePort.sendPort,
        Dox().config,
        Dox().doxServices,
        authGuard: Dox().authGuard,
      ),
    );

    _isolates.add(isolate);
    _receivePorts.add((receivePort));
  }
}

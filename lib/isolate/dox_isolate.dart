import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/isolate_handler.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/utils/logger.dart';

class DoxIsolate {
  /// singleton
  static final DoxIsolate _singleton = DoxIsolate._internal();
  factory DoxIsolate() => _singleton;
  DoxIsolate._internal();

  /// create threads
  /// ```
  /// await DoxMultiThread.create(3)
  /// ```
  Future<void> create(int count) async {
    for (int i = 0; i < count; i++) {
      await _createThread(i + 1);
    }
    DoxLogger.info(
        'Server started at http://127.0.0.1:${Dox().config.serverPort}');
  }

  /// create a thread
  Future<void> _createThread(int isolateId) async {
    ReceivePort receivePort = ReceivePort();

    await Isolate.spawn(
      isolateHandler,
      IsolateSpawnParameter(
        isolateId,
        receivePort.sendPort,
        Dox().config,
        Dox().doxServices,
        authGuard: Dox().authGuard,
      ),
    );
  }
}

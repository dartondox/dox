import 'dart:isolate';

import 'package:async/async.dart';
import 'package:dox_core/dox_core.dart';

class DoxThread {
  SendPort? sendPort;
  final Isolate isolate;
  final ReceivePort receivePort;
  final StreamQueue<dynamic> stream;
  DoxThread(this.isolate, this.receivePort, this.stream, {this.sendPort});
}

class IsolateSpawnParameter {
  final SendPort sendPort;
  final AppConfig config;
  final List<DoxService> services;
  const IsolateSpawnParameter(this.sendPort, this.config, this.services);
}
